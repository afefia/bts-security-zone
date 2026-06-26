import '../config/supabase_service.dart';
import '../models/db_models.dart';

class AdminService {
  final _client = SupabaseService.client;

  Future<Map<String, int>> getOverviewStats() async {
    final recruits = await _client.from('recruits').select('id, status');
    final companies = await _client.from('companies').select('id, is_verified');
    final flagged =
        (recruits as List).where((r) => r['status'] != 'clear').length;
    final pending =
        (companies as List).where((c) => c['is_verified'] == false).length;

    final today = DateTime.now();
    final startOfDay =
        DateTime(today.year, today.month, today.day).toIso8601String();
    final searchesToday = await _client
        .from('audit_logs')
        .select('id')
        .eq('action', 'SEARCH')
        .gte('created_at', startOfDay);

    final startOfMonth = DateTime(today.year, today.month, 1).toIso8601String();
    final newThisMonth = await _client
        .from('recruits')
        .select('id')
        .gte('registered_at', startOfMonth);

    return {
      'totalRecruits': recruits.length,
      'totalCompanies': companies.length,
      'flaggedRecords': flagged,
      'pendingApprovals': pending,
      'searchesToday': (searchesToday as List).length,
      'newThisMonth': (newThisMonth as List).length,
    };
  }

  Future<List<DbAuditEntry>> getAuditLog({int limit = 50}) async {
    final data = await _client
        .from('audit_logs')
        .select('*, companies ( name )')
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List)
        .map((e) => DbAuditEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Analytics ────────────────────────────────────────────────────────

  /// Recruit count by status — feeds the status-breakdown pie/donut chart.
  Future<Map<String, int>> getRecruitsByStatus() async {
    final data = await _client.from('recruits').select('status');
    final counts = <String, int>{
      'clear': 0,
      'flagged': 0,
      'suspended': 0,
      'terminated': 0,
    };
    for (final row in (data as List)) {
      final status = row['status'] as String? ?? 'clear';
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }

  /// Conduct record count by type — feeds the conduct-type bar chart.
  Future<Map<String, int>> getConductRecordsByType() async {
    final data = await _client.from('conduct_records').select('type');
    final counts = <String, int>{
      'commendation': 0,
      'warning': 0,
      'suspension': 0,
      'misconduct': 0,
      'termination': 0,
    };
    for (final row in (data as List)) {
      final type = row['type'] as String?;
      if (type != null && counts.containsKey(type)) {
        counts[type] = counts[type]! + 1;
      }
    }
    return counts;
  }

  /// Recruit registrations per day for the last [days] days — feeds the
  /// growth line chart. Returns one entry per day, including zero-count
  /// days, so the chart's x-axis is evenly spaced rather than skipping
  /// gaps where nothing happened.
  Future<List<DailyCount>> getRegistrationTrend({int days = 30}) async {
    final since = DateTime.now().subtract(Duration(days: days - 1));
    final sinceStart = DateTime(since.year, since.month, since.day);

    final data = await _client
        .from('recruits')
        .select('registered_at')
        .gte('registered_at', sinceStart.toIso8601String());

    return _bucketByDay(
      (data as List).map((r) => DateTime.parse(r['registered_at'] as String)),
      days,
    );
  }

  /// Search volume per day for the last [days] days — feeds the activity
  /// line chart, same zero-filling approach as registrations.
  Future<List<DailyCount>> getSearchTrend({int days = 30}) async {
    final since = DateTime.now().subtract(Duration(days: days - 1));
    final sinceStart = DateTime(since.year, since.month, since.day);

    final data = await _client
        .from('audit_logs')
        .select('created_at')
        .eq('action', 'SEARCH')
        .gte('created_at', sinceStart.toIso8601String());

    return _bucketByDay(
      (data as List).map((r) => DateTime.parse(r['created_at'] as String)),
      days,
    );
  }

  /// Recruit count grouped by region — feeds the regional distribution bar
  /// chart, sorted descending so the busiest regions show first.
  Future<List<RegionCount>> getRecruitsByRegion() async {
    final data = await _client.from('recruits').select('region');
    final counts = <String, int>{};
    for (final row in (data as List)) {
      final region = row['region'] as String? ?? 'Unknown';
      counts[region] = (counts[region] ?? 0) + 1;
    }
    final list = counts.entries
        .map((e) => RegionCount(region: e.key, count: e.value))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    return list;
  }

  List<DailyCount> _bucketByDay(Iterable<DateTime> timestamps, int days) {
    final buckets = <DateTime, int>{};
    final now = DateTime.now();
    for (int i = days - 1; i >= 0; i--) {
      final day =
          DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      buckets[day] = 0;
    }
    for (final ts in timestamps) {
      final day = DateTime(ts.year, ts.month, ts.day);
      if (buckets.containsKey(day)) {
        buckets[day] = buckets[day]! + 1;
      }
    }
    return buckets.entries
        .map((e) => DailyCount(date: e.key, count: e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Admin: get all companies (bypasses RLS via stored procedure).
  Future<List<DbCompany>> getAllCompanies() async {
    final data = await _client.rpc('admin_get_all_companies');
    return (data as List)
        .map((e) => DbCompany.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Admin: verify a company (bypasses RLS).
  Future<void> verifyCompany(String companyId) async {
    await _client.rpc('admin_verify_company', params: {
      'p_company_id': companyId,
    });
  }

  /// Admin: reject/delete a company (bypasses RLS).
  Future<void> rejectCompany(String companyId) async {
    await _client.rpc('admin_reject_company', params: {
      'p_company_id': companyId,
    });
  }
}

class DailyCount {
  final DateTime date;
  final int count;
  const DailyCount({required this.date, required this.count});
}

class RegionCount {
  final String region;
  final int count;
  const RegionCount({required this.region, required this.count});
}
