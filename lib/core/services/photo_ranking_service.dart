import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, kDebugMode;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

import '../../domain/entities/gallery_image.dart';

// ── Top-level helpers for compute() isolate ──────────────────────────────────

/// Decodes image bytes, resizes to 320 px wide, then computes sharpness,
/// brightness scores, and original image dimensions.
/// Runs in a background isolate via [compute] to avoid blocking the UI thread.
({double sharpness, double brightness, int width, int height})
    _computeImageMetrics(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return (sharpness: 0.5, brightness: 0.5, width: 0, height: 0);
  }
  final thumb = img.copyResize(decoded, width: 320);
  return (
    sharpness: _computeSharpness(thumb),
    brightness: _computeBrightness(thumb),
    width: decoded.width,
    height: decoded.height,
  );
}

double _lumPixel(img.Image image, int x, int y) {
  final pixel = image.getPixel(x, y);
  return 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
}

double _computeSharpness(img.Image thumb) {
  final w = thumb.width;
  final h = thumb.height;
  if (w < 3 || h < 3) return 0.5;
  final responses = <double>[];
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final l = _lumPixel(thumb, x - 1, y);
      final r = _lumPixel(thumb, x + 1, y);
      final u = _lumPixel(thumb, x, y - 1);
      final d = _lumPixel(thumb, x, y + 1);
      final c = _lumPixel(thumb, x, y);
      responses.add((4 * c - l - r - u - d).abs().toDouble());
    }
  }
  if (responses.isEmpty) return 0.5;
  final mean = responses.reduce((a, b) => a + b) / responses.length;
  var variance = 0.0;
  for (final v in responses) {
    variance += (v - mean) * (v - mean);
  }
  variance /= responses.length;
  return sqrt(variance / 4000.0).clamp(0.0, 1.0);
}

double _computeBrightness(img.Image thumb) {
  final w = thumb.width;
  final h = thumb.height;
  if (w == 0 || h == 0) return 0.5;
  double sumLum = 0.0;
  final count = w * h;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      sumLum += _lumPixel(thumb, x, y);
    }
  }
  final meanNorm = (sumLum / count) / 255.0;
  const ideal = 0.55;
  const sigma = 0.20;
  final diff = meanNorm - ideal;
  return exp(-(diff * diff) / (2 * sigma * sigma));
}

/// Composite quality score for a single baby photo.
class PhotoScore {
  const PhotoScore({
    required this.image,
    required this.smileScore,
    required this.sharpnessScore,
    required this.faceSizeScore,
    required this.eyeScore,
    required this.brightnessScore,
    required this.totalScore,
    required this.rank,
  });

  final GalleryImage image;

  /// ML Kit smiling probability (0.0–1.0). 0.5 when unavailable.
  final double smileScore;

  /// Laplacian-variance sharpness (0.0–1.0). Higher = sharper.
  final double sharpnessScore;

  /// Face bounding-box fraction of image area (0.0–1.0, clamped at 0.5 max).
  final double faceSizeScore;

  /// Average eye-openness probability (0.0–1.0). 1.0 if unavailable.
  final double eyeScore;

  /// Perceptual brightness score (0.0–1.0). Best near 0.55 (not too dark/bright).
  final double brightnessScore;

  /// Weighted composite (0.0–1.0).
  final double totalScore;

  /// 1-based rank after sorting by totalScore descending.
  final int rank;

  /// Percentage string for display (e.g. "87%").
  String get totalPct => '${(totalScore * 100).round()}%';
  String get smilePct => '${(smileScore * 100).round()}%';
  String get sharpPct => '${(sharpnessScore * 100).round()}%';
  String get brightPct => '${(brightnessScore * 100).round()}%';
}

/// Analyzes baby photos and returns the top-N ranked by photo quality.
///
/// Scoring weights:
///   sharpness  35 %
///   smile      30 %
///   face size  20 %
///   eye open   15 %
class PhotoRankingService {
  PhotoRankingService()
      : _faceDetector = FaceDetector(
          options: FaceDetectorOptions(
            performanceMode: FaceDetectorMode.fast,
            enableClassification: true,
            enableLandmarks: false,
            minFaceSize: 0.05,
          ),
        );

  final FaceDetector _faceDetector;

  // Scoring weights (must sum to 1.0):
  //   sharpness  30 %
  //   smile      25 %
  //   face size  20 %
  //   eye open   15 %
  //   brightness 10 %
  static const double _wSharpness = 0.30;
  static const double _wSmile = 0.25;
  static const double _wFaceSize = 0.20;
  static const double _wEye = 0.15;
  static const double _wBrightness = 0.10;

  /// In-memory cache: assetId → PhotoScore.
  /// Static so results persist across screen navigations within the same
  /// app session – the user never waits for the same image twice.
  static final Map<String, PhotoScore> _scoreCache = {};

  /// Clears all cached photo scores.
  /// Call when the image library has changed or the user requests a
  /// fresh analysis run.
  static void clearCache() => _scoreCache.clear();

  /// Returns the top [topN] photos sorted by quality score.
  ///
  /// Already-analysed images are served from the static [_scoreCache] so
  /// returning to the screen is instant.
  ///
  /// Uncached images are processed in parallel groups of [batchSize] to keep
  /// throughput high without overwhelming the device.
  ///
  /// [onProgress] is called after every image with (done, total).
  /// [onPartialResults] is called after every batch with the current top-N,
  /// allowing the UI to show live-updating results before analysis finishes.
  Future<List<PhotoScore>> rankTopPhotos(
    List<GalleryImage> images, {
    int topN = 10,
    int batchSize = 6,
    void Function(int done, int total)? onProgress,
    void Function(List<PhotoScore> partial)? onPartialResults,
  }) async {
    final candidates = images.toList();
    if (candidates.isEmpty) return [];

    final total = candidates.length;
    final scored = <PhotoScore>[];
    int done = 0;

    // ── Phase 1: serve cached results immediately ────────────────────────
    final toProcess = <GalleryImage>[];
    for (final image in candidates) {
      final cached = _scoreCache[image.assetId];
      if (cached != null) {
        scored.add(cached);
        done++;
      } else {
        toProcess.add(image);
      }
    }
    if (done > 0) {
      onProgress?.call(done, total);
      onPartialResults?.call(_buildTopN(scored, topN));
    }

    // ── Phase 2: process uncached images in parallel batches ─────────────
    for (var i = 0; i < toProcess.length; i += batchSize) {
      final batch = toProcess.sublist(
        i,
        (i + batchSize).clamp(0, toProcess.length),
      );

      final batchResults = await Future.wait(
        batch.map((image) async {
          try {
            return await _scoreImage(image);
          } catch (e) {
            if (kDebugMode) {
              // ignore: avoid_print
              print('[BestPhotos] Skipped ${image.path}: $e');
            }
            return null;
          }
        }),
      );

      for (final score in batchResults) {
        if (score != null) {
          scored.add(score);
          _scoreCache[score.image.assetId] = score; // persist for next run
        }
      }
      done += batch.length;
      onProgress?.call(done, total);
      onPartialResults?.call(_buildTopN(scored, topN));
    }

    return _buildTopN(scored, topN);
  }

  /// Sorts [scores] descending by totalScore and assigns 1-based ranks.
  List<PhotoScore> _buildTopN(List<PhotoScore> scores, int topN) {
    final sorted = scores.toList()
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));
    final top = sorted.take(topN).toList();
    return List.generate(top.length, (i) {
      final s = top[i];
      return PhotoScore(
        image: s.image,
        smileScore: s.smileScore,
        sharpnessScore: s.sharpnessScore,
        faceSizeScore: s.faceSizeScore,
        eyeScore: s.eyeScore,
        brightnessScore: s.brightnessScore,
        totalScore: s.totalScore,
        rank: i + 1,
      );
    });
  }

  /// Scores a single image file.
  ///
  /// Image decoding and pixel-level computation run in a background isolate
  /// via [compute] so the UI thread is not blocked for large galleries.
  Future<PhotoScore> _scoreImage(GalleryImage galleryImage) async {
    final file = galleryImage.file;

    // ── 1. Decode + compute pixel metrics in background isolate ─────────
    final bytes = await file.readAsBytes();
    final metrics = await compute(_computeImageMetrics, bytes);

    if (kDebugMode && metrics.width == 0) {
      // ignore: avoid_print
      print('[BestPhotos] Could not decode ${galleryImage.path}');
    }

    // ── 2. Face detection for smile + size + eye openness ───────────────
    double smileScore = 0.5;
    double faceSizeScore = 0.3;
    double eyeScore = 1.0;

    try {
      final inputImage = InputImage.fromFile(file);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        // Use the largest face.
        final face = faces.reduce(
          (a, b) =>
              a.boundingBox.width * a.boundingBox.height >=
                      b.boundingBox.width * b.boundingBox.height
                  ? a
                  : b,
        );

        // Smile probability.
        if (face.smilingProbability != null) {
          smileScore = face.smilingProbability!.clamp(0.0, 1.0);
        }

        // Eye openness.
        final left = face.leftEyeOpenProbability;
        final right = face.rightEyeOpenProbability;
        if (left != null && right != null) {
          eyeScore = ((left + right) / 2).clamp(0.0, 1.0);
        } else if (left != null) {
          eyeScore = left.clamp(0.0, 1.0);
        } else if (right != null) {
          eyeScore = right.clamp(0.0, 1.0);
        }

        // Face size relative to image area.
        if (metrics.width > 0 && metrics.height > 0) {
          final imageArea = metrics.width * metrics.height;
          final faceArea = face.boundingBox.width * face.boundingBox.height;
          // Normalize so that 25 % of image area = score 1.0.
          faceSizeScore = (faceArea / imageArea / 0.25).clamp(0.0, 1.0);
        }
      }
    } catch (_) {
      // Face detection failed — use defaults.
    }

    final total = (_wSharpness * metrics.sharpness) +
        (_wSmile * smileScore) +
        (_wFaceSize * faceSizeScore) +
        (_wEye * eyeScore) +
        (_wBrightness * metrics.brightness);

    return PhotoScore(
      image: galleryImage,
      smileScore: smileScore,
      sharpnessScore: metrics.sharpness,
      faceSizeScore: faceSizeScore,
      eyeScore: eyeScore,
      brightnessScore: metrics.brightness,
      totalScore: total.clamp(0.0, 1.0),
      rank: 0, // assigned later
    );
  }

  void close() {
    _faceDetector.close();
  }
}
