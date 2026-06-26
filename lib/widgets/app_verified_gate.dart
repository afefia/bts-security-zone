import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/company_service.dart';
import 'app_button.dart';

/// Wraps a screen that performs a real platform action (registering a
/// recruit, searching, filing a conduct record) and blocks it with a
/// clear explanation if the logged-in user's company isn't verified yet.
///
/// WHY THIS EXISTS: the database's RLS policies already correctly refuse
/// these operations for an unverified company (see
/// recruits_insert_verified, conduct_insert_own, etc. in
/// supabase_schema.sql) — that's the real, unbypassable enforcement.
/// This widget is the app-side half of the same rule: without it, an
/// unverified company's user could open these screens, fill out a whole
/// form, hit submit, and only then discover it was rejected — with a
/// confusing low-level database error instead of a clear explanation
/// up front. This stops them before they waste the effort.
///
/// USAGE: wrap a screen's Scaffold (or the whole build() return value)
/// in AppVerifiedGate. It checks the company's status once and either
/// shows the real screen or a clear "pending verification" blocker.
class AppVerifiedGate extends StatefulWidget {
  final Widget child;

  const AppVerifiedGate({super.key, required this.child});

  @override
  State<AppVerifiedGate> createState() => _AppVerifiedGateState();
}

class _AppVerifiedGateState extends State<AppVerifiedGate> {
  final _companyService = CompanyService();
  bool _checking = true;
  bool _isVerified = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final company = await _companyService.getMyCompany();
      if (!mounted) return;
      setState(() {
        _isVerified = company?.isVerified ?? false;
        _checking = false;
      });
    } catch (_) {
      // If the check itself fails (offline, etc.), don't block the
      // person from at least trying — RLS is still the real backstop,
      // so failing open here doesn't create a security gap, it just
      // means they might hit a database-level rejection instead of this
      // friendlier one in that edge case.
      if (mounted) {
        setState(() {
          _isVerified = true;
          _checking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.goldAccent),
        ),
      );
    }

    if (!_isVerified) {
      return Scaffold(
        appBar: AppBar(title: const Text('Verification Required')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.hourglass_top,
                    color: AppTheme.goldAccent, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Your company is pending verification',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'An admin needs to verify your company before you can '
                  'register recruits, search, or file conduct records. '
                  "This usually doesn't take long — check back soon.",
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                AppButton.secondary(
                  label: 'GO BACK',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
