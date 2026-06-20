import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/db_models.dart';
import '../services/recruit_service.dart';
import '../services/local_db.dart';
import '../services/connectivity_service.dart';
import '../config/supabase_service.dart';
import '../widgets/connectivity_banner.dart';
import '../widgets/app_button.dart';
import '../utils/validators.dart';

class AddConductRecordScreen extends StatefulWidget {
  final DbRecruit recruit;

  const AddConductRecordScreen({super.key, required this.recruit});

  @override
  State<AddConductRecordScreen> createState() =>
      _AddConductRecordScreenState();
}

class _AddConductRecordScreenState extends State<AddConductRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedType = 'warning';
  final _descriptionCtrl = TextEditingController();
  final _reportedByCtrl = TextEditingController();
  DateTime _incidentDate = DateTime.now();
  bool _isSubmitting = false;
  String? _errorMessage;
  final _recruitService = RecruitService();

  static const List<String> _types = [
    'commendation',
    'warning',
    'suspension',
    'misconduct',
    'termination',
  ];

  final Map<String, String> _typeLabels = {
    'commendation': 'Commendation',
    'warning': 'Warning',
    'suspension': 'Suspension',
    'misconduct': 'Misconduct',
    'termination': 'Termination',
  };

  final Map<String, IconData> _typeIcons = {
    'commendation': Icons.star_outline,
    'warning': Icons.warning_amber_outlined,
    'suspension': Icons.pause_circle_outline,
    'misconduct': Icons.report_outlined,
    'termination': Icons.cancel_outlined,
  };

  Color _colorForType(String t) {
    switch (t) {
      case 'commendation':
        return AppTheme.successGreen;
      case 'warning':
        return AppTheme.goldLight;
      case 'suspension':
        return const Color(0xFFFF9F1C);
      case 'misconduct':
      case 'termination':
        return AppTheme.dangerRed;
      default:
        return AppTheme.textMuted;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _incidentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.goldAccent,
            surface: AppTheme.cardBg,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _incidentDate = picked);
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
          // Fall through to cached value below.
        }
      }
      companyId ??= await LocalDb.getMyCachedCompanyId();

      if (companyId == null) {
        setState(() {
          _isSubmitting = false;
          _errorMessage =
              'Could not determine your company. Please connect to the '
              'internet at least once before adding records offline.';
        });
        return;
      }

      final result = await _recruitService.addConductRecord(
        recruitId: widget.recruit.id,
        companyId: companyId,
        type: _selectedType,
        description: Validators.sanitize(_descriptionCtrl.text),
        reportedBy: Validators.sanitize(_reportedByCtrl.text),
        incidentDate: _incidentDate,
      );

      setState(() => _isSubmitting = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.queuedOffline
                  ? 'Saved offline — will sync once back online'
                  : '${_typeLabels[_selectedType]} record added for ${widget.recruit.fullName}',
            ),
            backgroundColor: result.queuedOffline
                ? AppTheme.goldAccent
                : AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Add Conduct Record')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ConnectivityBanner(),

              // Recruit info banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.steelBlue.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.goldAccent.withOpacity(0.2),
                      child: Text(
                        widget.recruit.fullName[0],
                        style: const TextStyle(
                            color: AppTheme.goldAccent,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.recruit.fullName,
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(widget.recruit.idNumber,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _sectionLabel(context, 'RECORD TYPE'),
              const SizedBox(height: 12),

              // Type selector
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.2,
                children: _types.map((type) {
                  final isSelected = _selectedType == type;
                  final color = _colorForType(type);
                  return GestureDetector(
                    onTap: () => setState(() => _selectedType = type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withOpacity(0.2)
                            : AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? color
                              : AppTheme.steelBlue.withOpacity(0.4),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_typeIcons[type], color: color, size: 22),
                          const SizedBox(height: 4),
                          Text(
                            _typeLabels[type]!,
                            style: TextStyle(
                              color: isSelected ? color : AppTheme.textMuted,
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              _sectionLabel(context, 'INCIDENT DETAILS'),
              const SizedBox(height: 12),

              // Date picker
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.steelBlue.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppTheme.steelBlue.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          color: AppTheme.goldAccent, size: 18),
                      const SizedBox(width: 12),
                      Text(
                        'Incident Date:  '
                        '${_incidentDate.day}/${_incidentDate.month}/${_incidentDate.year}',
                        style: const TextStyle(color: AppTheme.offWhite),
                      ),
                      const Spacer(),
                      const Icon(Icons.edit_outlined,
                          color: AppTheme.textMuted, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _descriptionCtrl,
                style: const TextStyle(color: AppTheme.offWhite),
                maxLines: 4,
                maxLength: Validators.conductDescriptionMaxLength,
                decoration: const InputDecoration(
                  labelText: 'Description / Details',
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 60),
                    child: Icon(Icons.notes_outlined),
                  ),
                  alignLabelWithHint: true,
                  counterText: '',
                ),
                validator: Validators.conductDescription,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _reportedByCtrl,
                style: const TextStyle(color: AppTheme.offWhite),
                maxLength: Validators.reportedByMaxLength,
                decoration: const InputDecoration(
                  labelText: 'Reported By',
                  prefixIcon: Icon(Icons.person_outline),
                  hintText: 'Supervisor name or designation',
                  counterText: '',
                ),
                validator: Validators.reportedBy,
              ),
              const SizedBox(height: 32),

              // Warning for serious records
              if (_selectedType == 'termination' ||
                  _selectedType == 'misconduct') ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppTheme.dangerRed.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning,
                          color: AppTheme.dangerRed, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          ConnectivityService().isOnline
                              ? 'This record will permanently flag this recruit '
                                  'and alert all companies when they are searched.'
                              : 'You are offline. This record will be saved '
                                  'locally and the recruit will only be '
                                  'flagged for other companies once it syncs.',
                          style: TextStyle(
                              color: AppTheme.dangerRed.withOpacity(0.9),
                              fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

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


            ],
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
