import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../config/supabase_service.dart';
import '../services/sync_service.dart';
import '../services/push_notification_service.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.6)),
    );
    _scaleAnim = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        final isLoggedIn = SupabaseService.isLoggedIn;
        if (isLoggedIn) {
          SyncService().syncNow();
          PushNotificationService().registerCurrentToken();
        }
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                isLoggedIn ? const DashboardScreen() : const LoginScreen(),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navyDark,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Shield icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.goldAccent, width: 2),
                    color: AppTheme.navyMid,
                  ),
                  child: const Icon(
                    Icons.shield,
                    size: 52,
                    color: AppTheme.goldAccent,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'THE SECURITY ZONE',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    letterSpacing: 3,
                    color: AppTheme.offWhite,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  width: 60,
                  height: 2,
                  color: AppTheme.goldAccent,
                ),
                const SizedBox(height: 12),
                Text(
                  'Trusted Intelligence for Private Security',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    letterSpacing: 1.1,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.goldAccent.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
