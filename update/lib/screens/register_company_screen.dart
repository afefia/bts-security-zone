import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';
import '../widgets/app_button.dart';
import '../widgets/app_max_width.dart';

class RegisterCompanyScreen extends StatefulWidget {
  const RegisterCompanyScreen({super.key});

  @override
  State<RegisterCompanyScreen> createState() => _RegisterCompanyScreenState();
}

class _RegisterCompanyScreenState extends State<RegisterCompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _agreedToTerms = false;
  bool _isLoading = false;
  String _selectedRegion = 'Greater Accra';
  int _currentStep = 0;
  final _authService = AuthService();

  final List<String> _regions = [
    'Greater Accra', 'Ashanti', 'Western', 'Eastern',
    'Central', 'Volta', 'Northern', 'Upper East', 'Upper West', 'Bono',
  ];

  Future<void> _submit() async {
    // Validate every field explicitly here rather than relying on the
    // Stepper's broken per-step Form/key setup — each field is checked
    // against the same Validators rules used by the service layer, so
    // the validation behaviour is consistent no matter what path called
    // this method.
    final errors = <String>[];

    final nameErr = Validators.companyName(_nameCtrl.text);
    if (nameErr != null) errors.add(nameErr);

    final licenseErr = Validators.licenseNumber(_licenseCtrl.text);
    if (licenseErr != null) errors.add(licenseErr);

    final contactErr = Validators.fullName(_contactNameCtrl.text);
    if (contactErr != null) errors.add('Contact name: $contactErr');

    final emailErr = Validators.email(_emailCtrl.text);
    if (emailErr != null) errors.add(emailErr);

    final phoneErr = Validators.phone(_phoneCtrl.text);
    if (phoneErr != null) errors.add(phoneErr);

    final addrErr = Validators.address(_addressCtrl.text);
    if (addrErr != null) errors.add(addrErr);

    final pwErr = Validators.password(_passwordCtrl.text);
    if (pwErr != null) errors.add(pwErr);

    if (_passwordCtrl.text != _confirmCtrl.text) {
      errors.add('Passwords do not match');
    }

    if (!_agreedToTerms) {
      errors.add('You must agree to the Terms & Conditions');
    }

    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errors.first),
          backgroundColor: AppTheme.dangerRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await _authService.registerCompany(
      companyName: Validators.sanitize(_nameCtrl.text),
      licenseNumber: Validators.sanitize(_licenseCtrl.text),
      region: _selectedRegion,
      address: Validators.sanitize(_addressCtrl.text),
      email: Validators.sanitize(_emailCtrl.text),
      phone: Validators.sanitize(_phoneCtrl.text),
      password: _passwordCtrl.text,
      fullName: Validators.sanitize(_contactNameCtrl.text),
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Registration failed'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Icon(
            result.needsEmailConfirmation
                ? Icons.mark_email_unread_outlined
                : Icons.check_circle,
            color: result.needsEmailConfirmation
                ? AppTheme.goldAccent
                : AppTheme.successGreen,
            size: 48,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                result.needsEmailConfirmation
                    ? 'Confirm Your Email'
                    : 'Application Submitted!',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                result.needsEmailConfirmation
                    ? 'We sent a confirmation link to ${_emailCtrl.text.trim()}. '
                        'Please confirm your email before signing in. '
                        'After that, your company will still need to be '
                        'verified by our admin team before you can search '
                        'other companies\' records.'
                    : 'Your company registration is under review. '
                        'You will receive an email once verified by our admin team.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            Center(
              child: AppButton(
                label: 'BACK TO LOGIN',
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register Company')),
      body: AppMaxWidth(
        maxWidth: 600,
        child: Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context)
                .colorScheme
                .copyWith(primary: AppTheme.goldAccent),
          ),
          child: Stepper(
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 2) setState(() => _currentStep++);
            else _submit();
          },
          onStepCancel: () {
            if (_currentStep > 0) setState(() => _currentStep--);
          },
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppButton(
                      label: _currentStep == 2 ? 'SUBMIT' : 'NEXT',
                      onPressed: _isLoading ? null : details.onStepContinue,
                      isLoading: _isLoading && _currentStep == 2,
                    ),
                    if (_currentStep > 0) ...[
                      const SizedBox(width: 12),
                      AppButton.secondary(
                        label: 'BACK',
                        onPressed: details.onStepCancel,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
          steps: [
            Step(
              title: const Text('Company Info',
                  style: TextStyle(color: AppTheme.offWhite)),
              isActive: _currentStep >= 0,
              state: _currentStep > 0
                  ? StepState.complete
                  : StepState.indexed,
              content: Form(
                key: _currentStep == 0 ? _formKey : null,
                child: Column(
                  children: [
                  TextFormField(
                    controller: _nameCtrl,
                    style: const TextStyle(color: AppTheme.offWhite),
                    maxLength: Validators.companyNameMaxLength,
                    decoration: const InputDecoration(
                      labelText: 'Company Name',
                      prefixIcon: Icon(Icons.business),
                      counterText: '',
                    ),
                    validator: Validators.companyName,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _licenseCtrl,
                    style: const TextStyle(color: AppTheme.offWhite),
                    maxLength: Validators.licenseNumberMaxLength,
                    decoration: const InputDecoration(
                      labelText: 'License Number',
                      prefixIcon: Icon(Icons.badge_outlined),
                      hintText: 'PSC-GH-XXXX',
                      counterText: '',
                    ),
                    validator: Validators.licenseNumber,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedRegion,
                    dropdownColor: AppTheme.navyMid,
                    style: const TextStyle(color: AppTheme.offWhite),
                    decoration: const InputDecoration(
                      labelText: 'Region',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    items: _regions
                        .map((r) =>
                            DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedRegion = v!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressCtrl,
                    style: const TextStyle(color: AppTheme.offWhite),
                    maxLength: Validators.addressMaxLength,
                    decoration: const InputDecoration(
                      labelText: 'Physical Address',
                      prefixIcon: Icon(Icons.map_outlined),
                      counterText: '',
                    ),
                    maxLines: 2,
                    validator: (v) => Validators.address(v),
                  ),
                  ],
                ),
              ),
            ),
            Step(
              title: const Text('Contact Details',
                  style: TextStyle(color: AppTheme.offWhite)),
              isActive: _currentStep >= 1,
              state: _currentStep > 1
                  ? StepState.complete
                  : StepState.indexed,
              content: Column(
                children: [
                  TextFormField(
                    controller: _contactNameCtrl,
                    style: const TextStyle(color: AppTheme.offWhite),
                    maxLength: Validators.nameMaxLength,
                    decoration: const InputDecoration(
                      labelText: 'Your Full Name (Account Owner)',
                      prefixIcon: Icon(Icons.person_outline),
                      counterText: '',
                    ),
                    validator: Validators.fullName,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    style: const TextStyle(color: AppTheme.offWhite),
                    keyboardType: TextInputType.emailAddress,
                    maxLength: Validators.emailMaxLength,
                    decoration: const InputDecoration(
                      labelText: 'Official Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      counterText: '',
                    ),
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneCtrl,
                    style: const TextStyle(color: AppTheme.offWhite),
                    keyboardType: TextInputType.phone,
                    maxLength: Validators.phoneMaxLength,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone_outlined),
                      counterText: '',
                    ),
                    validator: Validators.phone,
                  ),
                ],
              ),
            ),
            Step(
              title: const Text('Account Setup',
                  style: TextStyle(color: AppTheme.offWhite)),
              isActive: _currentStep >= 2,
              content: Column(
                children: [
                  TextFormField(
                    controller: _passwordCtrl,
                    style: const TextStyle(color: AppTheme.offWhite),
                    obscureText: _obscure1,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      helperText: 'At least 8 characters, with letters and numbers',
                      helperStyle: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 11),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure1
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppTheme.textMuted,
                        ),
                        onPressed: () =>
                            setState(() => _obscure1 = !_obscure1),
                      ),
                    ),
                    validator: Validators.password,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmCtrl,
                    style: const TextStyle(color: AppTheme.offWhite),
                    obscureText: _obscure2,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure2
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppTheme.textMuted,
                        ),
                        onPressed: () =>
                            setState(() => _obscure2 = !_obscure2),
                      ),
                    ),
                    validator: (v) => v != _passwordCtrl.text
                        ? 'Passwords do not match'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: _agreedToTerms,
                        activeColor: AppTheme.goldAccent,
                        onChanged: (v) =>
                            setState(() => _agreedToTerms = v!),
                      ),
                      Expanded(
                        child: Text(
                          'I agree to the Terms of Service and Data Privacy Policy',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
