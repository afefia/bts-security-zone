import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../models/db_models.dart';
import '../services/admin_service.dart';
import '../services/company_service.dart';
import '../services/dispute_service.dart';
import '../widgets/app_button.dart';
import '../widgets/app_max_width.dart';
import '../widgets/app_skeleton.dart';
import '../widgets/app_loading_indicator.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppTheme.goldAccent,
          labelColor: AppTheme.goldAccent,
          unselectedLabelColor: AppTheme.textMuted,
          tabs: const [
            Tab(text: 'OVERVIEW'),
            Tab(text: 'ANALYTICS'),
            Tab(text: 'DISPUTES'),
            Tab(text: 'COMPANIES'),
            Tab(text: 'AUDIT LOG'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _OverviewTab(),
          _AnalyticsTab(),
          _DisputesAdminTab(),
          _CompaniesAdminTab(),
          _AuditLogTab(),
        ],
      ),
    );
  }
}

// ── Overview Tab ──────────────────────────────────────────────────────────────

class _OverviewTab extends StatefulWidget {
  const _OverviewTab();

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  final _adminService = AdminService();
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, int> _stats = {};
  List<DbAuditEntry> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final stats = await _adminService.getOverviewStats();
      final activity = await _adminService.getAuditLog(limit: 6);
      setState(() {
        _stats = stats;
        _recentActivity = activity;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  IconData _iconForAction(String action) {
    switch (action) {
      case 'SEARCH':
        return Icons.search;
      case 'ADD_RECORD':
        return Icons.flag;
      case 'REGISTER':
        return Icons.person_add;
      case 'VERIFY':
        return Icons.verified;
      case 'LOGIN':
        return Icons.login;
      default:
        return Icons.history;
    }
  }

  Color _colorForAction(String action) {
    switch (action) {
      case 'SEARCH':
        return AppTheme.steelBlue;
      case 'ADD_RECORD':
        return AppTheme.dangerRed;
      case 'REGISTER':
        return AppTheme.successGreen;
      case 'VERIFY':
        return AppTheme.goldAccent;
      default:
        return AppTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return AppMaxWidth(
        maxWidth: 700,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              AppSkeletonBox(width: 200, height: 16),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: AppSkeletonStat()),
                  SizedBox(width: 12),
                  Expanded(child: AppSkeletonStat()),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: AppSkeletonStat()),
                  SizedBox(width: 12),
                  Expanded(child: AppSkeletonStat()),
                ],
              ),
              SizedBox(height: 24),
              AppSkeletonBox(width: 150, height: 14),
              SizedBox(height: 12),
              AppSkeletonList(count: 3, padding: EdgeInsets.zero),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: AppTheme.dangerRed, size: 48),
              const SizedBox(height: 16),
              Text(_errorMessage!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              AppButton(
                label: 'RETRY',
                icon: Icons.refresh,
                onPressed: _loadData,
              ),
            ],
          ),
        ),
      );
    }

    final statCards = [
      _AdminStat('Total Recruits', '${_stats['totalRecruits'] ?? 0}',
          Icons.people, AppTheme.successGreen),
      _AdminStat('Companies', '${_stats['totalCompanies'] ?? 0}',
          Icons.business, AppTheme.steelBlue),
      _AdminStat('Flagged Records', '${_stats['flaggedRecords'] ?? 0}',
          Icons.flag, AppTheme.dangerRed),
      _AdminStat('Pending Approvals', '${_stats['pendingApprovals'] ?? 0}',
          Icons.hourglass_top, AppTheme.goldAccent),
      _AdminStat('Searches Today', '${_stats['searchesToday'] ?? 0}',
          Icons.search, const Color(0xFF9B59B6)),
      _AdminStat('New This Month', '${_stats['newThisMonth'] ?? 0}',
          Icons.trending_up, AppTheme.goldLight),
    ];

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.goldAccent,
      backgroundColor: AppTheme.cardBg,
      child: AppMaxWidth(
        maxWidth: 700,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PanelHeader(
                title: 'Platform Overview',
                subtitle: 'Real-time summary across all registered companies',
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: statCards.map((s) => _AdminStatCard(stat: s)).toList(),
            ),
            const SizedBox(height: 24),
            const _AdminSectionLabel('RECENT ACTIVITY'),
            const SizedBox(height: 12),
            if (_recentActivity.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text('No recent activity',
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
              )
            else
              ..._recentActivity.map((a) => _ActivityTile(
                    icon: _iconForAction(a.action),
                    color: _colorForAction(a.action),
                    title: a.action.replaceAll('_', ' '),
                    subtitle: '${a.companyName}: ${a.detail}',
                    time: _timeAgo(a.createdAt),
                  )),
          ],
        ),
        ),
      ),
    );
  }
}

// ── Analytics Tab ────────────────────────────────────────────────────────────

class _AnalyticsTab extends StatefulWidget {
  const _AnalyticsTab();

  @override
  State<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<_AnalyticsTab> {
  final _adminService = AdminService();
  bool _isLoading = true;
  String? _errorMessage;

  Map<String, int> _statusCounts = {};
  Map<String, int> _conductCounts = {};
  List<DailyCount> _registrationTrend = [];
  List<DailyCount> _searchTrend = [];
  List<RegionCount> _regionCounts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        _adminService.getRecruitsByStatus(),
        _adminService.getConductRecordsByType(),
        _adminService.getRegistrationTrend(),
        _adminService.getSearchTrend(),
        _adminService.getRecruitsByRegion(),
      ]);
      setState(() {
        _statusCounts = results[0] as Map<String, int>;
        _conductCounts = results[1] as Map<String, int>;
        _registrationTrend = results[2] as List<DailyCount>;
        _searchTrend = results[3] as List<DailyCount>;
        _regionCounts = results[4] as List<RegionCount>;
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
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.goldAccent),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: AppTheme.dangerRed, size: 48),
              const SizedBox(height: 16),
              Text(_errorMessage!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              AppButton(
                label: 'RETRY',
                icon: Icons.refresh,
                onPressed: _loadData,
              ),
            ],
          ),
        ),
      );
    }

    final totalRecruits =
        _statusCounts.values.fold<int>(0, (a, b) => a + b);
    final totalConduct =
        _conductCounts.values.fold<int>(0, (a, b) => a + b);

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.goldAccent,
      backgroundColor: AppTheme.cardBg,
      child: AppMaxWidth(
        maxWidth: 700,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _AdminSectionLabel('REGISTRATION TREND — LAST 30 DAYS'),
              const SizedBox(height: 12),
              _ChartCard(
                child: totalRecruits == 0
                    ? const _EmptyChartState(message: 'No recruits registered yet')
                    : _TrendLineChart(
                        data: _registrationTrend,
                        color: AppTheme.successGreen,
                      ),
              ),
            const SizedBox(height: 24),

            const _AdminSectionLabel('SEARCH ACTIVITY — LAST 30 DAYS'),
            const SizedBox(height: 12),
            _ChartCard(
              child: _searchTrend.every((d) => d.count == 0)
                  ? const _EmptyChartState(message: 'No searches recorded yet')
                  : _TrendLineChart(
                      data: _searchTrend,
                      color: AppTheme.steelBlue,
                    ),
            ),
            const SizedBox(height: 24),

            const _AdminSectionLabel('RECRUIT STATUS BREAKDOWN'),
            const SizedBox(height: 12),
            _ChartCard(
              height: 260,
              child: totalRecruits == 0
                  ? const _EmptyChartState(message: 'No recruits to show')
                  : _StatusDonutChart(counts: _statusCounts, total: totalRecruits),
            ),
            const SizedBox(height: 24),

            const _AdminSectionLabel('CONDUCT RECORDS BY TYPE'),
            const SizedBox(height: 12),
            _ChartCard(
              child: totalConduct == 0
                  ? const _EmptyChartState(message: 'No conduct records on file')
                  : _ConductBarChart(counts: _conductCounts),
            ),
            const SizedBox(height: 24),

            const _AdminSectionLabel('RECRUITS BY REGION'),
            const SizedBox(height: 12),
            _ChartCard(
              height: _regionCounts.isEmpty
                  ? 100
                  : (60 + _regionCounts.length * 36).toDouble(),
              child: _regionCounts.isEmpty
                  ? const _EmptyChartState(message: 'No regional data yet')
                  : _RegionBarChart(regions: _regionCounts),
            ),
            const SizedBox(height: 16),
          ],
        ),
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final Widget child;
  final double height;
  const _ChartCard({required this.child, this.height = 220});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.steelBlue.withOpacity(0.4)),
      ),
      child: child,
    );
  }
}

class _EmptyChartState extends StatelessWidget {
  final String message;
  const _EmptyChartState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _TrendLineChart extends StatelessWidget {
  final List<DailyCount> data;
  final Color color;
  const _TrendLineChart({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    final maxY = data.map((d) => d.count).fold<int>(0, (a, b) => a > b ? a : b);
    final effectiveMaxY = maxY == 0 ? 1.0 : maxY.toDouble();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: effectiveMaxY * 1.2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: effectiveMaxY / 3 < 1 ? 1 : effectiveMaxY / 3,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppTheme.steelBlue.withOpacity(0.2),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: effectiveMaxY / 3 < 1 ? 1 : (effectiveMaxY / 3).ceilToDouble(),
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 9),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: (data.length / 5).ceilToDouble().clamp(1, data.length.toDouble()),
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= data.length) return const SizedBox();
                final date = data[i].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${date.day}/${date.month}',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 8.5),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (int i = 0; i < data.length; i++)
                FlSpot(i.toDouble(), data[i].count.toDouble()),
            ],
            isCurved: true,
            curveSmoothness: 0.25,
            color: color,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color.withOpacity(0.25), color.withOpacity(0.0)],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppTheme.navyMid,
            getTooltipItems: (spots) => spots.map((s) {
              final date = data[s.x.toInt()].date;
              return LineTooltipItem(
                '${date.day}/${date.month}: ${s.y.toInt()}',
                const TextStyle(color: AppTheme.offWhite, fontSize: 11),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _StatusDonutChart extends StatelessWidget {
  final Map<String, int> counts;
  final int total;
  const _StatusDonutChart({required this.counts, required this.total});

  Color _colorFor(String status) {
    switch (status) {
      case 'clear':
        return AppTheme.successGreen;
      case 'flagged':
        return AppTheme.goldLight;
      case 'suspended':
        return const Color(0xFFFF9F1C);
      case 'terminated':
        return AppTheme.dangerRed;
      default:
        return AppTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = counts.entries.where((e) => e.value > 0).toList();

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 42,
              sections: entries.map((e) {
                final pct = (e.value / total * 100);
                return PieChartSectionData(
                  value: e.value.toDouble(),
                  color: _colorFor(e.key),
                  title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
                  titleStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.navyDark,
                  ),
                  radius: 56,
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: entries.map((e) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _colorFor(e.key),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${e.key[0].toUpperCase()}${e.key.substring(1)} (${e.value})',
                        style: const TextStyle(
                            color: AppTheme.offWhite, fontSize: 10.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _ConductBarChart extends StatelessWidget {
  final Map<String, int> counts;
  const _ConductBarChart({required this.counts});

  static const _order = [
    'commendation',
    'warning',
    'suspension',
    'misconduct',
    'termination',
  ];

  Color _colorFor(String type) {
    switch (type) {
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

  String _labelFor(String type) {
    switch (type) {
      case 'commendation':
        return 'Commend.';
      case 'warning':
        return 'Warning';
      case 'suspension':
        return 'Suspend.';
      case 'misconduct':
        return 'Misconduct';
      case 'termination':
        return 'Terminat.';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxY = _order
        .map((k) => counts[k] ?? 0)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final effectiveMaxY = maxY == 0 ? 1.0 : maxY.toDouble();

    return BarChart(
      BarChartData(
        maxY: effectiveMaxY * 1.25,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppTheme.steelBlue.withOpacity(0.2),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 9),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= _order.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _labelFor(_order[i]),
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 8),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (int i = 0; i < _order.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: (counts[_order[i]] ?? 0).toDouble(),
                  color: _colorFor(_order[i]),
                  width: 22,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppTheme.navyMid,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${_labelFor(_order[group.x])}: ${rod.toY.toInt()}',
                const TextStyle(color: AppTheme.offWhite, fontSize: 11),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RegionBarChart extends StatelessWidget {
  final List<RegionCount> regions;
  const _RegionBarChart({required this.regions});

  @override
  Widget build(BuildContext context) {
    final maxCount =
        regions.map((r) => r.count).fold<int>(0, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: regions.map((r) {
        final fraction = maxCount == 0 ? 0.0 : r.count / maxCount;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  r.region,
                  style: const TextStyle(color: AppTheme.offWhite, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppTheme.steelBlue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: fraction.clamp(0.03, 1.0),
                      child: Container(
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppTheme.goldAccent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 28,
                child: Text(
                  '${r.count}',
                  style: const TextStyle(
                      color: AppTheme.goldAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Disputes Admin Tab ────────────────────────────────────────────────────────

class _DisputesAdminTab extends StatefulWidget {
  const _DisputesAdminTab();

  @override
  State<_DisputesAdminTab> createState() => _DisputesAdminTabState();
}

class _DisputesAdminTabState extends State<_DisputesAdminTab> {
  final _disputeService = DisputeService();
  bool _isLoading = true;
  String? _errorMessage;
  List<ConductDispute> _disputes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final d = await _disputeService.getAllPendingDisputes();
      setState(() { _disputes = d; _isLoading = false; });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _showResolveDialog(ConductDispute dispute, bool uphold) {
    final notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.navyMid,
        title: Text(
          uphold ? 'Uphold Dispute' : 'Reject Dispute',
          style: TextStyle(
            color: uphold ? AppTheme.successGreen : AppTheme.dangerRed,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              uphold
                  ? 'This will permanently delete the conduct record. The recruit\'s status will be recalculated.'
                  : 'The conduct record will remain unchanged.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesCtrl,
              maxLines: 3,
              style: const TextStyle(color: AppTheme.offWhite),
              decoration: const InputDecoration(
                labelText: 'Admin Notes (optional)',
                hintText: 'Reason for your decision...',
              ),
            ),
          ],
        ),
        actions: [
          AppButton.text(
            label: 'CANCEL',
            onPressed: () => Navigator.pop(ctx),
          ),
          uphold
              ? AppButton.success(
                  label: 'UPHOLD',
                  compact: true,
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await _disputeService.upholdDispute(
                        disputeId: dispute.id,
                        conductRecordId: dispute.conductRecordId,
                        adminNotes:
                            notesCtrl.text.isEmpty ? null : notesCtrl.text,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Dispute upheld — record removed'),
                            backgroundColor: AppTheme.successGreen,
                          ),
                        );
                        _load();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              e.toString().replaceFirst('Exception: ', '')),
                          backgroundColor: AppTheme.dangerRed,
                        ));
                      }
                    }
                  },
                )
              : AppButton.danger(
                  label: 'REJECT',
                  compact: true,
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await _disputeService.rejectDispute(
                        disputeId: dispute.id,
                        adminNotes:
                            notesCtrl.text.isEmpty ? null : notesCtrl.text,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Dispute rejected — record stands'),
                            backgroundColor: AppTheme.dangerRed,
                          ),
                        );
                        _load();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              e.toString().replaceFirst('Exception: ', '')),
                          backgroundColor: AppTheme.dangerRed,
                        ));
                      }
                    }
                  },
                ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppLoadingIndicator(caption: 'Loading disputes...');
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: AppTheme.dangerRed, size: 48),
              const SizedBox(height: 16),
              Text(_errorMessage!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              AppButton(
                label: 'RETRY',
                icon: Icons.refresh,
                onPressed: _load,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.goldAccent,
      backgroundColor: AppTheme.cardBg,
      child: AppMaxWidth(
        maxWidth: 700,
        child: _disputes.isEmpty
            ? ListView(
                children: [
                  SizedBox(
                    height: 300,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_outline,
                              color: AppTheme.successGreen, size: 48),
                          const SizedBox(height: 16),
                          Text('No pending disputes',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text('All conduct record disputes have been resolved.',
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _disputes.length,
              itemBuilder: (context, i) {
                final d = _disputes[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.goldAccent.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.flag_outlined,
                              color: AppTheme.goldAccent, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Disputed by ${d.disputedByCompanyName}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontSize: 13),
                            ),
                          ),
                          Text(
                            '${d.createdAt.day}/${d.createdAt.month}/${d.createdAt.year}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        d.reason,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Wrap(
                          spacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            AppButton.danger(
                              label: 'REJECT',
                              icon: Icons.close,
                              compact: true,
                              onPressed: () => _showResolveDialog(d, false),
                            ),
                            AppButton.success(
                              label: 'UPHOLD',
                              icon: Icons.check,
                              compact: true,
                              onPressed: () => _showResolveDialog(d, true),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            ),
    );
  }
}

// ── Companies Admin Tab ───────────────────────────────────────────────────────

class _CompaniesAdminTab extends StatefulWidget {
  const _CompaniesAdminTab();

  @override
  State<_CompaniesAdminTab> createState() => _CompaniesAdminTabState();
}

class _CompaniesAdminTabState extends State<_CompaniesAdminTab> {
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

  Future<void> _approve(DbCompany c) async {
    try {
      await _companyService.verifyCompany(c.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${c.name} approved successfully'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        _loadCompanies();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    }
  }

  Future<void> _reject(DbCompany c) async {
    try {
      await _companyService.rejectCompany(c.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${c.name} rejected'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
        _loadCompanies();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    }
  }

  void _showConfirm(DbCompany c, bool approve) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text(
          approve ? 'Approve Company?' : 'Reject Company?',
          style: const TextStyle(color: AppTheme.offWhite),
        ),
        content: Text(
          'Are you sure you want to ${approve ? 'approve' : 'reject'} "${c.name}"?',
          style: const TextStyle(color: AppTheme.textMuted),
        ),
        actions: [
          AppButton.text(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context),
          ),
          approve
              ? AppButton.success(
                  label: 'APPROVE',
                  compact: true,
                  onPressed: () {
                    Navigator.pop(context);
                    _approve(c);
                  },
                )
              : AppButton.danger(
                  label: 'REJECT',
                  compact: true,
                  onPressed: () {
                    Navigator.pop(context);
                    _reject(c);
                  },
                ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppLoadingIndicator(caption: 'Loading companies...');
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: AppTheme.dangerRed, size: 48),
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
      );
    }

    final pending = _companies.where((c) => !c.isVerified).toList();
    final verified = _companies.where((c) => c.isVerified).toList();

    return RefreshIndicator(
      onRefresh: _loadCompanies,
      color: AppTheme.goldAccent,
      backgroundColor: AppTheme.cardBg,
      child: AppMaxWidth(
        maxWidth: 700,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_fromCache) ...[
                _BannerAlert(
                  message:
                      'Offline — showing cached list. Approve/reject requires a connection.',
                  color: AppTheme.goldAccent,
                ),
                const SizedBox(height: 12),
              ],
              if (pending.isNotEmpty) ...[
                _BannerAlert(
                  message: '${pending.length} ${pending.length == 1 ? 'company' : 'companies'} awaiting verification',
                  color: AppTheme.goldAccent,
                ),
                const SizedBox(height: 16),
                const _AdminSectionLabel('PENDING APPROVAL'),
                const SizedBox(height: 8),
                ...pending.map((c) => _CompanyAdminTile(
                      company: c,
                    isPending: true,
                    onApprove: () => _showConfirm(c, true),
                    onReject: () => _showConfirm(c, false),
                  )),
              const SizedBox(height: 20),
            ],
            const _AdminSectionLabel('VERIFIED COMPANIES'),
            const SizedBox(height: 8),
            if (verified.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text('No verified companies yet',
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
              )
            else
              ...verified.map((c) => _CompanyAdminTile(
                    company: c,
                    isPending: false,
                  )),
          ],
        ),
        ),
      ),
    );
  }
}

// ── Audit Log Tab ─────────────────────────────────────────────────────────────

class _AuditLogTab extends StatefulWidget {
  const _AuditLogTab();

  @override
  State<_AuditLogTab> createState() => _AuditLogTabState();
}

class _AuditLogTabState extends State<_AuditLogTab> {
  final _adminService = AdminService();
  bool _isLoading = true;
  String? _errorMessage;
  List<DbAuditEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadLog();
  }

  Future<void> _loadLog() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final entries = await _adminService.getAuditLog(limit: 100);
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'SEARCH':
        return AppTheme.steelBlue;
      case 'ADD_RECORD':
        return AppTheme.dangerRed;
      case 'REGISTER':
        return AppTheme.successGreen;
      case 'VERIFY':
        return AppTheme.goldAccent;
      default:
        return AppTheme.textMuted;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppLoadingIndicator(caption: 'Loading audit log...');
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: AppTheme.dangerRed, size: 48),
              const SizedBox(height: 16),
              Text(_errorMessage!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              AppButton(
                label: 'RETRY',
                icon: Icons.refresh,
                onPressed: _loadLog,
              ),
            ],
          ),
        ),
      );
    }

    if (_entries.isEmpty) {
      return Center(
        child: Text('No audit entries yet',
            style: Theme.of(context).textTheme.bodyMedium),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLog,
      color: AppTheme.goldAccent,
      backgroundColor: AppTheme.cardBg,
      child: AppMaxWidth(
        maxWidth: 700,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: _entries.length,
          separatorBuilder: (_, __) =>
              const Divider(color: AppTheme.steelBlue, height: 1),
          itemBuilder: (context, i) {
            final e = _entries[i];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _actionColor(e.action).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      e.action,
                      style: TextStyle(
                        color: _actionColor(e.action),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.companyName,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(e.detail,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                Text(
                  _timeAgo(e.createdAt),
                  style:
                      Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
                ),
              ],
            ),
          );
        },
      ),
      ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _PanelHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.navyMid, AppTheme.steelBlue],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.goldAccent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.admin_panel_settings,
              color: AppTheme.goldAccent, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                Text(subtitle,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminStatCard extends StatelessWidget {
  final _AdminStat stat;
  const _AdminStatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: stat.color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(stat.icon, color: stat.color, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stat.value,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: stat.color),
              ),
              Text(stat.label,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String time;

  const _ActivityTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontSize: 13)),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          Text(time,
              style:
                  Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}

class _CompanyAdminTile extends StatelessWidget {
  final DbCompany company;
  final bool isPending;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _CompanyAdminTile({
    required this.company,
    required this.isPending,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPending
              ? AppTheme.goldAccent.withOpacity(0.4)
              : AppTheme.steelBlue.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(company.name,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              if (isPending) ...[
                _ActionBtn(
                  label: 'APPROVE',
                  color: AppTheme.successGreen,
                  onTap: onApprove ?? () {},
                ),
                const SizedBox(width: 8),
                _ActionBtn(
                  label: 'REJECT',
                  color: AppTheme.dangerRed,
                  onTap: onReject ?? () {},
                ),
              ] else
                const Icon(Icons.verified,
                    color: AppTheme.successGreen, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          Text(company.licenseNumber,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.goldAccent)),
          Text('${company.region}  ·  ${company.email}',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8)),
      ),
    );
  }
}

class _BannerAlert extends StatelessWidget {
  final String message;
  final Color color;
  const _BannerAlert({required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_active, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _AdminSectionLabel extends StatelessWidget {
  final String label;
  const _AdminSectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
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

// ── Data Classes ──────────────────────────────────────────────────────────────

class _AdminStat {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _AdminStat(this.label, this.value, this.icon, this.color);
}
