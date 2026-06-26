import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../config/supabase_service.dart';
import '../widgets/app_button.dart';
import '../widgets/app_max_width.dart';
import '../widgets/app_verified_gate.dart';
import '../utils/validators.dart';

class CompanyUsersScreen extends StatefulWidget {
  const CompanyUsersScreen({super.key});

  @override
  State<CompanyUsersScreen> createState() => _CompanyUsersScreenState();
}

class _CompanyUsersScreenState extends State<CompanyUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _companyId;

  // Invite dialog
  final _inviteEmailCtrl = TextEditingController();
  final _inviteNameCtrl = TextEditingController();
  String _inviteRole = 'company_user';
  bool _isInviting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final user = SupabaseService.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Not authenticated';
        });
        return;
      }

      // Get the current user's company
      final userData = await SupabaseService.client
          .from('users')
          .select('company_id')
          .eq('id', user.id)
          .maybeSingle();

      if (userData == null || userData['company_id'] == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No company found for your account.';
        });
        return;
      }

      _companyId = userData['company_id'] as String;

      // Get all users in this company
      final data = await SupabaseService.client
          .from('users')
          .select('id, full_name, email, role, created_at')
          .eq('company_id', _companyId as Object)
          .order('full_name');

      setState(() {
        _users = (data as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Failed to load users: ${e.toString().replaceFirst("Exception: ", "")}';
      });
    }
  }

  Future<void> _inviteUser() async {
    if (_inviteEmailCtrl.text.trim().isEmpty ||
        _inviteNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill in all fields'),
            backgroundColor: AppTheme.dangerRed,
            behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _isInviting = true);

    try {
      if (_companyId == null) {
        setState(() => _isInviting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No company ID. Cannot add user.'),
              backgroundColor: AppTheme.dangerRed,
              behavior: SnackBarBehavior.floating),
        );
        return;
      }

      final email = _inviteEmailCtrl.text.trim();
      final name = Validators.sanitize(_inviteNameCtrl.text.trim());
      final role = _inviteRole;
      final tempPassword = 'Temp@${DateTime.now().millisecondsSinceEpoch}';

      // Create auth account
      User? newUser;
      try {
        final authResponse = await SupabaseService.client.auth.signUp(
          email: email,
          password: tempPassword,
        );
        newUser = authResponse.user;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${e.toString().replaceFirst("Exception: ", "")}'),
              backgroundColor: AppTheme.dangerRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        setState(() => _isInviting = false);
        return;
      }

      if (newUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Failed to create user. The email may already be registered.'),
              backgroundColor: AppTheme.dangerRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        setState(() => _isInviting = false);
        return;
      }

      // Link the new user to this company
      await SupabaseService.client.from('users').insert(<String, dynamic>{
        'id': newUser!.id,
        'company_id': _companyId,
        'full_name': name,
        'email': email,
        'role': role,
      });

      setState(() => _isInviting = false);
      Navigator.pop(context); // Close dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User invited! Temporary password: $tempPassword'),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );

      _load(); // Refresh the list
    } catch (e) {
      setState(() => _isInviting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Error: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: AppTheme.dangerRed,
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _showInviteDialog() {
    _inviteEmailCtrl.clear();
    _inviteNameCtrl.clear();
    _inviteRole = 'company_user';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Add System User'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _inviteNameCtrl,
                style: const TextStyle(color: AppTheme.offWhite),
                decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                    counterText: ''),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _inviteEmailCtrl,
                style: const TextStyle(color: AppTheme.offWhite),
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    counterText: ''),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _inviteRole,
                dropdownColor: AppTheme.navyMid,
                style: const TextStyle(color: AppTheme.offWhite),
                decoration: const InputDecoration(
                    labelText: 'Role',
                    prefixIcon: Icon(Icons.admin_panel_settings)),
                items: const [
                  DropdownMenuItem(
                      value: 'company_admin', child: Text('Company Admin')),
                  DropdownMenuItem(value: 'company_user', child: Text('User')),
                  DropdownMenuItem(
                      value: 'company_viewer',
                      child: Text('Viewer (read-only)')),
                ],
                onChanged: (v) => setState(() => _inviteRole = v!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          AppButton(
            label: 'ADD USER',
            isLoading: _isInviting,
            onPressed: () {
              _inviteUser();
            },
          ),
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'ADMIN';
      case 'company_admin':
        return 'COMPANY ADMIN';
      case 'company_user':
        return 'USER';
      case 'company_viewer':
        return 'VIEWER';
      default:
        return role.toUpperCase();
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
      case 'company_admin':
        return AppTheme.goldAccent;
      case 'company_user':
        return AppTheme.successGreen;
      case 'company_viewer':
        return AppTheme.textMuted;
      default:
        return AppTheme.textMuted;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'admin':
      case 'company_admin':
        return Icons.admin_panel_settings;
      case 'company_user':
        return Icons.person;
      case 'company_viewer':
        return Icons.visibility;
      default:
        return Icons.person_outline;
    }
  }

  @override
  void dispose() {
    _inviteEmailCtrl.dispose();
    _inviteNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppVerifiedGate(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Company Users'),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: _showInviteDialog,
              tooltip: 'Add user',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.goldAccent))
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppTheme.dangerRed, size: 48),
                          const SizedBox(height: 12),
                          Text(_errorMessage!,
                              textAlign: TextAlign.center,
                              style:
                                  const TextStyle(color: AppTheme.dangerRed)),
                        ],
                      ),
                    ),
                  )
                : _users.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people_outline,
                                color: AppTheme.textMuted, size: 48),
                            const SizedBox(height: 12),
                            const Text('No users found',
                                style: TextStyle(color: AppTheme.textMuted)),
                            const SizedBox(height: 16),
                            AppButton.secondary(
                              label: 'ADD USER',
                              onPressed: _showInviteDialog,
                            ),
                          ],
                        ),
                      )
                    : AppMaxWidth(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _users.length,
                          itemBuilder: (ctx, i) {
                            final u = _users[i];
                            final role = u['role'] as String? ?? 'company_user';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.cardBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: AppTheme.steelBlue.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor:
                                        _roleColor(role).withOpacity(0.2),
                                    radius: 20,
                                    child: Icon(_roleIcon(role),
                                        color: _roleColor(role), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(u['full_name'] ?? '',
                                            style: const TextStyle(
                                                color: AppTheme.offWhite,
                                                fontWeight: FontWeight.w600)),
                                        Text(u['email'] ?? '',
                                            style: const TextStyle(
                                                color: AppTheme.textMuted,
                                                fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _roleColor(role).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _roleLabel(role),
                                      style: TextStyle(
                                        color: _roleColor(role),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}
