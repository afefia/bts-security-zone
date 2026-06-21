import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Local SQLite cache so the app stays usable when connectivity drops.
///
/// Two jobs:
/// 1. CACHE  — last-synced recruits/companies/conduct records, readable
///    offline so a search still returns useful (if possibly stale) results.
/// 2. OUTBOX — writes made while offline (register recruit, add conduct
///    record) are queued here and replayed against Supabase once
///    connectivity returns.
///
/// NOTE: sqflite does not work on web. When running in a browser (Edge),
/// all LocalDb calls silently return null/empty so the app falls back to
/// Supabase directly. Offline caching is desktop/mobile only.
class LocalDb {
  static Database? _db;
  static const _dbName = 'security_zone_cache.db';
  static const _dbVersion = 1;

  static bool get _isWeb => kIsWeb;

  static Future<Database?> get instance async {
    if (_isWeb) return null;
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cached_recruits (
            id TEXT PRIMARY KEY,
            full_name TEXT NOT NULL,
            id_number TEXT NOT NULL,
            data TEXT NOT NULL,
            synced_at TEXT NOT NULL
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_cached_recruits_name ON cached_recruits(full_name)');
        await db.execute(
            'CREATE INDEX idx_cached_recruits_idnum ON cached_recruits(id_number)');

        await db.execute('''
          CREATE TABLE cached_companies (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            synced_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE outbox (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            kind TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL,
            attempts INTEGER NOT NULL DEFAULT 0,
            last_error TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE sync_meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // ── Recruits cache ─────────────────────────────────────────────────────

  static Future<void> cacheRecruits(List<Map<String, dynamic>> recruits) async {
    final db = await instance;
    if (db == null) return;
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final r in recruits) {
      batch.insert(
        'cached_recruits',
        {
          'id': r['id'],
          'full_name': r['full_name'],
          'id_number': r['id_number'],
          'data': jsonEncode(r),
          'synced_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<void> cacheRecruit(Map<String, dynamic> recruit) async {
    await cacheRecruits([recruit]);
  }

  static Future<List<Map<String, dynamic>>> searchCachedRecruits(
      String query) async {
    final db = await instance;
    if (db == null) return [];
    final q = '%${query.toLowerCase()}%';
    final rows = await db.query(
      'cached_recruits',
      where: 'LOWER(full_name) LIKE ? OR LOWER(id_number) LIKE ?',
      whereArgs: [q, q],
      orderBy: 'full_name',
    );
    return rows
        .map((r) => jsonDecode(r['data'] as String) as Map<String, dynamic>)
        .toList();
  }

  static Future<Map<String, dynamic>?> getCachedRecruitById(String id) async {
    final db = await instance;
    if (db == null) return null;
    final rows = await db.query(
      'cached_recruits',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['data'] as String) as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> getAllCachedRecruits() async {
    final db = await instance;
    if (db == null) return [];
    final rows = await db.query('cached_recruits', orderBy: 'full_name');
    return rows
        .map((r) => jsonDecode(r['data'] as String) as Map<String, dynamic>)
        .toList();
  }

  static Future<DateTime?> getRecruitsLastSyncedAt() async {
    final db = await instance;
    if (db == null) return null;
    final rows = await db.query('cached_recruits',
        columns: ['synced_at'], orderBy: 'synced_at DESC', limit: 1);
    if (rows.isEmpty) return null;
    return DateTime.parse(rows.first['synced_at'] as String);
  }

  // ── Companies cache ────────────────────────────────────────────────────

  static Future<void> cacheCompanies(
      List<Map<String, dynamic>> companies) async {
    final db = await instance;
    if (db == null) return;
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final c in companies) {
      batch.insert(
        'cached_companies',
        {'id': c['id'], 'data': jsonEncode(c), 'synced_at': now},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getAllCachedCompanies() async {
    final db = await instance;
    if (db == null) return [];
    final rows = await db.query('cached_companies');
    return rows
        .map((r) => jsonDecode(r['data'] as String) as Map<String, dynamic>)
        .toList();
  }

  // ── Outbox (pending writes) ───────────────────────────────────────────

  static Future<int> queueWrite({
    required String kind,
    required Map<String, dynamic> payload,
  }) async {
    final db = await instance;
    if (db == null) return -1;
    return db.insert('outbox', {
      'kind': kind,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
      'attempts': 0,
    });
  }

  static Future<List<OutboxItem>> getPendingWrites() async {
    final db = await instance;
    if (db == null) return [];
    final rows = await db.query('outbox', orderBy: 'created_at ASC');
    return rows.map(OutboxItem.fromRow).toList();
  }

  static Future<int> getPendingWriteCount() async {
    final db = await instance;
    if (db == null) return 0;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM outbox');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  static Future<void> markWriteSucceeded(int outboxId) async {
    final db = await instance;
    if (db == null) return;
    await db.delete('outbox', where: 'id = ?', whereArgs: [outboxId]);
  }

  static Future<void> markWriteFailed(int outboxId, String error) async {
    final db = await instance;
    if (db == null) return;
    await db.rawUpdate(
      'UPDATE outbox SET attempts = attempts + 1, last_error = ? WHERE id = ?',
      [error, outboxId],
    );
  }

  static Future<void> removeWrite(int outboxId) async {
    final db = await instance;
    if (db == null) return;
    await db.delete('outbox', where: 'id = ?', whereArgs: [outboxId]);
  }

  // ── Sync metadata ──────────────────────────────────────────────────────

  static Future<void> setMeta(String key, String value) async {
    final db = await instance;
    if (db == null) return;
    await db.insert(
      'sync_meta',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<String?> getMeta(String key) async {
    final db = await instance;
    if (db == null) return null;
    final rows =
        await db.query('sync_meta', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  static Future<void> cacheMyCompanyId(String companyId) =>
      setMeta('my_company_id', companyId);

  static Future<String?> getMyCachedCompanyId() => getMeta('my_company_id');

  // ── Maintenance ──────────────────────────────────────────────────────

  static Future<void> clearAll() async {
    final db = await instance;
    if (db == null) return;
    await db.delete('cached_recruits');
    await db.delete('cached_companies');
    await db.delete('outbox');
    await db.delete('sync_meta');
  }
}

class OutboxItem {
  final int id;
  final String kind;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;

  OutboxItem({
    required this.id,
    required this.kind,
    required this.payload,
    required this.createdAt,
    required this.attempts,
    this.lastError,
  });

  factory OutboxItem.fromRow(Map<String, dynamic> row) {
    return OutboxItem(
      id: row['id'] as int,
      kind: row['kind'] as String,
      payload: jsonDecode(row['payload'] as String) as Map<String, dynamic>,
      createdAt: DateTime.parse(row['created_at'] as String),
      attempts: row['attempts'] as int,
      lastError: row['last_error'] as String?,
    );
  }
}
