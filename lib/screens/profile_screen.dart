import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/company_service.dart';
import '../models/db_models.dart';
import '../utils/validators.dart';
import '../widgets/app_button.dart';
import '../widgets/app_max_width.dart';
import '../widgets/app_skeleton.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _authService = AuthService();
  final _companyService = CompanyService();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  DbUserProfile? _profile;
  DbCompany? _company;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _companyService.getMyProfile();
      final company = await _companyService.getMyCompany();
      setState(() {
        _profile = profile;
        _company = company;
        _nameCtrl.text = profile?.fullName ?? '';
        _emailCtrl.text = profile?.email ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final emailChanged = _emailCtrl.text.trim() != _profile?.email;

    final result = await _authService.updateProfile(
      fullName: Validators.sanitize(_nameCtrl.text),
      email: Validators.sanitize(_emailCtrl.text),
    );

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            emailChanged
                ? 'Profile updated. Check your new email to confirm the change.'
                : 'Profile updated.',
          ),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _load();
    } else {
      setState(() => _errorMessage = result.error ?? 'Could not save changes');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Account')),
      body: _isLoading
          ? AppMaxWidth(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: const [
                    Center(
                      child: AppSkeletonBox(
                          width: 72, height: 72, borderRadius: 36),
                    ),
                    SizedBox(height: 28),
                    AppSkeletonBox(height: 56),
                    SizedBox(height: 16),
                    AppSkeletonBox(height: 56),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: AppMaxWidth(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 36,
                        backgroundColor: AppTheme.goldAccent,
                        child: Text(
                          (_profile?.fullName.isNotEmpty == true)
                              ? _profile!.fullName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.navyDark,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        _company?.name ?? '',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    if (_profile?.isAdmin == true) ...[
                      const SizedBox(height: 6),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.goldAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'ADMIN',
                            style: TextStyle(
                              color: AppTheme.goldAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
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
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailCtrl,
                      style: const TextStyle(color: AppTheme.offWhite),
                      keyboardType: TextInputType.emailAddress,
                      maxLength: Validators.emailMaxLength,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        counterText: '',
                        helperText:
                            'Changing this sends a confirmation link to the new address',
                        helperMaxLines: 2,
                      ),
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 8),
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.dangerRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppTheme.dangerRed.withOpacity(0.4)),
                        ),
                        child: Text(_errorMessage!,
                            style: const TextStyle(
                                color: AppTheme.dangerRed, fontSize: 13)),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Center(
                      child: AppButton(
                        label: 'SAVE CHANGES',
                        isLoading: _isSaving,
                        onPressed: _isSaving ? null : _save,
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
