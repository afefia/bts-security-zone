import 'package:flutter/material.dart';

enum RecordStatus { clear, flagged, terminated, suspended }

enum RecordType { commendation, warning, suspension, termination, misconduct }

class Company {
  final String id;
  final String name;
  final String licenseNumber;
  final String region;
  final String contactEmail;
  final bool isVerified;
  final DateTime registeredAt;

  const Company({
    required this.id,
    required this.name,
    required this.licenseNumber,
    required this.region,
    required this.contactEmail,
    this.isVerified = false,
    required this.registeredAt,
  });
}

class ConductRecord {
  final String id;
  final String companyId;
  final String companyName;
  final RecordType type;
  final String description;
  final DateTime date;
  final String reportedBy;

  const ConductRecord({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.type,
    required this.description,
    required this.date,
    required this.reportedBy,
  });

  Color get typeColor {
    switch (type) {
      case RecordType.commendation:
        return const Color(0xFF2EC4B6);
      case RecordType.warning:
        return const Color(0xFFF0C040);
      case RecordType.suspension:
        return const Color(0xFFFF9F1C);
      case RecordType.termination:
      case RecordType.misconduct:
        return const Color(0xFFE63946);
    }
  }

  String get typeLabel {
    switch (type) {
      case RecordType.commendation:
        return 'Commendation';
      case RecordType.warning:
        return 'Warning';
      case RecordType.suspension:
        return 'Suspension';
      case RecordType.termination:
        return 'Termination';
      case RecordType.misconduct:
        return 'Misconduct';
    }
  }
}

class EmploymentHistory {
  final String companyId;
  final String companyName;
  final String role;
  final DateTime startDate;
  final DateTime? endDate;
  final String? exitReason;

  const EmploymentHistory({
    required this.companyId,
    required this.companyName,
    required this.role,
    required this.startDate,
    this.endDate,
    this.exitReason,
  });

  bool get isCurrent => endDate == null;
}

class Recruit {
  final String id;
  final String fullName;
  final String idNumber;
  final String? fingerprintHash;
  final String phone;
  final String region;
  final String photoUrl;
  final RecordStatus status;
  final List<EmploymentHistory> employmentHistory;
  final List<ConductRecord> conductRecords;
  final DateTime registeredAt;

  const Recruit({
    required this.id,
    required this.fullName,
    required this.idNumber,
    this.fingerprintHash,
    required this.phone,
    required this.region,
    required this.photoUrl,
    required this.status,
    required this.employmentHistory,
    required this.conductRecords,
    required this.registeredAt,
  });

  String get statusLabel {
    switch (status) {
      case RecordStatus.clear:
        return 'CLEAR';
      case RecordStatus.flagged:
        return 'FLAGGED';
      case RecordStatus.terminated:
        return 'TERMINATED';
      case RecordStatus.suspended:
        return 'SUSPENDED';
    }
  }

  Color get statusColor {
    switch (status) {
      case RecordStatus.clear:
        return const Color(0xFF2EC4B6);
      case RecordStatus.flagged:
        return const Color(0xFFF0C040);
      case RecordStatus.terminated:
        return const Color(0xFFE63946);
      case RecordStatus.suspended:
        return const Color(0xFFFF9F1C);
    }
  }
}

// ── Sample Data ──────────────────────────────────────────────────────────────

class SampleData {
  static final List<Recruit> recruits = [
    Recruit(
      id: 'R001',
      fullName: 'Kodzo Mensah',
      idNumber: 'GHA-2019-004521',
      phone: '+233 24 567 8901',
      region: 'Greater Accra',
      photoUrl: '',
      status: RecordStatus.terminated,
      registeredAt: DateTime(2019, 4, 10),
      employmentHistory: [
        EmploymentHistory(
          companyId: 'C001',
          companyName: 'Alpha Shield Security',
          role: 'Security Guard',
          startDate: DateTime(2019, 5, 1),
          endDate: DateTime(2021, 3, 15),
          exitReason: 'Terminated — misconduct',
        ),
        EmploymentHistory(
          companyId: 'C002',
          companyName: 'Eagle Eye Protection',
          role: 'Security Guard',
          startDate: DateTime(2021, 4, 20),
          endDate: DateTime(2022, 7, 10),
          exitReason: 'Resigned',
        ),
        EmploymentHistory(
          companyId: 'C003',
          companyName: 'Guardian Force Ltd',
          role: 'Senior Guard',
          startDate: DateTime(2022, 9, 1),
        ),
      ],
      conductRecords: [
        ConductRecord(
          id: 'CR001',
          companyId: 'C001',
          companyName: 'Alpha Shield Security',
          type: RecordType.warning,
          description: 'Absent from post without authorization on 3 occasions.',
          date: DateTime(2020, 6, 12),
          reportedBy: 'Supervisor K. Asante',
        ),
        ConductRecord(
          id: 'CR002',
          companyId: 'C001',
          companyName: 'Alpha Shield Security',
          type: RecordType.termination,
          description:
              'Terminated following theft investigation at client premises.',
          date: DateTime(2021, 3, 15),
          reportedBy: 'HR Manager — Alpha Shield',
        ),
        ConductRecord(
          id: 'CR003',
          companyId: 'C002',
          companyName: 'Eagle Eye Protection',
          type: RecordType.commendation,
          description: 'Recognized for alertness during an attempted break-in.',
          date: DateTime(2022, 1, 8),
          reportedBy: 'Operations Manager',
        ),
      ],
    ),
    Recruit(
      id: 'R002',
      fullName: 'Abena Osei',
      idNumber: 'GHA-2020-008874',
      phone: '+233 20 112 3344',
      region: 'Ashanti',
      photoUrl: '',
      status: RecordStatus.clear,
      registeredAt: DateTime(2020, 1, 15),
      employmentHistory: [
        EmploymentHistory(
          companyId: 'C002',
          companyName: 'Eagle Eye Protection',
          role: 'Security Officer',
          startDate: DateTime(2020, 2, 1),
        ),
      ],
      conductRecords: [
        ConductRecord(
          id: 'CR004',
          companyId: 'C002',
          companyName: 'Eagle Eye Protection',
          type: RecordType.commendation,
          description: 'Employee of the Quarter — Q3 2023.',
          date: DateTime(2023, 10, 1),
          reportedBy: 'Branch Manager',
        ),
      ],
    ),
  ];

  static final List<Company> companies = [
    Company(
      id: 'C001',
      name: 'Alpha Shield Security',
      licenseNumber: 'PSC-GH-1042',
      region: 'Greater Accra',
      contactEmail: 'info@alphashield.gh',
      isVerified: true,
      registeredAt: DateTime(2018, 3, 20),
    ),
    Company(
      id: 'C002',
      name: 'Eagle Eye Protection',
      licenseNumber: 'PSC-GH-2211',
      region: 'Ashanti',
      contactEmail: 'admin@eagleeye.gh',
      isVerified: true,
      registeredAt: DateTime(2019, 7, 5),
    ),
    Company(
      id: 'C003',
      name: 'Guardian Force Ltd',
      licenseNumber: 'PSC-GH-3390',
      region: 'Western',
      contactEmail: 'ops@guardianforce.gh',
      isVerified: false,
      registeredAt: DateTime(2022, 1, 14),
    ),
  ];
}
