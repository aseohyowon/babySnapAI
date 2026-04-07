import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/baby_profile.dart';
import '../../domain/repositories/baby_profile_repository.dart';

class BabyProfileRepositoryImpl implements BabyProfileRepository {
  static const String _key = 'baby_profiles_v1';

  @override
  Future<List<BabyProfile>> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <BabyProfile>[];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((item) => BabyProfile.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveProfile(BabyProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await loadProfiles();
    final updated = profiles.where((p) => p.id != profile.id).toList()
      ..add(profile);
    await prefs.setString(
      _key,
      jsonEncode(updated.map((p) => p.toJson()).toList()),
    );
  }

  @override
  Future<void> deleteProfile(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await loadProfiles();
    final updated = profiles.where((p) => p.id != id).toList();
    await prefs.setString(
      _key,
      jsonEncode(updated.map((p) => p.toJson()).toList()),
    );
  }
}
