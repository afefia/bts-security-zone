import 'package:flutter/material.dart';

// ============================================================
//  These mirror the Supabase schema (supabase_schema.sql).
//  This is the single source of truth for app data models —
//  used by all screens and services after backend integration.
// ============================================================

class DbCompany {
  final String id;
  final String name;
  final String licenseNumber;
  final String region;
  final String? address;
  final String email;
  final String? phone;
  final bool isVerified;
  final DateTime? verifiedAt;
  final DateTime createdAt;

  DbCompany({
    required this.id,
    required this.name,
    required this.licenseNumber,
    required this.region,
    this.address,
    required this.email,
    this.phone,
    required this.isVerified,
    this.verifiedAt,
    required this.createdAt,
  });

  factory DbCompany.fromJson(Map<String, dynamic> json) {
    return DbCompany(
      id: json['id'] as String,
      name: json['name'] as String,
      licenseNumber: json['license_number'] as String,
      region: json['region'] as String,
      address: json['address'] as String?,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      verifiedAt: json['verified_at'] != null
          ? DateTime.parse(json['verified_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// The current logged-in user's profile — role and company in one place
/// so the app doesn't need two separate async calls to answer "is this
/// person an admin?"
class DbUserProfile {
  final String id;
  final String fullName;
  final String email;
  final String role; // 'admin' | 'company_user'
  final String companyId;

  const DbUserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.companyId,
  });

  bool get isAdmin => role == 'admin';

  factory DbUserProfile.fromJson(Map<String, dynamic> json) {
    return DbUserProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      role: json['role'] as String? ?? 'company_user',
      companyId: json['company_id'] as String,
    );
  }
}

class DbEmploymentHistory {
  final String id;
  final String recruitId;
  final String companyId;
  final String companyName;
  final String role;
  final DateTime startDate;
  final DateTime? endDate;
  final String? exitReason;

  DbEmploymentHistory({
    required this.id,
    required this.recruitId,
    required this.companyId,
    required this.companyName,
    required this.role,
    required this.startDate,
    this.endDate,
    this.exitReason,
  });

  bool get isCurrent => endDate == null;

  factory DbEmploymentHistory.fromJson(Map<String, dynamic> json) {
    final company = json['companies'] as Map<String, dynamic>?;
    return DbEmploymentHistory(
      id: json['id'] as String,
      recruitId: json['recruit_id'] as String,
      companyId: json['company_id'] as String,
      companyName: company?['name'] as String? ?? 'Unknown Company',
      role: json['role'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      exitReason: json['exit_reason'] as String?,
    );
  }
}

class DbConductRecord {
  final String id;
  final String recruitId;
  final String companyId;
  final String companyName;
  final String type; // commendation | warning | suspension | misconduct | termination
  final String description;
  final String reportedBy;
  final DateTime incidentDate;
  final DateTime createdAt;

  DbConductRecord({
    required this.id,
    required this.recruitId,
    required this.companyId,
    required this.companyName,
    required this.type,
    required this.description,
    required this.reportedBy,
    required this.incidentDate,
    required this.createdAt,
  });

  factory DbConductRecord.fromJson(Map<String, dynamic> json) {
    final company = json['companies'] as Map<String, dynamic>?;
    return DbConductRecord(
      id: json['id'] as String,
      recruitId: json['recruit_id'] as String,
      companyId: json['company_id'] as String,
      companyName: company?['name'] as String? ?? 'Unknown Company',
      type: json['type'] as String,
      description: json['description'] as String,
      reportedBy: json['reported_by'] as String,
      incidentDate: DateTime.parse(json['incident_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Color get typeColor {
    switch (type) {
      case 'commendation':
        return const Color(0xFF2EC4B6);
      case 'warning':
        return const Color(0xFFF0C040);
      case 'suspension':
        return const Color(0xFFFF9F1C);
      case 'termination':
      case 'misconduct':
        return const Color(0xFFE63946);
      default:
        return const Color(0xFF8892A4);
    }
  }

  String get typeLabel {
    switch (type) {
      case 'commendation':
        return 'Commendation';
      case 'warning':
        return 'Warning';
      case 'suspension':
        return 'Suspension';
      case 'termination':
        return 'Termination';
      case 'misconduct':
        return 'Misconduct';
      default:
        return type;
    }
  }
}

class DbRecruit {
  final String id;
  final String fullName;
  final String idNumber;
  final String? fingerprintHash;
  final String? phone;
  final String region;
  final String? photoUrl;
  final String status; // clear | flagged | terminated | suspended
  final DateTime registeredAt;
  final List<DbEmploymentHistory> employmentHistory;
  final List<DbConductRecord> conductRecords;

  DbRecruit({
    required this.id,
    required this.fullName,
    required this.idNumber,
    this.fingerprintHash,
    this.phone,
    required this.region,
    this.photoUrl,
    required this.status,
    required this.registeredAt,
    required this.employmentHistory,
    required this.conductRecords,
  });

  factory DbRecruit.fromJson(Map<String, dynamic> json) {
    final employment = (json['employment_history'] as List? ?? [])
        .map((e) => DbEmploymentHistory.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    final conduct = (json['conduct_records'] as List? ?? [])
        .map((e) => DbConductRecord.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.incidentDate.compareTo(b.incidentDate));

    return DbRecruit(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      idNumber: json['id_number'] as String,
      fingerprintHash: json['fingerprint_hash'] as String?,
      phone: json['phone'] as String?,
      region: json['region'] as String,
      photoUrl: json['photo_url'] as String?,
      status: json['status'] as String? ?? 'clear',
      registeredAt: DateTime.parse(json['registered_at'] as String),
      employmentHistory: employment,
      conductRecords: conduct,
    );
  }

  String get statusLabel => status.toUpperCase();

  Color get statusColor {
    switch (status) {
      case 'clear':
        return const Color(0xFF2EC4B6);
      case 'flagged':
        return const Color(0xFFF0C040);
      case 'terminated':
        return const Color(0xFFE63946);
      case 'suspended':
        return const Color(0xFFFF9F1C);
      default:
        return const Color(0xFF8892A4);
    }
  }
}

class DbAlert {
  final String id;
  final String companyId;
  final String title;
  final String body;
  final String severity; // high | medium | info
  final bool isRead;
  final String? recruitId;
  final DateTime createdAt;

  DbAlert({
    required this.id,
    required this.companyId,
    required this.title,
    required this.body,
    required this.severity,
    required this.isRead,
    this.recruitId,
    required this.createdAt,
  });

  factory DbAlert.fromJson(Map<String, dynamic> json) {
    return DbAlert(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      severity: json['severity'] as String,
      isRead: json['is_read'] as bool? ?? false,
      recruitId: json['recruit_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Color get color {
    switch (severity) {
      case 'high':
        return const Color(0xFFE63946);
      case 'medium':
        return const Color(0xFFD4A017);
      default:
        return const Color(0xFF2EC4B6);
    }
  }
}

class DbAuditEntry {
  final String id;
  final String? companyId;
  final String companyName;
  final String action;
  final String detail;
  final DateTime createdAt;

  DbAuditEntry({
    required this.id,
    this.companyId,
    required this.companyName,
    required this.action,
    required this.detail,
    required this.createdAt,
  });

  factory DbAuditEntry.fromJson(Map<String, dynamic> json) {
    final company = json['companies'] as Map<String, dynamic>?;
    return DbAuditEntry(
      id: json['id'] as String,
      companyId: json['company_id'] as String?,
      companyName: company?['name'] as String? ?? 'System',
      action: json['action'] as String,
      detail: json['detail'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
