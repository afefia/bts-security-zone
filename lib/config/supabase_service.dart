import 'package:supabase_flutter/supabase_flutter.dart';

/// Single access point for the Supabase client throughout the app.
/// Usage: SupabaseService.client.from('recruits')...
class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;

  static User? get currentUser => client.auth.currentUser;

  static bool get isLoggedIn => currentUser != null;

  static Session? get currentSession => client.auth.currentSession;

  /// Stream of auth state changes
  static Stream<AuthState> get authStateChanges =>
      client.auth.onAuthStateChange;
}
