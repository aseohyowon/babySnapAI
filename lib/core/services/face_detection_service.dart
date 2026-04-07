import 'dart:io';
import 'dart:math';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:image/image.dart' as img;

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
        _imageLabeler = ImageLabeler(
          options: ImageLabelerOptions(confidenceThreshold: 0.50),
        );

  final FaceDetector _faceDetector;
  // Default ML Kit image labeling model (bundled, no internet required).
  final ImageLabeler _imageLabeler;
  final Map<String, FaceAnalysisResult> _cache = <String, FaceAnalysisResult>{};

  Future<FaceAnalysisResult> analyzeImage(File imageFile) async {
    final cached = _cache[imageFile.path];
    if (cached != null) {
      return cached;
    }

    try {
      final inputImage = InputImage.fromFile(imageFile);

      // Start face detection, image labeling, AND thumbnail decode concurrently.
      // The 480-px thumbnail is reused by both pixel classifiers, so the image
      // bytes are read from disk only once per analyzeImage() call.
      final facesFuture  = _faceDetector.processImage(inputImage);
      final labelsFuture = _imageLabeler.processImage(inputImage);
      final thumbFuture  = _decodeThumb(imageFile);

      final faces  = await facesFuture;
      final labels = await labelsFuture;
      final (:thumb, :sx, :sy) = await thumbFuture;

      _debugLog('▶ ${imageFile.uri.pathSegments.last}: '
          '${faces.length} face(s)  mlkit: '
          '${labels.take(3).map((l) => "${l.label}(${l.confidence.toStringAsFixed(2)})").join(", ")}');

      if (faces.isEmpty) {
        const result = FaceAnalysisResult(
          hasFace: false,
          isBaby: false,
          faceCount: 0,
        );
        _cache[imageFile.path] = result;
        return result;
      }

      // In ultra-strict mode, only accept images with one clear face.
      if (AppConstants.ultraStrictBabyMode && faces.length != 1) {
        const result = FaceAnalysisResult(
          hasFace: true,
          isBaby: false,
          faceCount: 0,
        );
        _cache[imageFile.path] = result;
        return result;
      }

      // Pick the largest face as the primary subject
      final primaryFace = faces.reduce(
        (a, b) =>
            a.boundingBox.width * a.boundingBox.height >=
                    b.boundingBox.width * b.boundingBox.height
                ? a
                : b,
      );

      // ── STEP 0: Image-level classification ───────────────────────────────
      // Classify the whole image before running any face-level analysis.
      // Only real photographs proceed; everything else is rejected immediately.
      final imageType = _classifyImageType(labels, thumb);
      _debugLog('  → image type: ${imageType.name}');
      if (imageType != ImageType.realPhoto) {
        const result = FaceAnalysisResult(
          hasFace: true,
          isBaby: false,
          faceCount: 0,
        );
        _cache[imageFile.path] = result;
        return result;
      }

      // ── STEP 1: Real-photo gate ────────────────────────────────────────────
      // Reject cartoons, watercolors, AI art, and paintings before baby check.
      final realPhotoResult = _classifyRealPhoto(primaryFace, thumb, sx, sy);
      _debugLog('  → real-photo score: ${realPhotoResult.score.toStringAsFixed(1)} '
          '(${realPhotoResult.passed ? "PASS" : "FAIL: ${realPhotoResult.rejectReason}"})');
      if (!realPhotoResult.passed) {
        const result = FaceAnalysisResult(
          hasFace: true,
          isBaby: false,
          faceCount: 0,
        );
        _cache[imageFile.path] = result;
        return result;
      }

      // ── STEP 2: Baby detection ────────────────────────────────────────────
      final babyFaces = faces.where(_isLikelyBabyFace).toList();
      final isBaby = babyFaces.isNotEmpty;
      _debugLog('  → baby faces: ${babyFaces.length}/${faces.length} → ${isBaby ? "IS BABY" : "not baby"}');

      final result = FaceAnalysisResult(
        hasFace: true,
        isBaby: isBaby,
        faceCount: faces.length,
        faceVector: _extractFaceVector(primaryFace),
      );
      _cache[imageFile.path] = result;
      return result;
    } catch (e, st) {
      _debugLog('ANALYSIS ERROR ${imageFile.path}: $e\n$st');
      const result = FaceAnalysisResult(
        hasFace: false,
        isBaby: false,
        faceCount: 0,
      );
      _cache[imageFile.path] = result;
      return result;
    }
  }

  // ignore: avoid_print
  void _debugLog(String msg) {
    if (AppConstants.debugDetection) print('[BabySnap] $msg');
  }

  /// Decodes [file] to a ≤480-px-wide thumbnail and returns it with the
  /// scale factors relative to the original image dimensions.
  /// Returns (thumb: null, sx: 1.0, sy: 1.0) on any error so callers can
  /// treat a null thumb as "skip pixel analysis".
  Future<({img.Image? thumb, double sx, double sy})> _decodeThumb(
      File file) async {
    try {
      final bytes = await file.readAsBytes();
      final full  = img.decodeImage(bytes);
      if (full == null) return (thumb: null, sx: 1.0, sy: 1.0);
      if (full.width <= 480) return (thumb: full, sx: 1.0, sy: 1.0);
      final t = img.copyResize(full, width: 480);
      // full goes out of scope here → eligible for GC immediately.
      return (thumb: t, sx: t.width / full.width, sy: t.height / full.height);
    } catch (_) {
      return (thumb: null, sx: 1.0, sy: 1.0);
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // STEP 0 ─ Image-Level Classifier
  //
  // Two orthogonal signals are combined for the final ImageType verdict:
  //
  //  1. ML Kit image labeling (semantic, pre-trained MobileNet model)
  //     • Run concurrently with face detection in analyzeImage()
  //     • Labels like "Illustration", "Cartoon", "Photography" etc.
  //
  //  2. Pixel heuristics (statistical, runs on a 240-px thumbnail)
  //     • Luminance variance, hyper-saturation, outline density, noise, skin
  //
  // Decision rules:
  //   ML Kit says non-photo with conf ≥ 0.70 → reject immediately
  //   Pixel says non-photo AND ML Kit uncertain → reject
  //   Pixel says non-photo BUT ML Kit says photo (conf ≥ 0.70) → pass
  //   ML Kit says non-photo (conf ≥ 0.55) AND pixel not strongly photo → reject
  //   Everything else → realPhoto (face-level check in STEP 1 will decide)
  // ────────────────────────────────────────────────────────────────────────

  // Non-photo labels from Google's ML Kit image labeling taxonomy.
  static const _nonPhotoLabelSet = {
    'illustration', 'drawing', 'cartoon', 'painting', 'clip art',
    'animated cartoon', 'comics', 'comic book', 'anime', 'manga', 'sketch',
    'watercolor paint', 'acrylic paint', 'visual arts', 'artwork',
    'caricature', 'digital art', 'fine art', 'fictional character',
    'graphic design', 'art', 'poster',
  };

  // Photo-confirming labels.
  static const _photoLabelSet = {
    'photography', 'photograph', 'portrait', 'snapshot', 'selfie',
    'stock photography',
  };

  ImageType _classifyImageType(
      List<ImageLabel> mlkitLabels, img.Image? preThumb) {
    try {
      // ── 1. ML Kit label interpretation

      ImageType? mlkitType;
      double     mlkitConf = 0.0;

      // Non-photo labels take precedence over photo labels.
      for (final label in mlkitLabels) {
        final name = label.label.toLowerCase();
        if (_nonPhotoLabelSet.contains(name) && label.confidence > mlkitConf) {
          mlkitConf = label.confidence;
          mlkitType = (name.contains('cartoon') || name.contains('anime') ||
                       name.contains('comic')   || name.contains('animated'))
              ? ImageType.cartoon
              : ImageType.illustration;
        }
      }
      if (mlkitType == null) {
        for (final label in mlkitLabels) {
          final name = label.label.toLowerCase();
          if (_photoLabelSet.contains(name) && label.confidence > mlkitConf) {
            mlkitConf = label.confidence;
            mlkitType = ImageType.realPhoto;
          }
        }
      }
      _debugLog('  → ML Kit verdict: ${mlkitType?.name ?? "uncertain"} (${mlkitConf.toStringAsFixed(2)})');

      // Strong ML Kit non-photo signal → skip pixel analysis.
      if (mlkitType != null &&
          mlkitType != ImageType.realPhoto &&
          mlkitConf >= 0.70) {
        return mlkitType;
      }

      // ── 2. Pixel-level analysis ──────────────────────────────────────────
      if (preThumb == null) return ImageType.realPhoto;
      // Re-use the pre-decoded 480-px thumbnail; pixel stats are ratio-based
      // so 480 px works just as well as the previous 240-px resize.
      final thumb = preThumb;
      final tw = thumb.width;
      final th = thumb.height;

      // Sample on a grid: target ≈ 800 pixels.
      final totalPixels = tw * th;
      final stride = max(1, (totalPixels / 800).ceil());

      final reds   = <int>[];
      final greens = <int>[];
      final blues  = <int>[];
      var outlinePairs = 0;
      var outlineHits  = 0;
      var adjDiffTotal = 0.0;
      var adjCount     = 0;

      for (var py = 0; py < th; py += stride) {
        for (var px = 0; px < tw; px += stride) {
          final pixel = thumb.getPixel(px, py);
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();
          reds.add(r);
          greens.add(g);
          blues.add(b);

          final lum = r * 0.299 + g * 0.587 + b * 0.114;
          if (px + 1 < tw) {
            final np   = thumb.getPixel(px + 1, py);
            final nlum = np.r.toInt() * 0.299
                       + np.g.toInt() * 0.587
                       + np.b.toInt() * 0.114;
            final diff = (lum - nlum).abs();
            adjDiffTotal += diff;
            adjCount++;
            if (diff > 70 && min(lum, nlum) < 80) outlineHits++;
            outlinePairs++;
          }
        }
      }

      final n = reds.length;
      if (n < 30) return ImageType.realPhoto; // too few samples

      // ── Luminance distribution ─────────────────────────────────────────
      final lums = List<double>.generate(
        n, (i) => reds[i] * 0.299 + greens[i] * 0.587 + blues[i] * 0.114);
      final meanLum = lums.reduce((a, b) => a + b) / n;
      final lumVariance = lums
          .map((l) => (l - meanLum) * (l - meanLum))
          .reduce((a, b) => a + b) / n;

      // ── Gate 1: Solid color ───────────────────────────────────────────
      // If luminance variance is tiny AND color buckets are dominated by one
      // hue, this is a plain solid-color image.
      if (lumVariance < 120.0) {
        // Check color uniformity via coarse 5-bit buckets.
        final colorBuckets = <int, int>{};
        for (var i = 0; i < n; i++) {
          final key = (reds[i] >> 3) * 1024 + (greens[i] >> 3) * 32 + (blues[i] >> 3);
          colorBuckets[key] = (colorBuckets[key] ?? 0) + 1;
        }
        final topShare = (colorBuckets.values.toList()
              ..sort((a, b) => b.compareTo(a)))
            .first / n;
        if (topShare > 0.75) {
          _debugLog('  → solidColor: lumVar=${lumVariance.toStringAsFixed(1)} topShare=${topShare.toStringAsFixed(2)}');
          return ImageType.solidColor;
        }
      }

      // ── Gate 2: Silhouette ────────────────────────────────────────────
      // Bimodal luminance: mostly very dark + very bright, ≤15 % midtones.
      var darkCount  = 0; // lum < 40
      var brightCount = 0; // lum > 215
      var midCount   = 0; // 40 ≤ lum ≤ 215
      for (final l in lums) {
        if (l < 40) darkCount++;
        else if (l > 215) brightCount++;
        else midCount++;
      }
      final midRatio = midCount / n;
      final extremeRatio = (darkCount + brightCount) / n;
      if (extremeRatio > 0.80 && midRatio < 0.15) {
        _debugLog('  → silhouette: extreme=${extremeRatio.toStringAsFixed(2)} mid=${midRatio.toStringAsFixed(2)}');
        return ImageType.silhouette;
      }

      // ── Per-pixel noise (sensor noise signal) ─────────────────────────
      final meanAbsDiff = adjCount > 0 ? adjDiffTotal / adjCount : 8.0;

      // ── Outline ratio (cartoon hard contours) ─────────────────────────
      final outlineRatio = outlinePairs > 10 ? outlineHits / outlinePairs : 0.0;

      // ── Hyper-saturation ratio (cartoon / anime) ──────────────────────
      var hyperSatCount = 0;
      for (var i = 0; i < n; i++) {
        final maxC = max(max(reds[i], greens[i]), blues[i]);
        final minC = min(min(reds[i], greens[i]), blues[i]);
        if (maxC > 30) {
          final sat = (maxC - minC) / maxC;
          if (sat > 0.72) hyperSatCount++;
        }
      }
      final hyperSatRatio = hyperSatCount / n;

      // ── Skin-tone presence ────────────────────────────────────────────
      var skinCount = 0;
      for (var i = 0; i < n; i++) {
        if (_isSkinPixel(reds[i], greens[i], blues[i])) skinCount++;
      }
      final skinRatio = skinCount / n;

      // ── Color bucket diversity ────────────────────────────────────────
      final fineBuckets = <int, int>{};
      for (var i = 0; i < n; i++) {
        final key = (reds[i] >> 3) * 1024 + (greens[i] >> 3) * 32 + (blues[i] >> 3);
        fineBuckets[key] = (fineBuckets[key] ?? 0) + 1;
      }
      final sortedBuckets = fineBuckets.values.toList()..sort((a, b) => b.compareTo(a));
      final top3Share = sortedBuckets.take(3).fold(0, (s, c) => s + c) / n;

      // ── Gate 3: Cartoon ───────────────────────────────────────────────
      // High saturation + hard outlines + low noise + flat color areas.
      if (hyperSatRatio > 0.35 && outlineRatio > 0.06 && meanAbsDiff < 10.0) {
        _debugLog('  → cartoon: sat=${hyperSatRatio.toStringAsFixed(2)} outline=${outlineRatio.toStringAsFixed(3)} noise=${meanAbsDiff.toStringAsFixed(1)}');
        return ImageType.cartoon;
      }

      // ── Gate 4: Illustration ─────────────────────────────────────────
      // Low noise, low texture variance, few skin tones, flat large regions.
      // Covers watercolor, digital painting, manga, sketch.
      if (meanAbsDiff < 6.5 && lumVariance < 900.0 &&
          skinRatio < 0.06 && top3Share > 0.45) {
        _debugLog('  → illustration: noise=${meanAbsDiff.toStringAsFixed(1)} lumVar=${lumVariance.toStringAsFixed(1)} skin=${skinRatio.toStringAsFixed(2)} top3=${top3Share.toStringAsFixed(2)}');
        return ImageType.illustration;
      }

      // ── Soft scoring: real photo vs non-photo ────────────────────────
      // Real photographs score high here; ambiguous edge cases are passed
      // through to let the face-level classifier (_classifyRealPhoto) decide.
      var photoScore = 0;
      if (skinRatio >= 0.04) photoScore++;          // has flesh tones
      if (meanAbsDiff >= 7.0) photoScore++;          // has sensor noise
      if (lumVariance >= 300.0) photoScore++;        // has tonal depth
      if (top3Share < 0.45) photoScore++;            // color diversity
      if (outlineRatio < 0.05) photoScore++;         // no hard outlines
      if (hyperSatRatio < 0.25) photoScore++;        // no hyper saturation

      _debugLog('  → pixel score=$photoScore/6 '
          'noise=${meanAbsDiff.toStringAsFixed(1)} '
          'lumVar=${lumVariance.toStringAsFixed(1)} '
          'skin=${skinRatio.toStringAsFixed(2)} '
          'top3=${top3Share.toStringAsFixed(2)}');

      // ── 3. Combine ML Kit + pixel signals ────────────────────────────────
      final pixelNonPhoto = photoScore <= 2;
      final mlkitNonPhoto = mlkitType != null && mlkitType != ImageType.realPhoto;
      final mlkitIsPhoto  = mlkitType == ImageType.realPhoto && mlkitConf >= 0.70;

      if (pixelNonPhoto) {
        if (mlkitIsPhoto) {
          // Pixel says non-photo, but ML Kit is confident it's a real photo.
          // Trust the semantic model — let face-level check (STEP 1) decide.
          _debugLog('  → pixel=non-photo overridden by ML Kit realPhoto conf=${mlkitConf.toStringAsFixed(2)}');
          return ImageType.realPhoto;
        }
        _debugLog('  → REJECT(pixel): photoScore=$photoScore mlkit=${mlkitType?.name ?? "uncertain"}');
        return mlkitType ?? ImageType.illustration;
      }

      if (mlkitNonPhoto && mlkitConf >= 0.55 && photoScore <= 4) {
        // ML Kit moderately says non-photo and pixel is not strongly photographic.
        _debugLog('  → REJECT(mlkit): ${mlkitType.name} conf=${mlkitConf.toStringAsFixed(2)} photoScore=$photoScore');
        return mlkitType;
      }

      return ImageType.realPhoto;
    } catch (_) {
      return ImageType.realPhoto; // never reject on error
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // STEP 1 ─ Real-Photo Classifier
  // Uses 4 independent pixel-level signals combined into a weighted score
  // (0–100).  Images scoring below [AppConstants.realPhotoMinScore] are
  // classified as non-photographic (cartoon / watercolor / AI art / painting)
  // and excluded from results.
  // ────────────────────────────────────────────────────────────────────────

  /// Returns true when [imageFile] is likely a real photograph.
  _RealPhotoResult _classifyRealPhoto(
      Face primaryFace, img.Image? thumb, double sx, double sy) {
    try {
      if (thumb == null) return _RealPhotoResult(true, 100.0, null);
      // Use the pre-decoded thumbnail; scaleX/Y already computed by _decodeThumb.
      final small  = thumb;
      final scaleX = sx;
      final scaleY = sy;

      // Use the inner 80 % of the face box to avoid background contamination.
      final box = primaryFace.boundingBox;
      const pad = 0.10;
      final x0 = ((box.left + box.width * pad) * scaleX)
          .round()
          .clamp(0, small.width - 1);
      final y0 = ((box.top + box.height * pad) * scaleY)
          .round()
          .clamp(0, small.height - 1);
      final x1 = ((box.right - box.width * pad) * scaleX)
          .round()
          .clamp(0, small.width - 1);
      final y1 = ((box.bottom - box.height * pad) * scaleY)
          .round()
          .clamp(0, small.height - 1);

      if (x1 - x0 < 12 || y1 - y0 < 12) return _RealPhotoResult(true, 100.0, null); // face too small to judge

      // Adaptive stride so we sample ~500 pixels regardless of face size.
      final regionPixels = (x1 - x0) * (y1 - y0);
      final stride = max(1, regionPixels ~/ 500);

      final reds = <int>[];
      final greens = <int>[];
      final blues = <int>[];

      // Signal 5 ─ outline detection (large dark/bright transitions)
      // Signal 6 ─ photographic noise (mean absolute luminance diff between
      //            truly-adjacent pixels).  Real camera photos always have
      //            fine-grained sensor noise (diff ≈ 8–25).  Watercolor, digital
      //            art and cartoons have smooth regions (diff ≈ 1–8).
      var outlinePairs = 0;
      var outlineHits = 0;
      var adjDiffTotal = 0.0;
      var adjCount = 0;

      for (var py = y0; py < y1; py += stride) {
        for (var px = x0; px < x1; px += stride) {
          final pixel = small.getPixel(px, py);
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();
          reds.add(r);
          greens.add(g);
          blues.add(b);

          final lum = r * 0.299 + g * 0.587 + b * 0.114;

          // Compare with the truly-adjacent right neighbour (NOT strided).
          if (px + 1 < x1) {
            final np = small.getPixel(px + 1, py);
            final nlum = np.r.toInt() * 0.299
                       + np.g.toInt() * 0.587
                       + np.b.toInt() * 0.114;
            final diff = (lum - nlum).abs();
            adjDiffTotal += diff;
            adjCount++;
            // Outline hit: large jump where one side is near-black.
            if (diff > 70 && min(lum, nlum) < 80) outlineHits++;
            outlinePairs++;
          }
        }
      }

      final n = reds.length;
      if (n < 20) return _RealPhotoResult(true, 100.0, null); // too few samples → don't reject

      final meanAbsDiff = adjCount > 0 ? adjDiffTotal / adjCount : 8.0;

      // ── Hard Gate A: minimum skin presence ─────────────────────────────
      // Any real-photo face region must contain at least 3 % skin-toned pixels.
      var skinCount = 0;
      for (var i = 0; i < n; i++) {
        if (_isSkinPixel(reds[i], greens[i], blues[i])) skinCount++;
      }
      final skinRatio = skinCount / n;
      if (skinRatio < 0.03) return _RealPhotoResult(false, 0.0, 'no_skin');

      // ── (Gate B removed) ─────────────────────────────────────────────────
      // Previous variance<90 gate rejected real baby photos soft-lit in
      // studio settings.  Replaced by the composite score & Gate D below.

      // ── Grayscale variance (needed for Gate D and Signal 3) ─────────────
      final grays = List<double>.generate(
        n,
        (i) => reds[i] * 0.299 + greens[i] * 0.587 + blues[i] * 0.114,
      );
      final meanG = grays.reduce((a, b) => a + b) / n;
      final variance = grays
              .map((g) => (g - meanG) * (g - meanG))
              .reduce((a, b) => a + b) /
          n;

      // ── Hard Gate C: flat-color domination ──────────────────────────────
      // A single color bucket covering > 70 % of the face region indicates a
      // cartoon flat-fill.  (Relaxed from 55 % which over-rejected real
      // close-up baby photos where skin can be dominant.)
      final bucketsC = <int, int>{};
      for (var i = 0; i < n; i++) {
        final key =
            (reds[i] >> 3) * 1024 + (greens[i] >> 3) * 32 + (blues[i] >> 3);
        bucketsC[key] = (bucketsC[key] ?? 0) + 1;
      }
      final sortedC = bucketsC.values.toList()..sort((a, b) => b.compareTo(a));
      final top1Share = sortedC.first / n;
      if (top1Share > 0.70) return _RealPhotoResult(false, 0.0, 'flat_color');

      // ── Hard Gate D: smooth + noiseless = watercolor / painting ─────────
      // Real camera photos always have EITHER appreciable texture variance
      // (detail, pores) OR fine-grained sensor noise (meanAbsDiff > 8).
      // A face region that is simultaneously smooth in variance AND quiet in
      // per-pixel noise is almost certainly a painted / drawn surface.
      if (variance < 300.0 && meanAbsDiff < 8.0) return _RealPhotoResult(false, 0.0, 'smooth_noiseless');

      // ── Signal 1: Skin-tone ratio (weight 22) ───────────────────────────
      // Real baby photos have ≥15 % of face pixels in a plausible skin range.
      final skinScore = (skinRatio / 0.15).clamp(0.0, 1.0);

      // ── Signal 2: Color diversity / anti-flat-color (weight 18) ─────────
      // Cartoon fills and watercolor washes dominate a few large color buckets.
      // (Reuse sortedC from Gate C.)
      final top3Share = sortedC.take(3).fold(0, (s, c) => s + c) / n;
      // Real photo top-3 ≤ 20–25 %; cartoon/drawing often > 55 %.
      final diversityScore =
          (1.0 - ((top3Share - 0.15) / 0.40).clamp(0.0, 1.0));

      // ── Signal 3: Texture variance (weight 15) ───────────────────────────
      // variance already computed above for Gate D.
      // Score: 0 at variance≤150, 1.0 at variance≥1200.
      final textureScore = ((variance - 150.0) / 1050.0).clamp(0.0, 1.0);

      // ── Signal 4: Anti-hyper-saturation (weight 8) ──────────────────────
      // Cartoon / anime art uses vivid, heavily saturated hues.
      var hyperSatCount = 0;
      for (var i = 0; i < n; i++) {
        final maxC = max(max(reds[i], greens[i]), blues[i]);
        final minC = min(min(reds[i], greens[i]), blues[i]);
        if (maxC > 30) {
          final sat = (maxC - minC) / maxC;
          if (sat > 0.78) hyperSatCount++;
        }
      }
      final hyperSatRatio = hyperSatCount / n;
      final satScore =
          (1.0 - ((hyperSatRatio - 0.10) / 0.40).clamp(0.0, 1.0));

      // ── Signal 5: Anti-cartoon-outline (weight 15) ──────────────────────
      // Hard dark↔bright transitions at contours indicate cartoon/drawing.
      double outlineScore = 1.0;
      if (outlinePairs > 10) {
        final outlineRatio = outlineHits / outlinePairs;
        outlineScore =
            (1.0 - ((outlineRatio - 0.08) / 0.22).clamp(0.0, 1.0));
      }

      // ── Signal 6: Photographic noise / fine-grain (weight 22) ───────────
      // Real camera photos always carry fine-grained sensor noise visible at
      // the single-pixel level (meanAbsDiff ≈ 8–25).
      // Watercolor paintings and digital illustrations are smooth between
      // brush-strokes / fills: meanAbsDiff ≈ 2–7.
      // Score: 0 at diff≤3, 1.0 at diff≥13.
      final noiseScore = ((meanAbsDiff - 3.0) / 10.0).clamp(0.0, 1.0);

      // ── Composite score (0–100) ──────────────────────────────────────────
      // Weights: 22 + 18 + 15 + 8 + 15 + 22 = 100
      final composite = skinScore      * 22.0
                      + diversityScore  * 18.0
                      + textureScore    * 15.0
                      + satScore        *  8.0
                      + outlineScore    * 15.0
                      + noiseScore      * 22.0;

      final passed = composite >= AppConstants.realPhotoMinScore;
      return _RealPhotoResult(passed, composite, passed ? null : 'low_score');
    } catch (_) {
      return _RealPhotoResult(true, 100.0, null); // never reject on decode/analysis error
    }
  }

  /// Returns true if [r],[g],[b] are within a plausible human skin-tone range.
  /// Two independent rules to handle varied lighting and ethnicities.
  bool _isSkinPixel(int r, int g, int b) {
    // Rule 1 — absolute RGB skin model (Peer et al.)
    if (r > 95 && g > 40 && b > 20 &&
        (r - b).abs() > 15 &&
        r > g &&
        r > b &&
        (r - g).abs() > 10) {
      return true;
    }
    // Rule 2 — normalised RGB (robust to over/under-exposure)
    final sum = r + g + b;
    if (sum == 0) return false;
    final rn = r / sum;
    final gn = g / sum;
    if (rn >= 0.36 && gn >= 0.28 && rn - gn >= 0.02 && rn <= 0.72) {
      return true;
    }
    return false;
  }

  // ────────────────────────────────────────────────────────────────────────
  // STEP 2 ─ Baby-Face Classifier
  //   Goals:
  //    • Detect small faces (distant / group shots)  — min width 55 px
  //    • Allow partial visibility (eyes + nose minimum)
  //    • Accept tilted faces
  //    • Reject adult faces via proportional geometry
  //    • Log every decision when debugDetection = true
  // ────────────────────────────────────────────────────────────────────────

  bool _isLikelyBabyFace(Face face) {
    final w = face.boundingBox.width;
    final h = face.boundingBox.height;

    // Gate 1: absolute minimum size (very permissive for distant shots)
    if (w < 55 || h < 55) {
      _debugLog('    face SKIP: too small (${w.toInt()}x${h.toInt()})');
      return false;
    }

    // Gate 2: must not be a large adult face
    if (w > AppConstants.babyFaceWidthThreshold) {
      _debugLog('    face SKIP: too wide (${w.toInt()})');
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
    if (lep == null || rep == null) {
      _debugLog('    face SKIP: null eye probs');
      return false;
    }
    // Reject only when BOTH eyes are at hard extremes
    if ((lep < 0.02 || lep > 0.99) && (rep < 0.02 || rep > 0.99)) {
      _debugLog('    face SKIP: extreme eye probs ($lep/$rep)');
      return false;
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
    _faceDetector.close();
    _imageLabeler.close();
  }
}

// Image-level classification result.
enum ImageType {
  /// Camera photograph — real scene captured by a sensor.
  realPhoto,

  /// Flat-filled cartoon / anime / vector art with hard outlines.
  cartoon,

  /// Painterly / digital illustration / watercolor / manga.
  illustration,

  /// Near-uniform background or plain solid-fill image.
  solidColor,

  /// High-contrast dark silhouette against a bright background (or vice versa).
  silhouette,
}

// Private helper — result of real-photo classification.
class _RealPhotoResult {
  const _RealPhotoResult(this.passed, this.score, this.rejectReason);
  final bool passed;
  final double score;
  final String? rejectReason;
}
