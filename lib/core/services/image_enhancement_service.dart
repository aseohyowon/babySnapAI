import 'dart:io';
import 'dart:isolate';

import 'package:image/image.dart' as img;

import 'export_service.dart';

/// Enhancement parameters — all values are normalised 0.0–1.0 where 0.5 is
/// "no change" unless stated otherwise.
class EnhancementParams {
  const EnhancementParams({
    this.brightness = 0.0,
    this.contrast = 0.0,
    this.sharpness = 0.5,
  });

  /// -1.0 (very dark) … 0.0 (original) … +1.0 (very bright).
  final double brightness;

  /// -1.0 (flat) … 0.0 (original) … +1.0 (high contrast).
  final double contrast;

  /// 0.0 (none) … 0.5 (medium) … 1.0 (maximum).
  final double sharpness;

  EnhancementParams copyWith({
    double? brightness,
    double? contrast,
    double? sharpness,
  }) =>
      EnhancementParams(
        brightness: brightness ?? this.brightness,
        contrast: contrast ?? this.contrast,
        sharpness: sharpness ?? this.sharpness,
      );

  @override
  bool operator ==(Object other) =>
      other is EnhancementParams &&
      other.brightness == brightness &&
      other.contrast == contrast &&
      other.sharpness == sharpness;

  @override
  int get hashCode => Object.hash(brightness, contrast, sharpness);
}

// ── Isolate message types ──────────────────────────────────────────────────

class _EnhanceRequest {
  const _EnhanceRequest({
    required this.sourcePath,
    required this.params,
    required this.sendPort,
  });
  final String sourcePath;
  final EnhancementParams params;
  final SendPort sendPort;
}

// ── Background processing function (top-level so it can be spawned) ──────────

void _enhanceInBackground(_EnhanceRequest request) {
  try {
    final bytes = File(request.sourcePath).readAsBytesSync();
    var image = img.decodeImage(bytes);
    if (image == null) {
      request.sendPort.send(null);
      return;
    }

    final p = request.params;

    // ── Brightness ─────────────────────────────────────────────────────────
    if (p.brightness != 0.0) {
      image = img.adjustColor(image, brightness: 1.0 + p.brightness);
    }

    // ── Contrast ───────────────────────────────────────────────────────────
    if (p.contrast != 0.0) {
      // contrast > 1 increases, < 1 decreases. Map -1..1 → 0.2..2.0
      final contrastMul = 1.0 + p.contrast;
      image = img.adjustColor(image, contrast: contrastMul.clamp(0.2, 2.0));
    }

    // ── Sharpness (convolution kernel) ─────────────────────────────────────
    if (p.sharpness > 0.05) {
      // Scale kernel strength linearly.  At 1.0 sharpness we use strength 8.
      final strength = (p.sharpness * 8.0).clamp(0.0, 8.0);
      final w = strength.round();
      image = img.convolution(
        image,
        filter: [
          0,           -w,       0,
          -w,  (4 * w) + 1, -w,
          0,           -w,       0,
        ],
        div: 1,
        offset: 0,
      );
    }

    request.sendPort.send(img.encodeJpg(image, quality: 95));
  } catch (_) {
    request.sendPort.send(null);
  }
}

// ── Service ────────────────────────────────────────────────────────────────

class ImageEnhancementService {
  final ExportService _exportService = ExportService();

  /// Enhances [sourcePath] with [params] and writes the result to a temp file.
  ///
  /// Processing runs on a separate isolate to avoid freezing the UI.
  /// Returns the path of the enhanced JPEG file, or null on failure.
  Future<String?> enhanceImage(
    String sourcePath,
    EnhancementParams params,
  ) async {
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(
      _enhanceInBackground,
      _EnhanceRequest(
        sourcePath: sourcePath,
        params: params,
        sendPort: receivePort.sendPort,
      ),
    );

    final result = await receivePort.first;
    receivePort.close();
    isolate.kill(priority: Isolate.immediate);

    if (result == null) return null;

    // Write to temp file.
    final tempDir = Directory.systemTemp;
    final ext = sourcePath.contains('.')
        ? sourcePath.substring(sourcePath.lastIndexOf('.'))
        : '.jpg';
    final outName =
        'enhanced_${DateTime.now().millisecondsSinceEpoch}$ext';
    final outPath = '${tempDir.path}/$outName';
    await File(outPath).writeAsBytes(result as List<int>);
    return outPath;
  }

  /// Saves the file at [enhancedPath] to the device gallery album
  /// "Pictures/BabySnap AI Enhanced".
  Future<bool> saveEnhancedImage(String enhancedPath) async {
    final count = await _exportService.exportImages([enhancedPath]);
    return count > 0;
  }
}
