import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/push_notification_service.dart';
import '../utils/validators.dart';
import '../widgets/app_button.dart';
import 'dashboard_screen.dart';
import 'register_company_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;
  bool _needsEmailConfirmation = false;
  final _authService = AuthService();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _needsEmailConfirmation = false;
    });

    final result = await _authService.signIn(
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
    );

    if (!mounted) return;

    if (result.success) {
      SyncService().syncNow(); // warm the offline cache right away
      PushNotificationService().registerCurrentToken();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result.error;
        _needsEmailConfirmation = result.needsEmailConfirmation;
      });
    }
  }

  Future<void> _resendConfirmation() async {
    if (_emailCtrl.text.trim().isEmpty || !_emailCtrl.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter your email above first'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }
    setState(() => _isResending = true);
    final result = await _authService.resendConfirmation(_emailCtrl.text);
    if (!mounted) return;
    setState(() => _isResending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.success
            ? 'Confirmation email resent — check your inbox'
            : result.error ?? 'Failed to resend confirmation email'),
        backgroundColor:
            result.success ? AppTheme.successGreen : AppTheme.dangerRed,
      ),
    );
  }

  Future<void> _forgotPassword() async {
    if (_emailCtrl.text.trim().isEmpty || !_emailCtrl.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter your email above first'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }
    final result = await _authService.resetPassword(_emailCtrl.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.success
            ? 'Password reset link sent to your email'
            : result.error ?? 'Failed to send reset link'),
        backgroundColor:
            result.success ? AppTheme.successGreen : AppTheme.dangerRed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navyDark,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),

                  // Logo
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.navyMid,
                      border: Border.all(
                          color: AppTheme.goldAccent, width: 2),
                    ),
                    child: const Icon(
                      Icons.shield,
                      size: 46,
                      color: AppTheme.goldAccent,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'THE SECURITY ZONE',
                    style: Theme.of(context)
                        .textTheme
                        .displayMedium
                        ?.copyWith(letterSpacing: 3, fontSize: 20),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Company Portal',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppTheme.goldAccent),
                  ),
                  const SizedBox(height: 48),

                  // Email
                  TextFormField(
                    controller: _emailCtrl,
                    style: const TextStyle(color: AppTheme.offWhite),
                    keyboardType: TextInputType.emailAddress,
                    maxLength: Validators.emailMaxLength,
                    decoration: const InputDecoration(
                      labelText: 'Company Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      counterText: '',
                    ),
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passwordCtrl,
                    style: const TextStyle(color: AppTheme.offWhite),
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppTheme.textMuted,
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) => v == null || v.isEmpty
                        ? 'Password is required'
                        : null,
                  ),
                  const SizedBox(height: 8),

                  Align(
                    alignment: Alignment.centerRight,
                    child: AppButton.text(
                      label: 'Forgot Password?',
                      onPressed: _forgotPassword,
                      compact: true,
                    ),
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.dangerRed.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppTheme.dangerRed, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                  color: AppTheme.dangerRed, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_needsEmailConfirmation) ...[
                      const SizedBox(height: 10),
                      Center(
                        child: AppButton.secondary(
                          label: _isResending
                              ? 'Sending...'
                              : 'Resend confirmation email',
                          icon: Icons.mark_email_unread_outlined,
                          isLoading: _isResending,
                          onPressed:
                              _isResending ? null : _resendConfirmation,
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),

                  Center(
                    child: AppButton(
                      label: 'SIGN IN',
                      onPressed: _isLoading ? null : _login,
                      isLoading: _isLoading,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Divider
                  Row(
                    children: [
                      const Expanded(
                          child: Divider(color: AppTheme.steelBlue)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'NEW TO THE PLATFORM?',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontSize: 11, letterSpacing: 1),
                        ),
                      ),
                      const Expanded(
                          child: Divider(color: AppTheme.steelBlue)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Center(
                    child: AppButton.secondary(
                      label: 'REGISTER YOUR COMPANY',
                      icon: Icons.add_business,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RegisterCompanyScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  Text(
                    'Authorized access only.\nAll activity is logged and audited.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
