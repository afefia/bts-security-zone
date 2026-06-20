import 'dart:async';
import '../config/supabase_service.dart';
import 'local_db.dart';
import 'connectivity_service.dart';

enum SyncStatus { idle, syncing, success, error }

class SyncService {
  static final SyncService _instance = SyncService._();
  factory SyncService() => _instance;
  SyncService._();

  final _connectivity = ConnectivityService();
  final _statusController = StreamController<SyncStatus>.broadcast();
  StreamSubscription? _connectivitySub;
  bool _isSyncing = false;

  Stream<SyncStatus> get statusStream => _statusController.stream;

  /// Call once at app startup (after Supabase init) so reconnection
  /// automatically drains the outbox without the user doing anything.
  void start() {
    _connectivitySub?.cancel();
    _connectivitySub = _connectivity.onStatusChange.listen((isOnline) {
      if (isOnline) {
        syncNow();
      }
    });
  }

  void stop() {
    _connectivitySub?.cancel();
  }

  /// Replays queued writes, then refreshes the local cache from Supabase.
  /// Safe to call repeatedly — it no-ops if a sync is already in flight.
  Future<void> syncNow() async {
    if (_isSyncing) return;
    if (!SupabaseService.isLoggedIn) return;

    _isSyncing = true;
    _statusController.add(SyncStatus.syncing);

    try {
      await _drainOutbox();
      await _refreshCache();
      _statusController.add(SyncStatus.success);
    } catch (e) {
      _statusController.add(SyncStatus.error);
    } finally {
      _isSyncing = false;
    }
  }

  // ── Outbox replay ────────────────────────────────────────────────────

  Future<void> _drainOutbox() async {
    final pending = await LocalDb.getPendingWrites();

    for (final item in pending) {
      try {
        switch (item.kind) {
          case 'register_recruit':
            await _replayRegisterRecruit(item.payload);
            break;
          case 'add_conduct_record':
            await _replayAddConductRecord(item.payload);
            break;
          default:
            // Unknown kind — drop it rather than retry forever.
            await LocalDb.removeWrite(item.id);
            continue;
        }
        await LocalDb.markWriteSucceeded(item.id);
      } catch (e) {
        await LocalDb.markWriteFailed(item.id, e.toString());
        if (item.attempts >= 4) {
          // Give up after repeated failures so one bad item doesn't block
          // the queue forever; last_error is kept for manual review.
          continue;
        }
        // Stop draining on first failure so writes replay in order and we
        // don't hammer a backend that's still struggling.
        rethrow;
      }
    }
  }

  Future<void> _replayRegisterRecruit(Map<String, dynamic> payload) async {
    final client = SupabaseService.client;

    final existing = await client
        .from('recruits')
        .select('id')
        .eq('id_number', payload['id_number'])
        .maybeSingle();
    if (existing != null) {
      // Already registered (e.g. synced from another device) — treat as
      // success rather than erroring the queue.
      return;
    }

    final recruitData = await client
        .from('recruits')
        .insert({
          'full_name': payload['full_name'],
          'id_number': payload['id_number'],
          'phone': payload['phone'],
          'region': payload['region'],
          'fingerprint_hash': payload['fingerprint_hash'],
          'status': 'clear',
          'registered_by': payload['registered_by'],
        })
        .select()
        .single();

    await client.from('employment_history').insert({
      'recruit_id': recruitData['id'],
      'company_id': payload['company_id'],
      'role': payload['role'],
      'start_date': payload['start_date'],
    });

    await client.from('audit_logs').insert({
      'company_id': payload['company_id'],
      'user_id': payload['registered_by'],
      'action': 'REGISTER',
      'detail':
          'Registered recruit: ${payload['full_name']} (${payload['id_number']}) [synced from offline queue]',
      'recruit_id': recruitData['id'],
    });
  }

  Future<void> _replayAddConductRecord(Map<String, dynamic> payload) async {
    final client = SupabaseService.client;

    await client.from('conduct_records').insert({
      'recruit_id': payload['recruit_id'],
      'company_id': payload['company_id'],
      'type': payload['type'],
      'description': payload['description'],
      'reported_by': payload['reported_by'],
      'submitted_by': payload['submitted_by'],
      'incident_date': payload['incident_date'],
    });

    await client.from('audit_logs').insert({
      'company_id': payload['company_id'],
      'user_id': payload['submitted_by'],
      'action': 'ADD_RECORD',
      'detail':
          'Added ${payload['type']} record for recruit ${payload['recruit_id']} [synced from offline queue]',
      'recruit_id': payload['recruit_id'],
    });
  }

  // ── Cache refresh ────────────────────────────────────────────────────

  Future<void> _refreshCache() async {
    final client = SupabaseService.client;

    final recruits = await client.from('recruits').select('''
          *,
          employment_history ( *, companies ( id, name ) ),
          conduct_records    ( *, companies ( id, name ) )
        ''').limit(500);

    await LocalDb.cacheRecruits(
        (recruits as List).cast<Map<String, dynamic>>());

    final companies = await client.from('companies').select();
    await LocalDb.cacheCompanies(
        (companies as List).cast<Map<String, dynamic>>());

    // Cache the current user's company_id so offline writes (register
    // recruit, add conduct record) don't need a network round-trip just
    // to know which company they belong to.
    final user = SupabaseService.currentUser;
    if (user != null) {
      final userData = await client
          .from('users')
          .select('company_id')
          .eq('id', user.id)
          .maybeSingle();
      if (userData != null) {
        await LocalDb.cacheMyCompanyId(userData['company_id'] as String);
      }
    }

    await LocalDb.setMeta('last_full_sync', DateTime.now().toIso8601String());
  }
}
