import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/recruit_service.dart';
import '../services/fingerprint_service.dart';
import '../services/local_db.dart';
import '../services/connectivity_service.dart';
import '../config/supabase_service.dart';
import '../widgets/connectivity_banner.dart';
import '../widgets/app_button.dart';
import '../widgets/app_max_width.dart';
import '../widgets/app_verified_gate.dart';
import '../widgets/app_success_overlay.dart';
import '../utils/validators.dart';

class RegisterRecruitScreen extends StatefulWidget {
  const RegisterRecruitScreen({super.key});

  @override
  State<RegisterRecruitScreen> createState() => _RegisterRecruitScreenState();
}

class _RegisterRecruitScreenState extends State<RegisterRecruitScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _fingerprintCaptured = false;
  bool _isSubmitting = false;
  bool _isCapturing = false;
  String? _errorMessage;
  String? _fingerprintHash;
  final _recruitService = RecruitService();
  final _fingerprintService = FingerprintService();

  final _nameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _selectedRegion = 'Greater Accra';
  String _selectedRole = 'Security Guard';

  final List<String> _regions = [
    'Greater Accra',
    'Ashanti',
    'Western',
    'Eastern',
    'Central',
    'Volta',
    'Northern',
    'Upper East',
    'Upper West',
    'Bono',
  ];

  final List<String> _roles = [
    'Security Guard',
    'Senior Guard',
    'Supervisor',
    'Control Room Operator',
    'Patrol Officer',
  ];

  Future<void> _captureFingerprint() async {
    setState(() {
      _isCapturing = true;
      _errorMessage = null;
    });

    final result = await _fingerprintService.capture();

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _isCapturing = false;
        _errorMessage = result.error ?? 'Fingerprint capture failed';
      });
      return;
    }

    setState(() {
      _isCapturing = false;
      _fingerprintCaptured = true;
      _fingerprintHash = result.template;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final userId = SupabaseService.currentUser!.id;
      String? companyId;

      if (ConnectivityService().isOnline) {
        try {
          final userData = await SupabaseService.client
              .from('users')
              .select('company_id')
              .eq('id', userId)
              .single();
          companyId = userData['company_id'] as String;
        } catch (_) {
          // Network call failed mid-flight — fall through to cached value.
        }
      }
      companyId ??= await LocalDb.getMyCachedCompanyId();

      if (companyId == null) {
        setState(() {
          _isSubmitting = false;
          _errorMessage =
              'Could not determine your company. Please connect to the '
              'internet at least once before registering recruits offline.';
        });
        return;
      }

      final result = await _recruitService.register(
        fullName: Validators.sanitize(_nameCtrl.text),
        idNumber: Validators.sanitize(_idCtrl.text),
        phone: Validators.sanitize(_phoneCtrl.text),
        region: _selectedRegion,
        fingerprintHash: _fingerprintHash,
        companyId: companyId,
        role: _selectedRole,
        startDate: DateTime.now(),
      );

      setState(() => _isSubmitting = false);

      if (mounted) {
        if (result.queuedOffline) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Saved offline — will sync automatically once back online'),
              backgroundColor: AppTheme.goldAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context);
        } else {
          await AppSuccessOverlay.show(context, message: 'Recruit registered');
          if (mounted) Navigator.pop(context);
        }
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppVerifiedGate(child: _buildScreen(context));
  }

  Widget _buildScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register Recruit')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AppMaxWidth(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ConnectivityBanner(),
                _sectionLabel(context, 'PERSONAL INFORMATION'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                style: const TextStyle(color: AppTheme.offWhite),
                maxLength: Validators.nameMaxLength,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                  counterText: '',
                ),
                validator: Validators.fullName,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _idCtrl,
                style: const TextStyle(color: AppTheme.offWhite),
                maxLength: Validators.idNumberMaxLength,
                decoration: const InputDecoration(
                  labelText: 'National ID Number',
                  prefixIcon: Icon(Icons.badge_outlined),
                  hintText: 'e.g. GHA-2024-000000',
                  counterText: '',
                ),
                validator: Validators.idNumber,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                style: const TextStyle(color: AppTheme.offWhite),
                maxLength: Validators.phoneMaxLength,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                  hintText: '+233 XX XXX XXXX',
                  counterText: '',
                ),
                keyboardType: TextInputType.phone,
                validator: Validators.phone,
              ),
              const SizedBox(height: 12),

              // Region dropdown
              DropdownButtonFormField<String>(
                value: _selectedRegion,
                dropdownColor: AppTheme.navyMid,
                style: const TextStyle(color: AppTheme.offWhite),
                decoration: const InputDecoration(
                  labelText: 'Region',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                items: _regions
                    .map(
                      (r) => DropdownMenuItem(value: r, child: Text(r)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedRegion = v!),
              ),
              const SizedBox(height: 24),

              _sectionLabel(context, 'EMPLOYMENT DETAILS'),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _selectedRole,
                dropdownColor: AppTheme.navyMid,
                style: const TextStyle(color: AppTheme.offWhite),
                decoration: const InputDecoration(
                  labelText: 'Role / Position',
                  prefixIcon: Icon(Icons.work_outline),
                ),
                items: _roles
                    .map(
                      (r) => DropdownMenuItem(value: r, child: Text(r)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedRole = v!),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _sectionLabel(context, 'BIOMETRIC CAPTURE'),
                  if (!_fingerprintService.isUsingRealHardware)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.goldAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppTheme.goldAccent.withOpacity(0.4)),
                      ),
                      child: const Text(
                        'SIMULATED — NO SCANNER',
                        style: TextStyle(
                          color: AppTheme.goldAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _fingerprintCaptured
                        ? AppTheme.successGreen.withOpacity(0.4)
                        : AppTheme.steelBlue.withOpacity(0.4),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.fingerprint,
                      size: 56,
                      color: _isCapturing
                          ? AppTheme.goldAccent
                          : _fingerprintCaptured
                              ? AppTheme.successGreen
                              : AppTheme.goldAccent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isCapturing
                          ? 'Scanning...'
                          : _fingerprintCaptured
                              ? '✓ Fingerprint Captured'
                              : 'Fingerprint not yet captured',
                      style: TextStyle(
                        color: _fingerprintCaptured && !_isCapturing
                            ? AppTheme.successGreen
                            : AppTheme.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppButton.secondary(
                      label: _fingerprintCaptured
                          ? 'RE-CAPTURE'
                          : 'CAPTURE FINGERPRINT',
                      icon: _fingerprintCaptured
                          ? Icons.refresh
                          : Icons.touch_app,
                      isLoading: _isCapturing,
                      onPressed: _isCapturing ? null : _captureFingerprint,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              if (_errorMessage != null) ...[
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
                        child: Text(_errorMessage!,
                            style: const TextStyle(
                                color: AppTheme.dangerRed, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              Center(
                child: AppButton(
                  label: 'REGISTER RECRUIT',
                  onPressed: _isSubmitting ? null : _submit,
                  isLoading: _isSubmitting,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        letterSpacing: 2,
        color: AppTheme.goldAccent,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
