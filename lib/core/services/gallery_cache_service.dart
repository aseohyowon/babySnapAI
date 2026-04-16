import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../data/models/cached_scan_record_model.dart';
import '../constants/app_constants.dart';

class GalleryCacheService {
  static const _dbName = 'babysnap_cache.db';
  static const _dbVersion = 2;

  Database? _db;

  Future<Database> _database() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE scan_records (
            asset_id TEXT PRIMARY KEY,
            path TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            modified_at INTEGER NOT NULL,
            has_face INTEGER NOT NULL,
            is_baby INTEGER NOT NULL,
            face_count INTEGER NOT NULL,
            quick_scanned INTEGER NOT NULL DEFAULT 0,
            face_vector TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE excluded_asset_ids (
            asset_id TEXT PRIMARY KEY
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_scan_records_created_at ON scan_records(created_at DESC)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE scan_records ADD COLUMN quick_scanned INTEGER NOT NULL DEFAULT 0',
          );
        }
      },
    );
    return _db!;
  }

  Future<List<CachedScanRecordModel>> loadRecords() async {
    final db = await _database();
    final rows = await db.query('scan_records', orderBy: 'created_at DESC');
    return rows.map(_mapRowToRecord).toList(growable: false);
  }

  Future<void> saveRecords(List<CachedScanRecordModel> records) async {
    if (records.isEmpty) {
      await _saveLastScanAt(DateTime.now());
      return;
    }

    final db = await _database();
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final record in records) {
        batch.insert(
          'scan_records',
          {
            'asset_id': record.assetId,
            'path': record.path,
            'created_at': record.createdAt.millisecondsSinceEpoch,
            'modified_at': record.modifiedAt.millisecondsSinceEpoch,
            'has_face': record.hasFace ? 1 : 0,
            'is_baby': record.isBaby ? 1 : 0,
            'face_count': record.faceCount,
            'quick_scanned': record.quickScanned ? 1 : 0,
            'face_vector': record.faceVector == null
                ? null
                : jsonEncode(record.faceVector),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
    await _saveLastScanAt(DateTime.now());
  }

  Future<DateTime?> loadLastScanAt() async {
    final db = await _database();
    final rows = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [AppConstants.lastScanAtKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final raw = rows.first['value'] as String?;
    if (raw == null || raw.isEmpty) return null;
    final millis = int.tryParse(raw);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<Set<String>> loadExcludedAssetIds() async {
    final db = await _database();
    final rows = await db.query('excluded_asset_ids', columns: ['asset_id']);
    return rows.map((row) => row['asset_id'] as String).toSet();
  }

  Future<void> saveExcludedAssetIds(Set<String> assetIds) async {
    final db = await _database();
    await db.transaction((txn) async {
      await txn.delete('excluded_asset_ids');
      if (assetIds.isEmpty) return;
      final batch = txn.batch();
      for (final assetId in assetIds) {
        batch.insert('excluded_asset_ids', {'asset_id': assetId});
      }
      await batch.commit(noResult: true);
    });
  }

  Future<int> loadFilterVersion() async {
    final db = await _database();
    final rows = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [AppConstants.cacheFilterVersionKey],
      limit: 1,
    );
    if (rows.isEmpty) return -1;
    final raw = rows.first['value'] as String?;
    return int.tryParse(raw ?? '') ?? -1;
  }

  Future<void> saveFilterVersion() async {
    final db = await _database();
    await db.insert(
      'settings',
      {
        'key': AppConstants.cacheFilterVersionKey,
        'value': AppConstants.cacheFilterVersion.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearRecords() async {
    final db = await _database();
    await db.delete('scan_records');
    await db.delete(
      'settings',
      where: 'key IN (?, ?)',
      whereArgs: [AppConstants.lastScanAtKey, AppConstants.cacheFilterVersionKey],
    );
  }

  Future<void> _saveLastScanAt(DateTime at) async {
    final db = await _database();
    await db.insert(
      'settings',
      {
        'key': AppConstants.lastScanAtKey,
        'value': at.millisecondsSinceEpoch.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  CachedScanRecordModel _mapRowToRecord(Map<String, Object?> row) {
    final vectorRaw = row['face_vector'] as String?;
    final vector = (vectorRaw == null || vectorRaw.isEmpty)
        ? null
        : (jsonDecode(vectorRaw) as List<dynamic>)
            .map((e) => (e as num).toDouble())
            .toList(growable: false);

    return CachedScanRecordModel(
      assetId: row['asset_id'] as String,
      path: row['path'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(row['modified_at'] as int),
      hasFace: (row['has_face'] as int) == 1,
      isBaby: (row['is_baby'] as int) == 1,
      faceCount: row['face_count'] as int,
      quickScanned: ((row['quick_scanned'] as int?) ?? 0) == 1,
      faceVector: vector,
    );
  }
}
