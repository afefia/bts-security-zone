import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/set_new_password_screen.dart';
import 'services/sync_service.dart';
import 'services/push_notification_service.dart';

/// App-wide navigator key so the deep link listener below can push a
/// screen without needing a BuildContext of its own — links can arrive
/// before any screen has built, or while the app is backgrounded.
final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (.env -> SUPABASE_URL, SUPABASE_ANON_KEY)
  await dotenv.load(fileName: '.env');

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  // Catches the most common first-run mistake: running the app before
  // replacing the placeholder values in .env. Without this check, the
  // failure mode is a raw exception from the Supabase client deep in the
  // stack with no indication of what to actually fix.
  final needsSetup = supabaseUrl == null ||
      supabaseAnonKey == null ||
      supabaseUrl.contains('your-project-id') ||
      supabaseAnonKey.contains('your-anon-key-here');

  if (needsSetup) {
    runApp(const _SetupNeededApp());
    return;
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // Starts listening for connectivity changes so any writes queued while
  // offline (recruit registration, conduct records) replay automatically
  // the moment a network connection returns — no user action required.
  SyncService().start();

  // Push notifications are optional — if google-services.json /
  // GoogleService-Info.plist aren't present yet, this silently no-ops
  // and the app continues to work with in-app Realtime alerts only.
  final firebaseReady = await initializeFirebaseIfConfigured();
  if (firebaseReady) {
    await PushNotificationService().initialize();
  }

  _initDeepLinkListener();

  runApp(const SecurityZoneApp());
}

/// Catches the securityzone://reset-password link Supabase redirects to
/// after a user taps the password reset email — see
/// AuthService.resetPassword for where this scheme is set, and the
/// README's "Password Reset" section for the matching Supabase Dashboard
/// configuration this depends on. Without that dashboard config, the
/// link still works for establishing a recovery session (Supabase
/// handles that via the URL fragment regardless), but the OS won't know
/// to hand the link to this app at all unless the custom scheme is also
/// registered in AndroidManifest.xml / Info.plist — see README.
void _initDeepLinkListener() {
  final appLinks = AppLinks();

  void handleLink(Uri uri) {
    if (uri.scheme == 'securityzone' && uri.host == 'reset-password') {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const SetNewPasswordScreen()),
      );
    }
  }

  // Link that launched the app from cold start, if any.
  appLinks.getInitialLink().then((uri) {
    if (uri != null) handleLink(uri);
  });

  // Links received while the app is already running.
  appLinks.uriLinkStream.listen(handleLink, onError: (_) {
    // Malformed or unexpected link — ignore rather than crash.
  });
}

class SecurityZoneApp extends StatelessWidget {
  const SecurityZoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'The Security Zone',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}

/// Shown instead of crashing when .env still contains the placeholder
/// SUPABASE_URL / SUPABASE_ANON_KEY values. A clear "here's exactly what
/// to do" screen is far more useful on first run than a stack trace from
/// deep inside the Supabase client.
class _SetupNeededApp extends StatelessWidget {
  const _SetupNeededApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.settings_outlined,
                    color: AppTheme.goldAccent, size: 56),
                const SizedBox(height: 20),
                Text(
                  'Setup Needed',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'The .env file still has placeholder Supabase credentials.\n\n'
                  'Open .env in the project root and replace:\n'
                  '  • SUPABASE_URL\n'
                  '  • SUPABASE_ANON_KEY\n\n'
                  'with your real project values from\n'
                  'Supabase Dashboard → Settings → API,\n'
                  'then restart the app.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(height: 1.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
