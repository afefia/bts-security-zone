import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_service.dart';
import '../utils/validators.dart';

enum DisputeStatus { pending, upheld, rejected }

class ConductDispute {
  final String id;
  final String conductRecordId;
  final String disputedByCompanyId;
  final String disputedByCompanyName;
  final String submittedByUserId;
  final String reason;
  final DisputeStatus status;
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const ConductDispute({
    required this.id,
    required this.conductRecordId,
    required this.disputedByCompanyId,
    required this.disputedByCompanyName,
    required this.submittedByUserId,
    required this.reason,
    required this.status,
    this.adminNotes,
    required this.createdAt,
    this.resolvedAt,
  });

  factory ConductDispute.fromJson(Map<String, dynamic> json) {
    return ConductDispute(
      id: json['id'] as String,
      conductRecordId: json['conduct_record_id'] as String,
      disputedByCompanyId: json['disputed_by'] as String,
      disputedByCompanyName:
          (json['companies'] as Map<String, dynamic>?)?['name'] as String? ??
              'Unknown Company',
      submittedByUserId: json['submitted_by_user'] as String,
      reason: json['reason'] as String,
      status: DisputeStatus.values.firstWhere(
        (s) => s.name == (json['status'] as String),
        orElse: () => DisputeStatus.pending,
      ),
      adminNotes: json['admin_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      resolvedAt: json['resolved_at'] == null
          ? null
          : DateTime.parse(json['resolved_at'] as String),
    );
  }

  bool get isPending => status == DisputeStatus.pending;
}

class DisputeService {
  final _client = SupabaseService.client;

  /// File a dispute against a conduct record. A company can only file one
  /// dispute per record (enforced by a UNIQUE constraint in the DB too).
  Future<void> fileDispute({
    required String conductRecordId,
    required String reason,
  }) async {
    // Validate reason length — mirrors the DB CHECK constraint
    final err = _validateReason(reason);
    if (err != null) throw ArgumentError(err);

    final user = SupabaseService.currentUser!;
    final userData = await _client
        .from('users')
        .select('company_id')
        .eq('id', user.id)
        .single();
    final companyId = userData['company_id'] as String;

    await _client.from('conduct_disputes').insert({
      'conduct_record_id': conductRecordId,
      'disputed_by': companyId,
      'submitted_by_user': user.id,
      'reason': Validators.sanitize(reason),
    });

    // Audit trail
    await _client.from('audit_logs').insert({
      'company_id': companyId,
      'user_id': user.id,
      'action': 'DISPUTE',
      'detail': 'Filed dispute against conduct record $conductRecordId',
    });
  }

  /// Get all disputes for a given conduct record (so the recruit profile
  /// can show a DISPUTED badge and list who contested it and why).
  Future<List<ConductDispute>> getDisputesForRecord(
      String conductRecordId) async {
    final data = await _client
        .from('conduct_disputes')
        .select('*, companies ( name )')
        .eq('conduct_record_id', conductRecordId)
        .order('created_at', ascending: false);

    return (data as List)
        .map((e) => ConductDispute.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// All disputes visible to the current company — used in an alerts-style
  /// feed so companies can track disputes they filed or disputes on records
  /// they filed (since a dispute against them is worth knowing about).
  Future<List<ConductDispute>> getMyDisputes() async {
    final data = await _client
        .from('conduct_disputes')
        .select('*, companies ( name )')
        .eq('disputed_by', await _myCompanyId())
        .order('created_at', ascending: false);

    return (data as List)
        .map((e) => ConductDispute.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Admin operations ───────────────────────────────────────────────

  /// All pending disputes — for the admin panel's dispute review tab.
  Future<List<ConductDispute>> getAllPendingDisputes() async {
    final data = await _client
        .from('conduct_disputes')
        .select('*, companies ( name )')
        .eq('status', 'pending')
        .order('created_at', ascending: true); // oldest first

    return (data as List)
        .map((e) => ConductDispute.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Uphold a dispute: the disputed conduct record is removed, the recruit's
  /// status is recalculated, and the resolution is logged.
  Future<void> upholdDispute({
    required String disputeId,
    required String conductRecordId,
    String? adminNotes,
  }) async {
    final user = SupabaseService.currentUser!;

    // Fetch the recruit_id before deleting the record
    final recordData = await _client
        .from('conduct_records')
        .select('recruit_id')
        .eq('id', conductRecordId)
        .maybeSingle();

    final recruitId = recordData?['recruit_id'] as String?;

    await _client.from('conduct_disputes').update({
      'status': 'upheld',
      'admin_notes': adminNotes,
      'resolved_by': user.id,
      'resolved_at': DateTime.now().toIso8601String(),
    }).eq('id', disputeId);

    // Remove the disputed record
    await _client
        .from('conduct_records')
        .delete()
        .eq('id', conductRecordId);

    // Recalculate recruit status based on remaining records
    if (recruitId != null) {
      await _recalculateRecruitStatus(recruitId);
    }

    await _client.from('audit_logs').insert({
      'company_id': null,
      'user_id': user.id,
      'action': 'DISPUTE',
      'detail':
          'Upheld dispute $disputeId — conduct record $conductRecordId removed',
      if (recruitId != null) 'recruit_id': recruitId,
    });
  }

  /// Reject a dispute: the conduct record stands, the dispute is closed.
  Future<void> rejectDispute({
    required String disputeId,
    String? adminNotes,
  }) async {
    final user = SupabaseService.currentUser!;

    await _client.from('conduct_disputes').update({
      'status': 'rejected',
      'admin_notes': adminNotes,
      'resolved_by': user.id,
      'resolved_at': DateTime.now().toIso8601String(),
    }).eq('id', disputeId);

    await _client.from('audit_logs').insert({
      'company_id': null,
      'user_id': user.id,
      'action': 'DISPUTE',
      'detail': 'Rejected dispute $disputeId — conduct record stands',
    });
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  Future<String> _myCompanyId() async {
    final user = SupabaseService.currentUser!;
    final data = await _client
        .from('users')
        .select('company_id')
        .eq('id', user.id)
        .single();
    return data['company_id'] as String;
  }

  Future<void> _recalculateRecruitStatus(String recruitId) async {
    final remaining = await _client
        .from('conduct_records')
        .select('type')
        .eq('recruit_id', recruitId);

    final types =
        (remaining as List).map((r) => r['type'] as String).toList();

    String newStatus = 'clear';
    if (types.contains('termination')) {
      newStatus = 'terminated';
    } else if (types.contains('misconduct') || types.contains('suspension')) {
      newStatus = 'suspended';
    } else if (types.contains('warning')) {
      newStatus = 'flagged';
    }

    await _client
        .from('recruits')
        .update({'status': newStatus, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', recruitId);
  }

  String? _validateReason(String reason) {
    final v = Validators.sanitize(reason);
    if (v.length < 20) {
      return 'Please provide a detailed reason (at least 20 characters)';
    }
    if (v.length > 2000) return 'Reason must be 2000 characters or fewer';
    return null;
  }
}
