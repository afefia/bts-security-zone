import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/db_models.dart';
import '../services/company_service.dart';
import '../widgets/connectivity_banner.dart';
import '../widgets/app_button.dart';

class CompanyListScreen extends StatefulWidget {
  const CompanyListScreen({super.key});

  @override
  State<CompanyListScreen> createState() => _CompanyListScreenState();
}

class _CompanyListScreenState extends State<CompanyListScreen> {
  final _companyService = CompanyService();
  bool _isLoading = true;
  String? _errorMessage;
  List<DbCompany> _companies = [];
  bool _fromCache = false;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final result = await _companyService.getAll();
      setState(() {
        _companies = result.companies;
        _fromCache = result.fromCache;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registered Companies')),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.goldAccent),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off,
                            color: AppTheme.dangerRed, size: 48),
                        const SizedBox(height: 16),
                        Text(_errorMessage!,
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        AppButton(
                          label: 'RETRY',
                          icon: Icons.refresh,
                          onPressed: _loadCompanies,
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCompanies,
                  color: AppTheme.goldAccent,
                  backgroundColor: AppTheme.cardBg,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const ConnectivityBanner(),

                        if (_fromCache) ...[
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.goldAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppTheme.goldAccent.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.cloud_off,
                                    color: AppTheme.goldAccent, size: 14),
                                const SizedBox(width: 8),
                                Text(
                                  'Showing cached company list',
                                  style: TextStyle(
                                      color: AppTheme.goldAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Summary
                        Row(
                          children: [
                            _SummaryChip(
                              label: 'Total',
                              value: '${_companies.length}',
                              color: AppTheme.goldAccent,
                            ),
                            const SizedBox(width: 10),
                            _SummaryChip(
                              label: 'Verified',
                              value:
                                  '${_companies.where((c) => c.isVerified).length}',
                              color: AppTheme.successGreen,
                            ),
                            const SizedBox(width: 10),
                            _SummaryChip(
                              label: 'Pending',
                              value:
                                  '${_companies.where((c) => !c.isVerified).length}',
                              color: AppTheme.dangerRed,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: _companies.isEmpty
                              ? Center(
                                  child: Text(
                                    'No companies registered yet',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                )
                              : ListView.builder(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  itemCount: _companies.length,
                                  itemBuilder: (context, i) {
                                    final c = _companies[i];
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppTheme.cardBg,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: c.isVerified
                                              ? AppTheme.successGreen
                                                  .withOpacity(0.3)
                                              : AppTheme.dangerRed
                                                  .withOpacity(0.3),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  c.name,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium,
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: c.isVerified
                                                      ? AppTheme.successGreen
                                                          .withOpacity(0.15)
                                                      : AppTheme.dangerRed
                                                          .withOpacity(0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  border: Border.all(
                                                    color: c.isVerified
                                                        ? AppTheme.successGreen
                                                            .withOpacity(0.5)
                                                        : AppTheme.dangerRed
                                                            .withOpacity(0.5),
                                                  ),
                                                ),
                                                child: Text(
                                                  c.isVerified
                                                      ? 'VERIFIED'
                                                      : 'PENDING',
                                                  style: TextStyle(
                                                    color: c.isVerified
                                                        ? AppTheme.successGreen
                                                        : AppTheme.dangerRed,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 1,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          _CompanyInfoRow(
                                            icon: Icons.badge_outlined,
                                            value: c.licenseNumber,
                                          ),
                                          _CompanyInfoRow(
                                            icon: Icons.location_on_outlined,
                                            value: c.region,
                                          ),
                                          _CompanyInfoRow(
                                            icon: Icons.email_outlined,
                                            value: c.email,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style:
                  Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanyInfoRow extends StatelessWidget {
  final IconData icon;
  final String value;

  const _CompanyInfoRow({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
