import '../entities/baby_profile.dart';

abstract class BabyProfileRepository {
  Future<List<BabyProfile>> loadProfiles();
  Future<void> saveProfile(BabyProfile profile);
  Future<void> deleteProfile(String id);
}
