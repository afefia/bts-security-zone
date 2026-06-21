import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../theme/app_theme.dart';
import '../models/db_models.dart';
import '../widgets/connectivity_banner.dart';
import '../widgets/app_button.dart';
import '../widgets/app_max_width.dart';
import '../services/recruit_service.dart';
import '../services/recruit_pdf_service.dart';
import '../services/company_service.dart';
import 'add_conduct_record_screen.dart';
import 'file_dispute_screen.dart';

class RecruitProfileScreen extends StatefulWidget {
  final DbRecruit recruit;

  const RecruitProfileScreen({super.key, required this.recruit});

  @override
  State<RecruitProfileScreen> createState() => _RecruitProfileScreenState();
}

class _RecruitProfileScreenState extends State<RecruitProfileScreen> {
  bool _isExporting = false;
  bool _isRefreshing = false;
  final _companyService = CompanyService();
  final _recruitService = RecruitService();
  late DbRecruit _recruit;

  DbRecruit get recruit => _recruit;

  @override
  void initState() {
    super.initState();
    _recruit = widget.recruit;
  }

  /// Re-fetches this recruit from the server (or cache, if offline) and
  /// swaps it into state — used after an action that changes the data
  /// shown on this screen (closing employment, adding a record) so the
  /// person sees the result immediately instead of stale data until they
  /// back out and re-search.
  Future<void> _refreshRecruit() async {
    setState(() => _isRefreshing = true);
    try {
      final updated = await _recruitService.getById(_recruit.id);
      if (updated != null && mounted) {
        setState(() => _recruit = updated);
      }
    } catch (_) {
      // Keep showing the last-known data rather than erroring the screen
      // over a refresh failure.
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);

    try {
      // Best-effort — falls back to a generic label if offline or the
      // company lookup fails, rather than blocking the export entirely.
      String companyName = 'The Security Zone';
      try {
        final myCompany = await _companyService.getMyCompany();
        if (myCompany != null) companyName = myCompany.name;
      } catch (_) {}

      final bytes = await RecruitPdfService.generateRecruitReport(
        recruit: recruit,
        generatedByCompanyName: companyName,
      );

      if (!mounted) return;
      setState(() => _isExporting = false);

      await _shareOrPrint(bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Could not generate report: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    }
  }

  Future<void> _shareOrPrint(List<int> bytes) async {
    if (!mounted) return;

    final fileName =
        'recruit_${recruit.idNumber.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_')}.pdf';

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.steelBlue,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Report Ready',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Text(
                    '${recruit.fullName} — verification report',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.share_outlined,
                      color: AppTheme.goldAccent),
                  title: const Text('Share / Save',
                      style: TextStyle(color: AppTheme.offWhite)),
                  subtitle: Text(
                    'Send via email, WhatsApp, or save to files',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await Printing.sharePdf(
                      bytes: Uint8List.fromList(bytes),
                      filename: fileName,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.print_outlined,
                      color: AppTheme.goldAccent),
                  title: const Text('Print',
                      style: TextStyle(color: AppTheme.offWhite)),
                  subtitle: Text(
                    'Send to a connected or network printer',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await Printing.layoutPdf(
                      onLayout: (_) async => Uint8List.fromList(bytes),
                      name: fileName,
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recruit Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddConductRecordScreen(recruit: recruit),
                ),
              );
              _refreshRecruit();
            },
            tooltip: 'Add Conduct Record',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AppMaxWidth(
          maxWidth: 600,
          child: Column(
          children: [
            const ConnectivityBanner(),
            if (_isRefreshing)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(
                  color: AppTheme.goldAccent,
                  backgroundColor: AppTheme.steelBlue,
                  minHeight: 2,
                ),
              ),

            // Profile header
            _buildHeader(context),
            const SizedBox(height: 20),

            // Status alert
            if (recruit.status != 'clear') ...[
              _buildStatusAlert(context),
              const SizedBox(height: 20),
            ],

            // ID Details
            _buildSection(
              context,
              title: 'IDENTIFICATION',
              child: Column(
                children: [
                  _InfoRow(label: 'Full Name', value: recruit.fullName),
                  _InfoRow(label: 'ID Number', value: recruit.idNumber),
                  _InfoRow(label: 'Phone', value: recruit.phone ?? 'Not provided'),
                  _InfoRow(label: 'Region', value: recruit.region),
                  _InfoRow(
                    label: 'Registered',
                    value:
                        '${recruit.registeredAt.day}/${recruit.registeredAt.month}/${recruit.registeredAt.year}',
                  ),
                  _InfoRow(
                    label: 'Fingerprint',
                    value: recruit.fingerprintHash != null
                        ? '✓ On File'
                        : 'Not Registered',
                    valueColor: recruit.fingerprintHash != null
                        ? AppTheme.successGreen
                        : AppTheme.dangerRed,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Employment history
            _buildSection(
              context,
              title: 'EMPLOYMENT HISTORY',
              child: Column(
                children: recruit.employmentHistory.reversed
                    .map((e) => _EmploymentTile(
                          employment: e,
                          onEmploymentClosed: _refreshRecruit,
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Conduct records
            _buildSection(
              context,
              title: 'CONDUCT RECORDS (${recruit.conductRecords.length})',
              child: recruit.conductRecords.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'No conduct records on file.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : Column(
                      children: recruit.conductRecords.reversed
                          .map((c) => _ConductTile(record: c))
                          .toList(),
                    ),
            ),
            const SizedBox(height: 24),

            // Action buttons
            Center(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  AppButton.secondary(
                    label: 'ADD RECORD',
                    icon: Icons.add_circle_outline,
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AddConductRecordScreen(recruit: recruit),
                        ),
                      );
                      _refreshRecruit();
                    },
                  ),
                  AppButton(
                    label: _isExporting ? 'GENERATING...' : 'EXPORT PDF',
                    icon: Icons.picture_as_pdf_outlined,
                    isLoading: _isExporting,
                    onPressed: _isExporting ? null : _exportPdf,
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.navyMid, AppTheme.steelBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: recruit.statusColor.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: recruit.statusColor.withOpacity(0.2),
            child: Text(
              recruit.fullName[0],
              style: TextStyle(
                color: recruit.statusColor,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recruit.fullName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  recruit.idNumber,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: recruit.statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: recruit.statusColor.withOpacity(0.6),
                        ),
                      ),
                      child: Text(
                        recruit.statusLabel,
                        style: TextStyle(
                          color: recruit.statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${recruit.employmentHistory.length} companies',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusAlert(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: recruit.statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: recruit.statusColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: recruit.statusColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This recruit has a ${recruit.statusLabel.toLowerCase()} flag. '
              'Review conduct records before onboarding.',
              style: TextStyle(
                color: recruit.statusColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.steelBlue.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: AppTheme.goldAccent,
              ),
            ),
          ),
          const Divider(color: AppTheme.steelBlue, height: 1),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmploymentTile extends StatelessWidget {
  final DbEmploymentHistory employment;
  final VoidCallback? onEmploymentClosed;

  const _EmploymentTile({required this.employment, this.onEmploymentClosed});

  void _showCloseDialog(BuildContext context) {
    final reasonCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.navyMid,
          title: const Text('Close Employment',
              style: TextStyle(color: AppTheme.offWhite)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recording the end of ${employment.role} at ${employment.companyName}.',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today,
                    color: AppTheme.goldAccent, size: 18),
                title: Text(
                  'End Date: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                  style: const TextStyle(color: AppTheme.offWhite, fontSize: 13),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: employment.startDate,
                    lastDate: DateTime.now(),
                    builder: (c, child) => Theme(
                      data: Theme.of(c).copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: AppTheme.goldAccent,
                          surface: AppTheme.navyMid,
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    setDialogState(() => selectedDate = picked);
                  }
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reasonCtrl,
                style: const TextStyle(color: AppTheme.offWhite),
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Exit Reason (optional)',
                  hintText: 'Resigned, contract ended...',
                ),
              ),
            ],
          ),
          actions: [
            AppButton.text(
              label: 'CANCEL',
              onPressed: () => Navigator.pop(ctx),
            ),
            AppButton(
              label: 'CLOSE EMPLOYMENT',
              compact: true,
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await RecruitService().closeEmployment(
                    employmentId: employment.id,
                    endDate: selectedDate,
                    exitReason: reasonCtrl.text.trim().isEmpty
                        ? null
                        : reasonCtrl.text.trim(),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Employment record closed'),
                        backgroundColor: AppTheme.successGreen,
                      ),
                    );
                    onEmploymentClosed?.call();
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            e.toString().replaceFirst('Exception: ', '')),
                        backgroundColor: AppTheme.dangerRed,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final start =
        '${employment.startDate.month}/${employment.startDate.year}';
    final end = employment.isCurrent
        ? 'Present'
        : '${employment.endDate!.month}/${employment.endDate!.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: employment.isCurrent
                      ? AppTheme.successGreen
                      : AppTheme.textMuted,
                ),
              ),
              if (true)
                Container(width: 2, height: 40, color: AppTheme.steelBlue),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employment.companyName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  employment.role,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '$start – $end',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 11,
                    color: AppTheme.goldAccent,
                  ),
                ),
                if (employment.exitReason != null && !employment.isCurrent)
                  Text(
                    employment.exitReason!,
                    style: const TextStyle(
                      color: AppTheme.dangerRed,
                      fontSize: 11,
                    ),
                  ),
                if (employment.isCurrent) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.logout,
                          size: 12, color: AppTheme.textMuted),
                      label: const Text(
                        'CLOSE EMPLOYMENT',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _showCloseDialog(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConductTile extends StatelessWidget {
  final DbConductRecord record;

  const _ConductTile({required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: record.typeColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: record.typeColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: record.typeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  record.typeLabel.toUpperCase(),
                  style: TextStyle(
                    color: record.typeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Text(
                '${record.incidentDate.day}/${record.incidentDate.month}/${record.incidentDate.year}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(record.companyName,
              style: const TextStyle(
                color: AppTheme.goldAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 4),
          Text(record.description, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 4),
          Text(
            'Reported by: ${record.reportedBy}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.flag_outlined,
                  size: 13, color: AppTheme.textMuted),
              label: const Text(
                'DISPUTE',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                  letterSpacing: 0.8,
                ),
              ),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FileDisputeScreen(record: record),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
