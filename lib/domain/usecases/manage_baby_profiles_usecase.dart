import 'dart:io';
import 'dart:math';

import '../../core/services/face_detection_service.dart';
import '../../domain/entities/baby_profile.dart';
import '../../domain/repositories/baby_profile_repository.dart';

class ManageBabyProfilesUseCase {
  ManageBabyProfilesUseCase(this._repository, this._faceDetectionService);

  final BabyProfileRepository _repository;
  final FaceDetectionService _faceDetectionService;

  Future<List<BabyProfile>> loadProfiles() => _repository.loadProfiles();

  Future<void> saveProfile(BabyProfile profile) =>
      _repository.saveProfile(profile);

  Future<void> deleteProfile(String id) => _repository.deleteProfile(id);

  /// Analyzes [imagePath] and returns the extracted face vector.
  /// Returns null if no valid face or missing landmarks.
  Future<List<double>?> extractFaceVector(String imagePath) async {
    final result = await _faceDetectionService.analyzeImage(File(imagePath));
    return result.faceVector;
  }

  /// Computes how similar two face vectors are (0.0 = different, 1.0 = identical).
  double computeSimilarity(List<double> ref, List<double> candidate) {
    if (ref.length != candidate.length || ref.isEmpty) return 0.0;
    var sumSq = 0.0;
    for (var i = 0; i < ref.length; i++) {
      final d = ref[i] - candidate[i];
      sumSq += d * d;
    }
    final dist = sqrt(sumSq);
    // Map euclidean distance 0–0.5 → similarity 1.0–0.0
    return (1.0 - (dist / 0.5)).clamp(0.0, 1.0);
  }
}
