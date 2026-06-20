import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../config/supabase_service.dart';

/// Background message handler MUST be a top-level (or static) function —
/// Flutter calls this in a separate isolate when a push arrives while the
/// app is fully closed or backgrounded.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Nothing to do here beyond letting the OS show the notification (FCM
  // does this automatically for "notification" payloads) — kept minimal
  // since background isolates have no access to the rest of the app's
  // state, and shouldn't try to touch Supabase or local DB here.
}

/// Wraps Firebase Cloud Messaging registration, permission requests, and
/// foreground notification display. The actual *sending* of pushes
/// happens server-side (see supabase/functions/send-push) — this class's
/// job is purely the client side: get a token, hand it to Supabase, and
/// show/react to incoming messages.
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._();
  factory PushNotificationService() => _instance;
  PushNotificationService._();

  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Called once at app startup, after Firebase.initializeApp(). Safe to
  /// call even if the project has no Firebase config yet — every step is
  /// wrapped so a missing/misconfigured Firebase setup degrades to "no
  /// push notifications" rather than crashing the app. In-app Realtime
  /// alerts (AlertsService) keep working regardless.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await _setupLocalNotifications();

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Foreground messages don't show a system notification automatically
      // on Android — we display one ourselves via flutter_local_notifications
      // so the behavior matches background/terminated states.
      FirebaseMessaging.onMessage.listen(_showForegroundNotification);

      // Token can change (app reinstall, FCM token rotation) — keep
      // Supabase in sync whenever that happens, not just at startup.
      messaging.onTokenRefresh.listen(_registerToken);

      final token = await messaging.getToken();
      if (token != null) await _registerToken(token);
    } catch (e) {
      // Misconfigured Firebase project, missing google-services.json, etc.
      // The rest of the app must keep working without push notifications.
      // ignore: avoid_print
      print('Push notifications unavailable: $e');
    }
  }

  Future<void> _setupLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
  }

  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'security_zone_alerts',
          'Security Zone Alerts',
          channelDescription:
              'Flagged recruit and platform alerts for your company',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Stores (or updates) this device's FCM token in Supabase, scoped to
  /// the logged-in user and their company, so the send-push Edge Function
  /// knows where to deliver alerts for that company.
  Future<void> _registerToken(String token) async {
    final user = SupabaseService.currentUser;
    if (user == null) return; // not logged in yet — register call comes later

    try {
      final userData = await SupabaseService.client
          .from('users')
          .select('company_id')
          .eq('id', user.id)
          .maybeSingle();
      if (userData == null) return;

      await SupabaseService.client.from('device_tokens').upsert({
        'token': token,
        'user_id': user.id,
        'company_id': userData['company_id'],
        'platform': _platformName(),
        'last_seen_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Network failure, RLS misconfiguration, etc — don't let a failed
      // token registration disrupt login or app startup.
      // ignore: avoid_print
      print('Failed to register push token: $e');
    }
  }

  /// Call this right after a successful login, since the token may have
  /// been obtained before SupabaseService.currentUser was available.
  Future<void> registerCurrentToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _registerToken(token);
    } catch (_) {}
  }

  /// Call on sign-out so a shared/borrowed device doesn't keep receiving
  /// another account's push notifications.
  Future<void> unregisterToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await SupabaseService.client
          .from('device_tokens')
          .delete()
          .eq('token', token);
    } catch (_) {}
  }

  String _platformName() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'other';
  }
}

/// Call before runApp() if Firebase config files are present.
/// Wrapped so a project without Firebase set up yet doesn't fail startup —
/// see README "Push Notifications" section for what needs to exist
/// (google-services.json / GoogleService-Info.plist) for this to succeed.
Future<bool> initializeFirebaseIfConfigured() async {
  // Firebase Web requires explicit initialization options, which aren't
  // configured here — skip entirely on web to avoid assertion errors
  // from firebase_core_web when options are null.
  if (kIsWeb) return false;

  try {
    await Firebase.initializeApp();
    return true;
  } catch (e) {
    // ignore: avoid_print
    print('Firebase not configured — push notifications disabled: $e');
    return false;
  }
}
