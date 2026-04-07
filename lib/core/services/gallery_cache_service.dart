import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../../data/models/cached_scan_record_model.dart';

class GalleryCacheService {
  Future<List<CachedScanRecordModel>> loadRecords() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(AppConstants.scanCacheKey);
    if (raw == null || raw.isEmpty) {
      return <CachedScanRecordModel>[];
    }

    final decoded = await compute(_decodeRecords, raw);
    return decoded
        .map((item) => CachedScanRecordModel.fromJson(item))
        .toList(growable: false);
  }

  Future<void> saveRecords(List<CachedScanRecordModel> records) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = await compute(
      _encodeRecords,
      records.map((record) => record.toJson()).toList(growable: false),
    );

    await preferences.setString(AppConstants.scanCacheKey, raw);
    await preferences.setInt(
      AppConstants.lastScanAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<DateTime?> loadLastScanAt() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getInt(AppConstants.lastScanAtKey);
    if (value == null) {
      return null;
    }

    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  Future<Set<String>> loadExcludedAssetIds() async {
    final preferences = await SharedPreferences.getInstance();
    final values =
        preferences.getStringList(AppConstants.excludedAssetIdsKey) ?? <String>[];
    return values.toSet();
  }

  Future<void> saveExcludedAssetIds(Set<String> assetIds) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      AppConstants.excludedAssetIdsKey,
      assetIds.toList(growable: false),
    );
  }

  /// Returns the filter version that was used for the current cache.
  /// Returns -1 if never saved (cache is stale/legacy).
  Future<int> loadFilterVersion() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt(AppConstants.cacheFilterVersionKey) ?? -1;
  }

  /// Saves the current filter version alongside the scan cache.
  Future<void> saveFilterVersion() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(
        AppConstants.cacheFilterVersionKey, AppConstants.cacheFilterVersion);
  }

  /// Clears the scan cache records so the next scan starts fresh.
  Future<void> clearRecords() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(AppConstants.scanCacheKey);
    await preferences.remove(AppConstants.lastScanAtKey);
  }
}

List<Map<String, dynamic>> _decodeRecords(String raw) {
  final decoded = jsonDecode(raw) as List<dynamic>;
  return decoded.cast<Map<String, dynamic>>();
}

String _encodeRecords(List<Map<String, dynamic>> records) {
  return jsonEncode(records);
}
