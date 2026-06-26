import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/recruit_service.dart';
import '../services/fingerprint_service.dart';
import '../services/local_db.dart';
import '../services/connectivity_service.dart';
import '../config/supabase_service.dart';
import '../models/db_models.dart';
import '../widgets/connectivity_banner.dart';
import '../widgets/app_button.dart';
import '../widgets/app_max_width.dart';
import '../widgets/app_verified_gate.dart';
import '../widgets/app_success_overlay.dart';
import '../utils/validators.dart';
import 'recruit_profile_screen.dart';

class RegisterRecruitScreen extends StatefulWidget {
  const RegisterRecruitScreen({super.key});

  @override
  State<RegisterRecruitScreen> createState() => _RegisterRecruitScreenState();
}

class _RegisterRecruitScreenState extends State<RegisterRecruitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _recruitService = RecruitService();
  final _fingerprintService = FingerprintService();

  // Step tracking: 'lookup' -> 'register' (or 'found')
  bool _isLookingUp = false;
  bool _foundExisting = false;
  Map<String, dynamic>? _existingRecruit;

  // Registration fields
  bool _fingerprintCaptured = false;
  bool _isSubmitting = false;
  bool _isCapturing = false;
  String? _errorMessage;
  String? _fingerprintHash;
  File? _photoFile;

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
        _errorMessage = result.error;
      });
      return;
    }
    setState(() {
      _isCapturing = false;
      _fingerprintCaptured = true;
      _fingerprintHash = result.template;
    });
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.camera, maxWidth: 1024, maxHeight: 1024);
    if (picked != null) {
      setState(() => _photoFile = File(picked.path));
    }
  }

  /// Step 1: Look up the ID number to see if recruit already exists.
  Future<void> _lookupId() async {
    if (_idCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage =
          'Please enter an ID number or capture a fingerprint first.');
      return;
    }
    setState(() {
      _isLookingUp = true;
      _errorMessage = null;
      _foundExisting = false;
      _existingRecruit = null;
    });

    try {
      final data = await SupabaseService.client
          .from('recruits')
          .select(
              '*, employment_history (*, companies (id, name)), conduct_records (*, companies (id, name))')
          .eq('id_number', _idCtrl.text.trim())
          .maybeSingle();

      if (data != null) {
        setState(() {
          _foundExisting = true;
          _existingRecruit = data;
          _isLookingUp = false;
        });
      } else {
        setState(() => _isLookingUp = false);
        // Not found — proceed to registration form
      }
    } catch (e) {
      setState(() {
        _isLookingUp = false;
        _errorMessage = 'Lookup failed. Check connection and try again.';
      });
    }
  }

  /// Step 2: Submit the registration.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Photo is mandatory for new recruits
    if (_photoFile == null) {
      setState(() => _errorMessage = 'Please take a photo of the recruit.');
      return;
    }

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
        } catch (_) {}
      }
      companyId ??= await LocalDb.getMyCachedCompanyId();

      if (companyId == null) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Could not determine your company.';
        });
        return;
      }

      // Upload photo if we have one and are online
      String? uploadedPhotoUrl;
      if (_photoFile != null && ConnectivityService().isOnline) {
        final fileName =
            'recruits/${DateTime.now().millisecondsSinceEpoch}_${_idCtrl.text.trim()}.jpg';
        await SupabaseService.client.storage
            .from('photos')
            .upload(fileName, _photoFile!);
        uploadedPhotoUrl = SupabaseService.client.storage
            .from('photos')
            .getPublicUrl(fileName);
      }

      final result = await _recruitService.register(
        fullName: Validators.sanitize(_nameCtrl.text),
        idNumber: Validators.sanitize(_idCtrl.text),
        phone: Validators.sanitize(_phoneCtrl.text),
        region: _selectedRegion,
        fingerprintHash: _fingerprintHash,
        photoUrl: uploadedPhotoUrl,
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
                behavior: SnackBarBehavior.floating),
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
  void dispose() {
    _nameCtrl.dispose();
    _idCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppVerifiedGate(child: _buildScreen(context));
  }

  Widget _buildScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_foundExisting ? 'Recruit Found' : 'Register Recruit')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AppMaxWidth(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ConnectivityBanner(),
                const SizedBox(height: 8),

                // ── STEP 1: ID LOOKUP ──
                if (!_foundExisting && _existingRecruit == null) ...[
                  _sectionLabel(context, 'SCAN OR ENTER ID'),
                  const SizedBox(height: 12),
                  Text(
                    'Enter the recruit\'s ID number or capture their fingerprint. '
                    'If they are already in the system, their record will be shown.',
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 16),

                  // Fingerprint capture during lookup step
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.steelBlue.withOpacity(0.4)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.fingerprint,
                            size: 40,
                            color: _fingerprintCaptured
                                ? AppTheme.successGreen
                                : AppTheme.goldAccent),
                        const SizedBox(height: 8),
                        Text(
                            _fingerprintCaptured
                                ? '✓ Fingerprint Captured'
                                : 'Or capture fingerprint',
                            style: TextStyle(
                                color: _fingerprintCaptured
                                    ? AppTheme.successGreen
                                    : AppTheme.textMuted)),
                        const SizedBox(height: 8),
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
                  const SizedBox(height: 24),

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
                                      color: AppTheme.dangerRed,
                                      fontSize: 13))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  Center(
                    child: AppButton(
                      label: 'NEXT',
                      onPressed: _isLookingUp ? null : _lookupId,
                      isLoading: _isLookingUp,
                    ),
                  ),
                ],

                // ── RECRUIT FOUND ──
                if (_foundExisting && _existingRecruit != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.goldAccent.withOpacity(0.5)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.person_search,
                            color: AppTheme.goldAccent, size: 48),
                        const SizedBox(height: 12),
                        Text(_existingRecruit!['full_name'] ?? 'Unknown',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(_existingRecruit!['id_number'] ?? '',
                            style: const TextStyle(color: AppTheme.textMuted)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _existingRecruit!['status'] == 'clear'
                                ? AppTheme.successGreen.withOpacity(0.15)
                                : AppTheme.dangerRed.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            (_existingRecruit!['status'] ?? '')
                                .toString()
                                .toUpperCase(),
                            style: TextStyle(
                              color: _existingRecruit!['status'] == 'clear'
                                  ? AppTheme.successGreen
                                  : AppTheme.dangerRed,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                            'This recruit is already registered in the system.',
                            style: const TextStyle(color: AppTheme.textMuted)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AppButton.secondary(
                              label: 'VIEW FULL RECORD',
                              onPressed: () {
                                final recruit =
                                    DbRecruit.fromJson(_existingRecruit!);
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => RecruitProfileScreen(
                                            recruit: recruit)));
                              },
                            ),
                            const SizedBox(width: 12),
                            AppButton.secondary(
                              label: 'REGISTER NEW',
                              onPressed: () {
                                setState(() {
                                  _foundExisting = false;
                                  _existingRecruit = null;
                                  _idCtrl.clear();
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // ── STEP 2: REGISTRATION FORM (shown when ID not found) ──
                if (!_foundExisting &&
                    _existingRecruit == null &&
                    !_isLookingUp &&
                    _idCtrl.text.trim().isNotEmpty) ...[
                  _sectionLabel(context, 'NEW RECRUIT — COMPLETE FORM'),
                  const SizedBox(height: 16),

                  // Photo capture (mandatory)
                  _sectionLabel(context, 'PHOTO (REQUIRED)'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _photoFile != null
                              ? AppTheme.successGreen.withOpacity(0.4)
                              : AppTheme.steelBlue.withOpacity(0.4),
                        ),
                      ),
                      child: Column(
                        children: [
                          if (_photoFile != null) ...[
                            ClipOval(
                              child: Image.file(_photoFile!,
                                  width: 100, height: 100, fit: BoxFit.cover),
                            ),
                            const SizedBox(height: 8),
                            const Text('Tap to retake',
                                style: TextStyle(
                                    color: AppTheme.textMuted, fontSize: 12)),
                          ] else ...[
                            const Icon(Icons.camera_alt_outlined,
                                color: AppTheme.goldAccent, size: 48),
                            const SizedBox(height: 8),
                            const Text('Tap to take photo',
                                style: TextStyle(color: AppTheme.textMuted)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _sectionLabel(context, 'PERSONAL INFORMATION'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameCtrl,
                    style: const TextStyle(color: AppTheme.offWhite),
                    maxLength: Validators.nameMaxLength,
                    decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                        counterText: ''),
                    validator: Validators.fullName,
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
                        counterText: ''),
                    keyboardType: TextInputType.phone,
                    validator: Validators.phone,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedRegion,
                    dropdownColor: AppTheme.navyMid,
                    style: const TextStyle(color: AppTheme.offWhite),
                    decoration: const InputDecoration(
                        labelText: 'Region',
                        prefixIcon: Icon(Icons.location_on_outlined)),
                    items: _regions
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedRegion = v!),
                  ),
                  const SizedBox(height: 20),

                  _sectionLabel(context, 'EMPLOYMENT DETAILS'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    dropdownColor: AppTheme.navyMid,
                    style: const TextStyle(color: AppTheme.offWhite),
                    decoration: const InputDecoration(
                        labelText: 'Role / Position',
                        prefixIcon: Icon(Icons.work_outline)),
                    items: _roles
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedRole = v!),
                  ),
                  const SizedBox(height: 24),

                  _sectionLabel(context, 'BIOMETRIC CAPTURE'),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
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
                        Icon(Icons.fingerprint,
                            size: 48,
                            color: _fingerprintCaptured
                                ? AppTheme.successGreen
                                : AppTheme.goldAccent),
                        const SizedBox(height: 8),
                        Text(
                            _fingerprintCaptured
                                ? '✓ Fingerprint Captured'
                                : 'Fingerprint not yet captured',
                            style: TextStyle(
                                color: _fingerprintCaptured
                                    ? AppTheme.successGreen
                                    : AppTheme.textMuted)),
                        const SizedBox(height: 8),
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
                  const SizedBox(height: 24),

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
                                      color: AppTheme.dangerRed,
                                      fontSize: 13))),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Text(label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            letterSpacing: 2,
            color: AppTheme.goldAccent,
            fontWeight: FontWeight.w700));
  }
}
