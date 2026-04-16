import 'dart:io';
import 'dart:math';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../constants/app_constants.dart';
import '../models/face_analysis_result.dart';

class FaceDetectionService {
  FaceDetectionService()
      : _faceDetector = FaceDetector(
          options: FaceDetectorOptions(
            performanceMode: FaceDetectorMode.accurate,
            enableLandmarks: true,
            enableClassification: true,
            minFaceSize: 0.08,
          ),
        ),
        _quickFaceDetector = FaceDetector(
          options: FaceDetectorOptions(
            performanceMode: FaceDetectorMode.fast,
            enableLandmarks: true,
            enableClassification: false,
            minFaceSize: 0.10,
          ),
        );

  final FaceDetector _faceDetector;
  final FaceDetector _quickFaceDetector;

  Future<FaceAnalysisResult> analyzeImage(
    File imageFile, {
    bool quickMode = false,
    /// Scale factor = thumbnail_size / max(original_width, original_height).
    /// Pass this so face bounding-box coordinates (in thumbnail pixel space)
    /// can be converted back to full-resolution pixel space before comparing
    /// against thresholds that were calibrated on full-res images.
    double imageScale = 1.0,
  }) async {
    // NOTE: No in-memory cache here. All thumbnails now share the same
    // temp file path (babyscan_thumb.jpg), so a path-based cache would
    // return the first image's result for every subsequent image.
    // Persistent caching is handled by GalleryCacheService instead.
    try {
      final inputImage = InputImage.fromFile(imageFile);

      if (quickMode) {
        final faces = await _quickFaceDetector.processImage(inputImage);
        if (faces.isEmpty) {
          return const FaceAnalysisResult(
            hasFace: false,
            isBaby: false,
            faceCount: 0,
          );
        }

        if (AppConstants.ultraStrictBabyMode && faces.length != 1) {
          return const FaceAnalysisResult(
            hasFace: true,
            isBaby: false,
            faceCount: 0,
          );
        }

        final babyFaces = faces
          .where((face) => _isLikelyBabyFace(face, strictEyeProbGate: false, imageScale: imageScale))
          .toList();
        return FaceAnalysisResult(
          hasFace: true,
          isBaby: babyFaces.isNotEmpty,
          faceCount: faces.length,
          faceVector: null,
        );
      }

      final faces = await _faceDetector.processImage(inputImage);

      _debugLog('▶ ${imageFile.uri.pathSegments.last}: ${faces.length} face(s)');

      if (faces.isEmpty) {
        return const FaceAnalysisResult(
          hasFace: false,
          isBaby: false,
          faceCount: 0,
        );
      }

      if (AppConstants.ultraStrictBabyMode && faces.length != 1) {
        return const FaceAnalysisResult(
          hasFace: true,
          isBaby: false,
          faceCount: 0,
        );
      }

      final primaryFace = faces.reduce(
        (a, b) =>
            a.boundingBox.width * a.boundingBox.height >=
                    b.boundingBox.width * b.boundingBox.height
                ? a
                : b,
      );

      final babyFaces = faces.where((f) => _isLikelyBabyFace(f, imageScale: imageScale)).toList();
      final isBaby = babyFaces.isNotEmpty;
      _debugLog('  → baby faces: ${babyFaces.length}/${faces.length} → ${isBaby ? "IS BABY" : "not baby"}');

      return FaceAnalysisResult(
        hasFace: true,
        isBaby: isBaby,
        faceCount: faces.length,
        faceVector: _extractFaceVector(primaryFace),
      );
    } catch (e, st) {
      _debugLog('ANALYSIS ERROR ${imageFile.path}: $e\n$st');
      return const FaceAnalysisResult(
        hasFace: false,
        isBaby: false,
        faceCount: 0,
      );
    }
  }

  // ignore: avoid_print
  void _debugLog(String msg) {
    if (AppConstants.debugDetection) print('[BabySnap] $msg');
  }

  bool _isLikelyBabyFace(
    Face face, {
    bool strictEyeProbGate = true,
    /// Scale factor = thumbnail_size / max(original_width, original_height).
    /// Converts thumbnail-space bounding-box dimensions back to full-resolution
    /// pixel space before comparing against thresholds calibrated on full-res.
    double imageScale = 1.0,
  }) {
    // Thresholds are calibrated for the 512-px thumbnail coordinate space.
    // ML Kit runs on the 512-px thumbnail, so use bounding-box dimensions
    // directly without any scale conversion.
    final w = face.boundingBox.width;
    final h = face.boundingBox.height;

    // Gate 1: absolute minimum size.
    // Calibrated for 256-px thumbnails: 35 px ≈ same real-world coverage
    // as 55 px was at 384 px (35 ≈ 55 × 256/384).
    if (w < 35 || h < 35) {
      _debugLog('    face SKIP: too small full-res=(${w.toInt()}x${h.toInt()})');
      return false;
    }

    // Gate 2: must not be a large adult face
    if (w > AppConstants.babyFaceWidthThreshold) {
      _debugLog('    face SKIP: too wide full-res=(${w.toInt()})');
      return false;
    }

    // Gate 3: aspect ratio sanity
    final aspectRatio = w / h;
    if (aspectRatio < 0.5 || aspectRatio > 2.0) {
      _debugLog('    face SKIP: bad aspect $aspectRatio');
      return false;
    }

    // Gate 4: require eyes + nose at minimum
    final leftEye  = face.landmarks[FaceLandmarkType.leftEye]?.position;
    final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;
    final nose     = face.landmarks[FaceLandmarkType.noseBase]?.position;
    final mouth    = face.landmarks[FaceLandmarkType.bottomMouth]?.position;

    if (leftEye == null || rightEye == null || nose == null) {
      _debugLog('    face SKIP: missing eyes/nose');
      return false;
    }

    // Gate 5: nose must be below eye midpoint (basic anatomy)
    final eyeMidY = (leftEye.y + rightEye.y) / 2.0;
    if (nose.y.toDouble() <= eyeMidY + h * 0.03) {
      _debugLog('    face SKIP: nose above eyes → drawing');
      return false;
    }

    // Gate 6: eye-open probabilities must be non-extreme
    // Drawings: ML Kit returns null, 0.0, or 1.0
    final lep = face.leftEyeOpenProbability;
    final rep = face.rightEyeOpenProbability;
    if (strictEyeProbGate) {
      if (lep == null || rep == null) {
        _debugLog('    face SKIP: null eye probs');
        return false;
      }
      // Reject only when BOTH eyes are at hard extremes
      if ((lep < 0.02 || lep > 0.99) && (rep < 0.02 || rep > 0.99)) {
        _debugLog('    face SKIP: extreme eye probs ($lep/$rep)');
        return false;
      }
    }

    // Soft scoring — need ≥3 out of max 7
    var score = 0;
    final reasons = <String>[];

    // S1: area in baby range
    final area = w * h;
    if (area >= AppConstants.babyFaceMinAreaThreshold &&
        area <= AppConstants.babyFaceAreaThreshold) {
      score++; reasons.add('area✓');
    }

    // S2: width in baby range
    if (w >= AppConstants.babyFaceMinWidthThreshold &&
        w <= AppConstants.babyFaceWidthThreshold) {
      score++; reasons.add('w✓');
    }

    // S3: near-square aspect ratio (babies have rounder heads)
    if (aspectRatio >= AppConstants.babyFaceMinAspectRatio &&
        aspectRatio <= AppConstants.babyFaceMaxAspectRatio) {
      score++; reasons.add('ar✓');
    }

    // S4: eye distance normalized by width (0.15–0.60 covers babies)
    final eyeDist = _distance(
      leftEye.x.toDouble(), leftEye.y.toDouble(),
      rightEye.x.toDouble(), rightEye.y.toDouble());
    final normED = eyeDist / w;
    if (normED >= 0.15 && normED <= 0.60) {
      score++; reasons.add('ed✓');
    }

    // S5: eye-to-nose distance normalized by height (0.06–0.40)
    final eyeMidX = (leftEye.x + rightEye.x) / 2.0;
    final eyeToNose = _distance(eyeMidX, eyeMidY,
        nose.x.toDouble(), nose.y.toDouble());
    final normEN = eyeToNose / h;
    if (normEN >= 0.06 && normEN <= 0.40) {
      score++; reasons.add('en✓');
    }

    // S6: smiling probability available (drawings: always null)
    if (face.smilingProbability != null) {
      score++; reasons.add('smile✓');
    }

    // S7: mouth below nose
    if (mouth != null && mouth.y.toDouble() > nose.y.toDouble()) {
      score++; reasons.add('mouth✓');
    }

    const minScore = 3;
    final pass = score >= minScore;
    _debugLog('    face ${pass ? "ACCEPT" : "SKIP"}: '
        'score=$score/7 (${reasons.join(",")}) '
        '${w.toInt()}x${h.toInt()}');
    return pass;
  }

  /// Extracts a normalized 5-dimensional geometric face vector for identity matching.
  /// Components: [eyeDist/w, eyeToNose/h, noseToMouth/h, (w/h)/2, eyeMidY/h]
  List<double>? _extractFaceVector(Face face) {
    final leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
    final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;
    final nose = face.landmarks[FaceLandmarkType.noseBase]?.position;
    final mouth = face.landmarks[FaceLandmarkType.bottomMouth]?.position;

    if (leftEye == null || rightEye == null || nose == null || mouth == null) {
      return null;
    }

    final w = face.boundingBox.width;
    final h = face.boundingBox.height;
    if (w <= 0 || h <= 0) return null;

    final eyeDist = _distance(
      leftEye.x.toDouble(), leftEye.y.toDouble(),
      rightEye.x.toDouble(), rightEye.y.toDouble(),
    );
    final eyeMidX = (leftEye.x + rightEye.x) / 2.0;
    final eyeMidY = (leftEye.y + rightEye.y) / 2.0;
    final eyeToNose = _distance(eyeMidX, eyeMidY, nose.x.toDouble(), nose.y.toDouble());
    final noseToMouth = _distance(
      nose.x.toDouble(), nose.y.toDouble(),
      mouth.x.toDouble(), mouth.y.toDouble(),
    );

    return [
      (eyeDist / w).clamp(0.0, 1.0),
      (eyeToNose / h).clamp(0.0, 1.0),
      (noseToMouth / h).clamp(0.0, 1.0),
      ((w / h) / 2.0).clamp(0.0, 1.0),
      ((eyeMidY - face.boundingBox.top) / h).clamp(0.0, 1.0),
    ];
  }

  /// Computes similarity between two face vectors (0.0 = different, 1.0 = identical).
  double computeSimilarity(List<double> ref, List<double> candidate) {
    if (ref.length != candidate.length || ref.isEmpty) return 0.0;
    var sumSq = 0.0;
    for (var i = 0; i < ref.length; i++) {
      final d = ref[i] - candidate[i];
      sumSq += d * d;
    }
    final dist = sqrt(sumSq);
    return (1.0 - (dist / 0.5)).clamp(0.0, 1.0);
  }

  double _distance(double x1, double y1, double x2, double y2) {
    final dx = x1 - x2;
    final dy = y1 - y2;
    return sqrt((dx * dx) + (dy * dy));
  }

  void close() {
    _quickFaceDetector.close();
    _faceDetector.close();
  }
}

