import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_service.dart';
import '../models/db_models.dart';
import 'local_db.dart';
import 'connectivity_service.dart';
import 'fingerprint_service.dart';
import '../utils/validators.dart';

/// Thrown when a user has exceeded the search rate limit enforced by the
/// check_search_rate_limit() Postgres function. Distinct from a generic
/// Exception so the UI can show a specific "slow down" message rather
/// than a vague error.
class RateLimitException implements Exception {
  final String message;
  const RateLimitException([
    this.message = 'Too many searches — please wait a moment and try again.',
  ]);

  @override
  String toString() => message;
}

/// Wraps a list of recruits with whether they came from a live query or
/// the local cache, so the UI can show "showing cached data" honestly
/// instead of presenting possibly-stale results as if they were live.
class RecruitSearchResult {
  final List<DbRecruit> recruits;
  final bool fromCache;
  final DateTime? cacheTimestamp;

  const RecruitSearchResult({
    required this.recruits,
    required this.fromCache,
    this.cacheTimestamp,
  });
}

class RecruitService {
  final _client = SupabaseService.client;
  final _connectivity = ConnectivityService();

  /// Calls the server-side rate limit check (see check_search_rate_limit
  /// in supabase_schema.sql). Enforced in Postgres rather than trusted to
  /// the client — this call can't be skipped to bypass the limit, since
  /// the database itself is what's tracking the count. If the RPC itself
  /// fails (e.g. function not deployed, or offline), we fail open rather
  /// than blocking search entirely over an enforcement mechanism issue.
  Future<void> _enforceSearchRateLimit() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    try {
      final allowed = await _client.rpc(
        'check_search_rate_limit',
        params: {'p_user_id': userId},
      );
      if (allowed == false) {
        throw const RateLimitException();
      }
    } on RateLimitException {
      rethrow;
    } catch (_) {
      // RPC not deployed yet, or a transient network issue — don't let
      // enforcement plumbing itself block legitimate searches.
    }
  }

  // ── Search ───────────────────────────────────────────────────────────────
  /// Search by name, ID number, or phone. Falls back to the local cache if
  /// the network is unavailable or the request fails, so a recruit lookup
  /// still returns something useful instead of just an error screen.
  Future<RecruitSearchResult> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      return const RecruitSearchResult(recruits: [], fromCache: false);
    }

    if (!_connectivity.isOnline) {
      return _searchOffline(q);
    }

    await _enforceSearchRateLimit();

    try {
      final data = await _client
          .from('recruits')
          .select('''
            *,
            employment_history (
              *,
              companies ( id, name )
            ),
            conduct_records (
              *,
              companies ( id, name )
            )
          ''')
          .or('full_name.ilike.%$q%,id_number.ilike.%$q%,phone.ilike.%$q%')
          .order('full_name');

      await _logAudit(
        action: 'SEARCH',
        detail: 'Searched for recruit: "$q"',
      );

      final results =
          (data as List).map((e) => DbRecruit.fromJson(e)).toList();

      // Refresh cache with whatever we just saw so it's available offline
      // later, even for a partial query result set.
      LocalDb.cacheRecruits((data).cast<Map<String, dynamic>>());

      return RecruitSearchResult(recruits: results, fromCache: false);
    } on PostgrestException catch (e) {
      throw Exception('Search failed: ${e.message}');
    } catch (e) {
      // Network-layer failure (timeout, DNS, etc.) — treat as offline
      // rather than surfacing a raw exception, and let the connectivity
      // service know its last "online" reading may be stale.
      await _connectivity.refresh();
      return _searchOffline(q);
    }
  }

  Future<RecruitSearchResult> _searchOffline(String q) async {
    final cached = await LocalDb.searchCachedRecruits(q);
    final lastSync = await LocalDb.getRecruitsLastSyncedAt();
    return RecruitSearchResult(
      recruits: cached.map((e) => DbRecruit.fromJson(e)).toList(),
      fromCache: true,
      cacheTimestamp: lastSync,
    );
  }

  /// Identifies a recruit from a freshly-captured fingerprint template by
  /// running 1:N matching against every recruit that has a fingerprint on
  /// file. This deliberately does NOT do an exact-equality database query
  /// (`eq('fingerprint_hash', ...)`) — that only works for the software
  /// fallback's fake hashes. Real fingerprint templates are never
  /// byte-identical between scans of the same finger, so identification
  /// has to go through [FingerprintService.findMatch], which delegates to
  /// the active provider's vendor-specific matching algorithm.
  ///
  /// NOTE ON SCALE: this fetches every recruit with a fingerprint on file
  /// and matches against each one client-side. Fine for hundreds to a
  /// few thousand recruits; if the platform grows well beyond that, move
  /// matching server-side (e.g. an Edge Function or a dedicated matching
  /// service) so the device isn't doing thousands of comparisons.
  Future<DbRecruit?> findByFingerprint(
    String capturedTemplate,
    FingerprintService fingerprintService,
  ) async {
    List<Map<String, dynamic>> candidates;

    if (!_connectivity.isOnline) {
      candidates = await LocalDb.getAllCachedRecruits();
    } else {
      try {
        final data = await _client
            .from('recruits')
            .select('''
              *,
              employment_history ( *, companies ( id, name ) ),
              conduct_records    ( *, companies ( id, name ) )
            ''')
            .not('fingerprint_hash', 'is', null);
        candidates = (data as List).cast<Map<String, dynamic>>();
      } on PostgrestException catch (e) {
        throw Exception('Fingerprint lookup failed: ${e.message}');
      } catch (_) {
        await _connectivity.refresh();
        candidates = await LocalDb.getAllCachedRecruits();
      }
    }

    final templatesById = <String, String>{};
    final recruitsById = <String, Map<String, dynamic>>{};
    for (final r in candidates) {
      final template = r['fingerprint_hash'] as String?;
      final id = r['id'] as String?;
      if (template != null && id != null) {
        templatesById[id] = template;
        recruitsById[id] = r;
      }
    }

    if (templatesById.isEmpty) return null;

    final matchedId = await fingerprintService.findMatch(
      capturedTemplate: capturedTemplate,
      candidates: templatesById,
    );

    if (matchedId == null) return null;

    if (_connectivity.isOnline) {
      await _logAudit(action: 'SEARCH', detail: 'Fingerprint scan lookup');
    }

    return DbRecruit.fromJson(recruitsById[matchedId]!);
  }

  // ── Get single recruit ───────────────────────────────────────────────────
  Future<DbRecruit?> getById(String recruitId) async {
    if (!_connectivity.isOnline) {
      final cached = await LocalDb.getCachedRecruitById(recruitId);
      return cached == null ? null : DbRecruit.fromJson(cached);
    }

    try {
      final data = await _client
          .from('recruits')
          .select('''
            *,
            employment_history ( *, companies ( id, name ) ),
            conduct_records    ( *, companies ( id, name ) )
          ''')
          .eq('id', recruitId)
          .maybeSingle();

      return data == null ? null : DbRecruit.fromJson(data);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch recruit: ${e.message}');
    } catch (e) {
      final cached = await LocalDb.getCachedRecruitById(recruitId);
      return cached == null ? null : DbRecruit.fromJson(cached);
    }
  }

  // ── Register new recruit ─────────────────────────────────────────────────
  /// When offline, this queues the registration instead of failing outright.
  /// Returns success=true with queued=true in that case so the UI can show
  /// "saved locally, will sync when back online" rather than an error.
  Future<RecruitWriteResult> register({
    required String fullName,
    required String idNumber,
    required String phone,
    required String region,
    String? fingerprintHash,
    String? photoUrl,
    required String companyId,
    required String role,
    required DateTime startDate,
  }) async {
    // Belt-and-suspenders: re-validate here independent of whatever the
    // calling screen's form already checked. Catches drift between a
    // screen's validator and these rules, and ensures even the offline
    // queue path (below) never stores invalid data waiting to sync.
    Validators.assertValid(Validators.fullName(fullName), 'Full name');
    Validators.assertValid(Validators.idNumber(idNumber), 'ID number');
    Validators.assertValid(Validators.phone(phone), 'Phone');
    Validators.assertValid(Validators.region(region), 'Region');
    Validators.assertValid(Validators.role(role), 'Role');

    final userId = SupabaseService.currentUser!.id;
    final startDateStr = startDate.toIso8601String().split('T')[0];

    if (!_connectivity.isOnline) {
      await LocalDb.queueWrite(kind: 'register_recruit', payload: {
        'full_name': fullName,
        'id_number': idNumber,
        'phone': phone,
        'region': region,
        'fingerprint_hash': fingerprintHash,
        'company_id': companyId,
        'role': role,
        'start_date': startDateStr,
        'registered_by': userId,
      });
      return const RecruitWriteResult(success: true, queuedOffline: true);
    }

    try {
      // Check for duplicate ID
      final existing = await _client
          .from('recruits')
          .select('id')
          .eq('id_number', idNumber)
          .maybeSingle();

      if (existing != null) {
        throw Exception(
            'A recruit with ID number "$idNumber" already exists in the system.');
      }

      // Insert recruit
      final recruitData = await _client
          .from('recruits')
          .insert({
            'full_name': fullName,
            'id_number': idNumber,
            'phone': phone,
            'region': region,
            'fingerprint_hash': fingerprintHash,
            'photo_url': photoUrl,
            'status': 'clear',
            'registered_by': userId,
          })
          .select()
          .single();

      final recruitId = recruitData['id'] as String;

      // Insert employment history
      await _client.from('employment_history').insert({
        'recruit_id': recruitId,
        'company_id': companyId,
        'role': role,
        'start_date': startDateStr,
      });

      await _logAudit(
        action: 'REGISTER',
        detail: 'Registered recruit: $fullName ($idNumber)',
        recruitId: recruitId,
      );

      final fullRecord = await _client
          .from('recruits')
          .select('''
            *,
            employment_history ( *, companies ( id, name ) ),
            conduct_records    ( *, companies ( id, name ) )
          ''')
          .eq('id', recruitId)
          .single();

      await LocalDb.cacheRecruit(fullRecord);

      return RecruitWriteResult(
        success: true,
        recruit: DbRecruit.fromJson(fullRecord),
      );
    } on PostgrestException catch (e) {
      throw Exception('Registration failed: ${e.message}');
    } catch (e) {
      if (e is Exception && e.toString().contains('already exists')) {
        rethrow;
      }
      // Network failure mid-request — queue it rather than losing the data
      // the user just typed.
      await _connectivity.refresh();
      if (!_connectivity.isOnline) {
        await LocalDb.queueWrite(kind: 'register_recruit', payload: {
          'full_name': fullName,
          'id_number': idNumber,
          'phone': phone,
          'region': region,
          'fingerprint_hash': fingerprintHash,
          'company_id': companyId,
          'role': role,
          'start_date': startDateStr,
          'registered_by': userId,
        });
        return const RecruitWriteResult(success: true, queuedOffline: true);
      }
      rethrow;
    }
  }

  // ── Add conduct record ───────────────────────────────────────────────────
  Future<RecruitWriteResult> addConductRecord({
    required String recruitId,
    required String companyId,
    required String type,
    required String description,
    required String reportedBy,
    required DateTime incidentDate,
  }) async {
    Validators.assertValid(
        Validators.conductDescription(description), 'Description');
    Validators.assertValid(Validators.reportedBy(reportedBy), 'Reported by');
    if (incidentDate.isAfter(DateTime.now())) {
      throw ArgumentError('Incident date: cannot be in the future');
    }

    final userId = SupabaseService.currentUser!.id;
    final incidentDateStr = incidentDate.toIso8601String().split('T')[0];

    if (!_connectivity.isOnline) {
      await LocalDb.queueWrite(kind: 'add_conduct_record', payload: {
        'recruit_id': recruitId,
        'company_id': companyId,
        'type': type,
        'description': description,
        'reported_by': reportedBy,
        'submitted_by': userId,
        'incident_date': incidentDateStr,
      });
      return const RecruitWriteResult(success: true, queuedOffline: true);
    }

    try {
      await _client.from('conduct_records').insert({
        'recruit_id': recruitId,
        'company_id': companyId,
        'type': type,
        'description': description,
        'reported_by': reportedBy,
        'submitted_by': userId,
        'incident_date': incidentDateStr,
      });

      await _logAudit(
        action: 'ADD_RECORD',
        detail: 'Added $type record for recruit $recruitId',
        recruitId: recruitId,
      );

      return const RecruitWriteResult(success: true);
    } on PostgrestException catch (e) {
      throw Exception('Failed to add record: ${e.message}');
    } catch (e) {
      await _connectivity.refresh();
      if (!_connectivity.isOnline) {
        await LocalDb.queueWrite(kind: 'add_conduct_record', payload: {
          'recruit_id': recruitId,
          'company_id': companyId,
          'type': type,
          'description': description,
          'reported_by': reportedBy,
          'submitted_by': userId,
          'incident_date': incidentDateStr,
        });
        return const RecruitWriteResult(success: true, queuedOffline: true);
      }
      rethrow;
    }
  }

  // ── Get all recruits (dashboard) ─────────────────────────────────────────
  Future<RecruitSearchResult> getAll({
    String? statusFilter,
    String? regionFilter,
    int limit = 50,
  }) async {
    if (!_connectivity.isOnline) {
      final cached = await LocalDb.getAllCachedRecruits();
      final lastSync = await LocalDb.getRecruitsLastSyncedAt();
      var results = cached.map((e) => DbRecruit.fromJson(e)).toList();
      if (statusFilter != null) {
        results = results.where((r) => r.status == statusFilter).toList();
      }
      if (regionFilter != null) {
        results = results.where((r) => r.region == regionFilter).toList();
      }
      return RecruitSearchResult(
        recruits: results,
        fromCache: true,
        cacheTimestamp: lastSync,
      );
    }

    try {
      var query = _client.from('recruits').select('''
            *,
            employment_history ( *, companies ( id, name ) ),
            conduct_records    ( *, companies ( id, name ) )
          ''');

      if (statusFilter != null) {
        query = query.eq('status', statusFilter) as dynamic;
      }
      if (regionFilter != null) {
        query = query.eq('region', regionFilter) as dynamic;
      }

      final data = await query
          .order('registered_at', ascending: false)
          .limit(limit);

      LocalDb.cacheRecruits((data as List).cast<Map<String, dynamic>>());

      return RecruitSearchResult(
        recruits: data.map((e) => DbRecruit.fromJson(e)).toList(),
        fromCache: false,
      );
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch recruits: ${e.message}');
    } catch (e) {
      await _connectivity.refresh();
      final cached = await LocalDb.getAllCachedRecruits();
      final lastSync = await LocalDb.getRecruitsLastSyncedAt();
      return RecruitSearchResult(
        recruits: cached.map((e) => DbRecruit.fromJson(e)).toList(),
        fromCache: true,
        cacheTimestamp: lastSync,
      );
    }
  }

  // ── Audit helper ─────────────────────────────────────────────────────────
  /// Closes a recruit's current employment at a company — sets end_date
  /// and exit_reason on the employment_history row. This is required for
  /// the employment timeline to be accurate; without it every recruit
  /// shows as perpetually employed wherever they were first registered.
  Future<void> closeEmployment({
    required String employmentId,
    required DateTime endDate,
    String? exitReason,
  }) async {
    if (endDate.isAfter(DateTime.now())) {
      throw ArgumentError('End date cannot be in the future');
    }
    Validators.assertValid(
      exitReason != null ? Validators.conductDescription(exitReason) : null,
      'Exit reason',
    );

    await _client.from('employment_history').update({
      'end_date': endDate.toIso8601String().split('T')[0],
      if (exitReason != null && exitReason.trim().isNotEmpty)
        'exit_reason': Validators.sanitize(exitReason),
    }).eq('id', employmentId);

    await _logAudit(
      action: 'ADD_RECORD',
      detail: 'Closed employment record $employmentId',
    );
  }

  Future<void> _logAudit({
    required String action,
    required String detail,
    String? recruitId,
  }) async {
    try {
      final user = SupabaseService.currentUser;
      if (user == null) return;
      final userData = await _client
          .from('users')
          .select('company_id')
          .eq('id', user.id)
          .maybeSingle();
      if (userData == null) return;
      await _client.from('audit_logs').insert({
        'company_id': userData['company_id'],
        'user_id': user.id,
        'action': action,
        'detail': detail,
        if (recruitId != null) 'recruit_id': recruitId,
      });
    } catch (_) {}
  }
}

class RecruitWriteResult {
  final bool success;
  final bool queuedOffline;
  final DbRecruit? recruit;
  final String? error;

  const RecruitWriteResult({
    required this.success,
    this.queuedOffline = false,
    this.recruit,
    this.error,
  });
}
