import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/db_models.dart';
import '../services/dispute_service.dart';
import '../utils/validators.dart';
import '../widgets/app_button.dart';
import '../widgets/app_max_width.dart';

class FileDisputeScreen extends StatefulWidget {
  final DbConductRecord record;

  const FileDisputeScreen({super.key, required this.record});

  @override
  State<FileDisputeScreen> createState() => _FileDisputeScreenState();
}

class _FileDisputeScreenState extends State<FileDisputeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();
  final _disputeService = DisputeService();
  bool _isSubmitting = false;
  String? _errorMessage;

  static final _dateFmt = DateFormat('d MMM yyyy');

  DbConductRecord get record => widget.record;

  String _conductLabel(String type) {
    switch (type) {
      case 'commendation': return 'Commendation';
      case 'warning': return 'Warning';
      case 'suspension': return 'Suspension';
      case 'termination': return 'Termination';
      case 'misconduct': return 'Misconduct';
      default: return type;
    }
  }

  Color _conductColor(String type) {
    switch (type) {
      case 'commendation': return AppTheme.successGreen;
      case 'warning': return AppTheme.goldLight;
      case 'suspension': return const Color(0xFFFF9F1C);
      case 'termination':
      case 'misconduct': return AppTheme.dangerRed;
      default: return AppTheme.textMuted;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _disputeService.fileDispute(
        conductRecordId: record.id,
        reason: _reasonCtrl.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dispute filed. An admin will review it and respond.'),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true); // true = was filed
    } on ArgumentError catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _conductColor(record.type);

    return Scaffold(
      appBar: AppBar(title: const Text('File a Dispute')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AppMaxWidth(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Record summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _conductLabel(record.type).toUpperCase(),
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _dateFmt.format(record.incidentDate),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Filed by: ${record.companyName}',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      record.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Reported by: ${record.reportedBy}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Explanation
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.steelBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.steelBlue.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: AppTheme.offWhite, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'About disputes',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A dispute flags this record for admin review. The record stays visible with a DISPUTED badge while the review is in progress. If the admin upholds your dispute, the record is removed. If rejected, it stands.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Reason
              Text(
                'REASON FOR DISPUTE',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 11,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.goldAccent,
                    ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reasonCtrl,
                maxLines: 6,
                maxLength: 2000,
                style: const TextStyle(color: AppTheme.offWhite),
                decoration: const InputDecoration(
                  hintText:
                      'Explain why this record is inaccurate or unfair. Be specific — include dates, names, or other evidence where possible.',
                  alignLabelWithHint: true,
                  counterStyle: TextStyle(color: AppTheme.textMuted),
                ),
                validator: (v) {
                  final s = Validators.sanitize(v ?? '');
                  if (s.length < 20) {
                    return 'Please provide a detailed reason (at least 20 characters)';
                  }
                  return null;
                },
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
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppTheme.dangerRed, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMessage!,
                            style: const TextStyle(
                                color: AppTheme.dangerRed, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              Center(
                child: AppButton(
                  label: 'FILE DISPUTE',
                  icon: Icons.flag_outlined,
                  isLoading: _isSubmitting,
                  onPressed: _isSubmitting ? null : _submit,
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
