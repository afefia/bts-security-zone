import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_service.dart';

class AuthResult {
  final bool success;
  final String? error;
  final bool needsEmailConfirmation;

  const AuthResult({
    required this.success,
    this.error,
    this.needsEmailConfirmation = false,
  });
}

class AuthService {
  final _client = SupabaseService.client;

  // ── Sign In ──────────────────────────────────────────────────────────────
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      // Belt-and-suspenders check: some Supabase configurations allow
      // signInWithPassword to succeed even before email confirmation, so we
      // verify explicitly and refuse to proceed if it isn't confirmed yet.
      final confirmedAt = response.user?.emailConfirmedAt;
      if (confirmedAt == null) {
        await _client.auth.signOut();
        return const AuthResult(
          success: false,
          needsEmailConfirmation: true,
          error: 'Please confirm your email before signing in. '
              'Check your inbox for a confirmation link.',
        );
      }

      // Log audit entry
      await _logAudit(action: 'LOGIN', detail: 'User signed in');

      return const AuthResult(success: true);
    } on AuthException catch (e) {
      final needsConfirmation = e.message.contains('Email not confirmed');
      return AuthResult(
        success: false,
        needsEmailConfirmation: needsConfirmation,
        error: _friendlyError(e.message),
      );
    } catch (e) {
      return AuthResult(success: false, error: 'An unexpected error occurred');
    }
  }

  // ── Resend Confirmation Email ─────────────────────────────────────────────
  Future<AuthResult> resendConfirmation(String email) async {
    try {
      await _client.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
      );
      return const AuthResult(success: true);
    } on AuthException catch (e) {
      return AuthResult(success: false, error: _friendlyError(e.message));
    } catch (e) {
      return const AuthResult(
          success: false, error: 'Could not resend confirmation email');
    }
  }

  // ── Register Company + First User ────────────────────────────────────────
  Future<AuthResult> registerCompany({
    required String companyName,
    required String licenseNumber,
    required String region,
    required String address,
    required String email,
    required String phone,
    required String password,
    required String fullName,
  }) async {
    try {
      // 1. Create auth user
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
      );

      if (response.user == null) {
        return const AuthResult(
            success: false, error: 'Account creation failed');
      }

      final userId = response.user!.id;

      // If the project requires email confirmation, signUp returns a user
      // but no active session — the user must click the emailed link before
      // they can sign in. We still need to create their company/user rows
      // now (while we have the new user's auth context / a temp session),
      // since Supabase only allows this insert as that authenticated user.
      final needsConfirmation = response.session == null;

      // 2. Insert company (unverified)
      final companyRes = await _client
          .from('companies')
          .insert({
            'name': companyName,
            'license_number': licenseNumber,
            'region': region,
            'address': address,
            'email': email.trim(),
            'phone': phone,
            'is_verified': false,
          })
          .select('id')
          .single();

      final companyId = companyRes['id'] as String;

      // 3. Insert user record
      await _client.from('users').insert({
        'id': userId,
        'company_id': companyId,
        'full_name': fullName,
        'email': email.trim(),
        'role': 'company_user',
      });

      // If confirmation is required, sign out any partial session so the
      // app doesn't treat this as a logged-in state.
      if (needsConfirmation) {
        await _client.auth.signOut();
      }

      return AuthResult(
        success: true,
        needsEmailConfirmation: needsConfirmation,
      );
    } on AuthException catch (e) {
      return AuthResult(success: false, error: _friendlyError(e.message));
    } on PostgrestException catch (e) {
      return AuthResult(success: false, error: _friendlyDbError(e));
    } catch (e) {
      return AuthResult(success: false, error: 'Registration failed: $e');
    }
  }

  // ── Sign Out ─────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ── Password Reset ───────────────────────────────────────────────────────
  Future<AuthResult> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email.trim(),
        // Without this, Supabase's default redirect drops the user on a
        // generic confirmation page in their browser with no way back
        // into the app. This custom scheme is caught by the deep link
        // listener in main.dart, which routes straight to a "set new
        // password" screen. Must match a Redirect URL configured in
        // Supabase Dashboard → Authentication → URL Configuration — see
        // README "Password Reset" section for the exact value to add.
        redirectTo: 'securityzone://reset-password',
      );
      return const AuthResult(success: true);
    } on AuthException catch (e) {
      return AuthResult(success: false, error: _friendlyError(e.message));
    }
  }

  /// Sets a new password for the session established by the password
  /// reset deep link. Supabase's recovery flow signs the user into a
  /// temporary session when they tap the email link — this just updates
  /// the password on that session.
  Future<AuthResult> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      return const AuthResult(success: true);
    } on AuthException catch (e) {
      return AuthResult(success: false, error: _friendlyError(e.message));
    }
  }


  /// Updates the logged-in user's full name and/or email. Email changes
  /// trigger Supabase's own re-confirmation flow (a confirmation link
  /// goes to the new address) — the change doesn't take effect until
  /// that's confirmed, which is intentional: it stops someone from
  /// silently hijacking an account by changing the email to one they
  /// control without proving they can receive mail there.
  Future<AuthResult> updateProfile({
    String? fullName,
    String? email,
  }) async {
    try {
      final user = SupabaseService.currentUser;
      if (user == null) {
        return const AuthResult(success: false, error: 'Not signed in');
      }

      if (email != null && email.trim() != user.email) {
        await _client.auth.updateUser(UserAttributes(email: email.trim()));
      }

      if (fullName != null && fullName.trim().isNotEmpty) {
        await _client
            .from('users')
            .update({'full_name': fullName.trim()})
            .eq('id', user.id);
      }

      await _logAudit(action: 'UPDATE', detail: 'Updated profile details');

      return const AuthResult(success: true);
    } on AuthException catch (e) {
      return AuthResult(success: false, error: _friendlyError(e.message));
    } catch (e) {
      return AuthResult(
          success: false,
          error: 'Could not update profile: ${e.toString()}');
    }
  }

  Future<void> _logAudit({
    required String action,
    required String detail,
  }) async {
    try {
      final user = SupabaseService.currentUser;
      if (user == null) return;
      final userData = await _client
          .from('users')
          .select('company_id')
          .eq('id', user.id)
          .maybeSingle();
      if (userData == null) return;
      await _client.from('audit_logs').insert({
        'company_id': userData['company_id'],
        'user_id': user.id,
        'action': action,
        'detail': detail,
      });
    } catch (_) {}
  }

  String _friendlyError(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'Invalid email or password';
    }
    if (message.contains('Email not confirmed')) {
      return 'Please check your email and confirm your account';
    }
    if (message.contains('User already registered')) {
      return 'An account with this email already exists';
    }
    return message;
  }

  String _friendlyDbError(PostgrestException e) {
    if (e.code == '23505') {
      if (e.message.contains('license_number')) {
        return 'A company with this license number already exists';
      }
      if (e.message.contains('email')) {
        return 'This email is already registered';
      }
    }
    return 'Database error: ${e.message}';
  }
}
