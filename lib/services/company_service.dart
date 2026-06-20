import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_service.dart';
import '../models/db_models.dart';
import 'local_db.dart';
import 'connectivity_service.dart';

/// Wraps a company list with whether it came from a live query or the
/// local cache, mirroring RecruitSearchResult so the UI can be honest
/// about data freshness here too.
class CompanyListResult {
  final List<DbCompany> companies;
  final bool fromCache;

  const CompanyListResult({required this.companies, required this.fromCache});
}

class CompanyService {
  final _client = SupabaseService.client;
  final _connectivity = ConnectivityService();

  /// Reads the full company list. Falls back to the local cache when
  /// offline or the request fails, same pattern as RecruitService —
  /// company approval status and contact details rarely change minute to
  /// minute, so a cached read is still useful here even though this isn't
  /// as time-critical as recruit verification.
  Future<CompanyListResult> getAll() async {
    if (!_connectivity.isOnline) {
      return _getAllOffline();
    }

    try {
      final data = await _client.from('companies').select().order('name');
      final companies =
          (data as List).map((e) => DbCompany.fromJson(e)).toList();

      LocalDb.cacheCompanies((data).cast<Map<String, dynamic>>());

      return CompanyListResult(companies: companies, fromCache: false);
    } catch (e) {
      await _connectivity.refresh();
      return _getAllOffline();
    }
  }

  Future<CompanyListResult> _getAllOffline() async {
    final cached = await LocalDb.getAllCachedCompanies();
    final companies = cached.map((e) => DbCompany.fromJson(e)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return CompanyListResult(companies: companies, fromCache: true);
  }

  Future<DbCompany?> getMyCompany() async {
    final user = SupabaseService.currentUser;
    if (user == null) return null;

    if (!_connectivity.isOnline) {
      return _getMyCompanyOffline(user.id);
    }

    try {
      final userData = await _client
          .from('users')
          .select('company_id')
          .eq('id', user.id)
          .maybeSingle();
      if (userData == null) return null;

      final data = await _client
          .from('companies')
          .select()
          .eq('id', userData['company_id'])
          .maybeSingle();

      if (data != null) {
        await LocalDb.cacheCompanies([data]);
        await LocalDb.cacheMyCompanyId(userData['company_id'] as String);
      }

      return data == null ? null : DbCompany.fromJson(data);
    } catch (e) {
      await _connectivity.refresh();
      return _getMyCompanyOffline(user.id);
    }
  }

  /// Fetches the current user's full profile (role + company) in one call.
  /// This is the right way to answer "is this person an admin?" — role
  /// lives on the users table, not the companies table.
  Future<DbUserProfile?> getMyProfile() async {
    final user = SupabaseService.currentUser;
    if (user == null) return null;

    try {
      final data = await _client
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      return data == null ? null : DbUserProfile.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<DbCompany?> _getMyCompanyOffline(String userId) async {
    final companyId = await LocalDb.getMyCachedCompanyId();
    if (companyId == null) return null;
    final cached = await LocalDb.getAllCachedCompanies();
    for (final c in cached) {
      if (c['id'] == companyId) return DbCompany.fromJson(c);
    }
    return null;
  }

  /// Approving/rejecting a company changes platform-wide state that every
  /// other company relies on (it gates whether recruits they search are
  /// visible at all) — unlike registering a recruit, there's no good way
  /// to "queue" this offline and have it feel safe, since the admin would
  /// have no confirmation the action actually took effect. This stays
  /// online-only and fails clearly rather than silently queuing.
  Future<void> verifyCompany(String companyId) async {
    if (!_connectivity.isOnline) {
      throw Exception(
          'Approving a company requires an internet connection. Please reconnect and try again.');
    }

    await _client.from('companies').update({
      'is_verified': true,
      'verified_at': DateTime.now().toIso8601String(),
      'verified_by': SupabaseService.currentUser?.id,
    }).eq('id', companyId);

    await _client.from('audit_logs').insert({
      'company_id': companyId,
      'user_id': SupabaseService.currentUser?.id,
      'action': 'VERIFY',
      'detail': 'Company verified by admin',
    });
  }

  Future<void> rejectCompany(String companyId) async {
    if (!_connectivity.isOnline) {
      throw Exception(
          'Rejecting a company requires an internet connection. Please reconnect and try again.');
    }

    await _client.from('companies').update({
      'is_verified': false,
    }).eq('id', companyId);

    await _client.from('audit_logs').insert({
      'company_id': companyId,
      'user_id': SupabaseService.currentUser?.id,
      'action': 'REJECT',
      'detail': 'Company registration rejected by admin',
    });
  }
}
