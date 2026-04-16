import 'dart:io';

import '../../core/constants/app_constants.dart';
import '../../core/models/face_analysis_result.dart';
import '../../core/services/gallery_cache_service.dart';
import '../../core/services/face_detection_service.dart';
import '../../domain/entities/gallery_image.dart';
import '../../domain/entities/gallery_scan_progress.dart';
import '../../domain/repositories/image_repository.dart';
import '../datasources/device_gallery_data_source.dart';
import '../models/cached_scan_record_model.dart';
import '../models/gallery_asset_meta.dart';

class ImageRepositoryImpl implements ImageRepository {
  ImageRepositoryImpl({
    required DeviceGalleryDataSource dataSource,
    required FaceDetectionService faceDetectionService,
    required GalleryCacheService cacheService,
  })  : _dataSource = dataSource,
        _faceDetectionService = faceDetectionService,
        _cacheService = cacheService;

  final DeviceGalleryDataSource _dataSource;
  final FaceDetectionService _faceDetectionService;
  final GalleryCacheService _cacheService;
  Set<String>? _excludedAssetIds;
  bool _isPremium = false;

  @override
  void setPremium(bool isPremium) {
    _isPremium = isPremium;
  }

  @override
  Future<bool> requestGalleryPermission() {
    return _dataSource.requestPermission();
  }

  @override
  Future<List<GalleryImage>> loadCachedBabyImages() async {
    final records = await _cacheService.loadRecords();
    final excluded = await _loadExcludedAssetIds();
    return _mapBabyImages(records, excluded);
  }

  @override
  Future<DateTime?> loadLastScanAt() {
    return _cacheService.loadLastScanAt();
  }

  @override
  Future<List<GalleryImage>> scanBabyImages({
    required void Function(GalleryScanProgress progress) onProgress,
    void Function(List<GalleryImage> partial)? onBabyFound,
    bool forceRescan = false,
    bool startupFastScan = false,
  }) async {
    // ── 1. Determine scan scope (startup fast path vs incremental) ───────
    final lastScanAt = await _cacheService.loadLastScanAt();
    final startupLimit =
        startupFastScan && !forceRescan ? AppConstants.startupInitialScanLimit : null;

    // Fast metadata fetch (no asset.file calls).
    // For startup fast-scan: only fetch photos newer than lastScanAt so the
    // background scan returns quickly.
    // For manual scan (forceRescan=false, startupFastScan=false): fetch ALL
    // photos — the DB cache below will skip already-processed ones, giving us
    // free crash-resume without restarting from scratch.
    // For forceRescan: newerThan is also null (fetch all, cache was cleared).
    final incrementalCutoff = startupFastScan ? lastScanAt : null;
    final metas = await _dataSource.fetchAssetsMetaFiltered(
      limit: startupLimit,
      newerThan: incrementalCutoff,
    );
    // ignore: avoid_print
    print('[SCAN] fetchAssetsMetaFiltered returned ${metas.length} items (startupFastScan=$startupFastScan, forceRescan=$forceRescan)');
    if (metas.isEmpty) {
      onProgress(
        const GalleryScanProgress(
          processed: 0,
          total: 0,
          message: '새로운 이미지가 없습니다.',
        ),
      );
      return loadCachedBabyImages();
    }

    // ── 2. Load existing scan cache ───────────────────────────────────────
    final storedVersion = await _cacheService.loadFilterVersion();
    final versionMismatch = storedVersion != AppConstants.cacheFilterVersion;

    final shouldResetCache = forceRescan || versionMismatch;
    if (shouldResetCache) {
      await _cacheService.clearRecords();
    }

    final cachedRecords = shouldResetCache
        ? <CachedScanRecordModel>[]
        : await _cacheService.loadRecords();
    final cachedByAssetId = <String, CachedScanRecordModel>{
      for (final r in cachedRecords) r.assetId: r,
    };

    final metasToProcess = shouldResetCache
        ? metas
        : metas.where((meta) {
            final cached = cachedByAssetId[meta.id];
            if (cached == null) return true;
        if (!startupFastScan && cached.quickScanned) return true;
            return cached.modifiedAt.millisecondsSinceEpoch !=
                meta.modifiedAt.millisecondsSinceEpoch;
          }).toList(growable: false);

    // ignore: avoid_print
    print('[SCAN] metasToProcess=${metasToProcess.length} shouldResetCache=$shouldResetCache storedVersion=$storedVersion');
    if (metasToProcess.isEmpty) {
      onProgress(
        const GalleryScanProgress(
          processed: 0,
          total: 0,
          message: '처리할 신규 이미지가 없습니다.',
        ),
      );
      return _mapBabyImages(cachedRecords, await _loadExcludedAssetIds());
    }

    // ── 2.5. Clean up the single shared temp thumbnail file ──────────────
    try {
      final thumbFile = File('${Directory.systemTemp.path}/babyscan_thumb.jpg');
      if (await thumbFile.exists()) await thumbFile.delete();
      // Also wipe any legacy per-image files from previous app versions.
      await for (final entity in Directory.systemTemp.list()) {
        if (entity is File && entity.path.contains('/babyscan_') &&
            entity.path.endsWith('_thumb.jpg')) {
          await entity.delete();
        }
      }
    } catch (_) {}

    // ── 3. Process in batches ─────────────────────────────────────────────
    final updatedRecords = <CachedScanRecordModel>[];
    final partialBabyImages = <GalleryImage>[];
    final excluded = await _loadExcludedAssetIds();
    final total = metasToProcess.length;
    var processed = 0;

    onProgress(GalleryScanProgress(
      processed: 0,
      total: total,
      message: '갤러리 메타데이터를 불러오는 중...',
    ));

    final batchSize = _isPremium
        ? AppConstants.premiumDetectionBatchSize
        : AppConstants.detectionBatchSize;
    final effectiveBatchSize = startupFastScan && batchSize > 8 ? 8 : batchSize;
    final workerCount = _isPremium
        ? AppConstants.premiumScanWorkerCount
        : AppConstants.scanWorkerCount;

    for (var i = 0; i < metasToProcess.length; i += effectiveBatchSize) {
      final end = (i + effectiveBatchSize).clamp(0, metasToProcess.length);
      final batch = metasToProcess.sublist(i, end);

      final batchResults = <CachedScanRecordModel?>[];
      for (var w = 0; w < batch.length; w += workerCount) {
        final wEnd = (w + workerCount).clamp(0, batch.length);
        final workerSlice = batch.sublist(w, wEnd);
        final resolved = await Future.wait(
          workerSlice.map(
            (meta) => _resolveRecordFromMeta(
              meta,
              cachedByAssetId[meta.id],
              quickMode: startupFastScan,
            ),
          ),
        );
        batchResults.addAll(resolved);
      }

      for (final record in batchResults) {
        if (record == null) continue;
        updatedRecords.add(record);
        if (record.isBaby && !excluded.contains(record.assetId)) {
          final img = record.toEntity();
          if (img.path.isNotEmpty) partialBabyImages.add(img);
        }
      }

      processed += batch.length;
      onProgress(GalleryScanProgress(
        processed: processed,
        total: total,
        message: '아기 얼굴 사진을 분류하는 중...',
      ));

      if (onBabyFound != null && partialBabyImages.isNotEmpty) {
        final sorted = List<GalleryImage>.of(partialBabyImages)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        onBabyFound(sorted);
      }

      // Save current batch results (INSERT OR REPLACE) for crash recovery.
      // Unchanged cached records are already in the DB — no need to re-save them.
      if (!startupFastScan) {
        final batchToSave = batchResults
            .whereType<CachedScanRecordModel>()
            .toList(growable: false);
        if (batchToSave.isNotEmpty) {
          await _cacheService.saveRecords(batchToSave);
          await _cacheService.saveFilterVersion();
        }
      }

      // Let iOS reclaim memory between batches.
      // 500 ms gives iOS time to reclaim IOSurface/ML Kit buffers between batches.
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    if (startupFastScan) {
      await _cacheService.saveRecords(updatedRecords);
      await _cacheService.saveFilterVersion();
    }

    final merged = <String, CachedScanRecordModel>{
      for (final record in cachedRecords) record.assetId: record,
    };
    for (final record in updatedRecords) {
      merged[record.assetId] = record;
    }
    return _mapBabyImages(merged.values.toList(growable: false), excluded);
  }

  /// Resolves a [GalleryAssetMeta] to a [CachedScanRecordModel].
  ///
  /// **Fast path** (cache hit, same [modifiedAt]):
  ///   - Non-baby images: return cached result immediately — path not needed.
  ///   - Baby images: verify the file still exists; re-scan if missing.
  ///
  /// **Slow path** (cache miss or stale):
  ///   1. Fetch a 256×256 JPEG thumbnail via photo_manager (≈4–8 MB IOSurface
  ///      vs ≈22 MB for the full-resolution original).
  ///   2. Write it to a temp file and run face detection on it.
  ///   3. Only call [asset.file] for confirmed baby images to get the display path.
  ///   4. Clean up the temp file regardless of outcome.
  Future<CachedScanRecordModel?> _resolveRecordFromMeta(
    GalleryAssetMeta meta,
    CachedScanRecordModel? cached,
    {bool quickMode = false}
  ) async {
    if (cached != null &&
        cached.modifiedAt.millisecondsSinceEpoch ==
            meta.modifiedAt.millisecondsSinceEpoch &&
        (quickMode || !cached.quickScanned)) {
      if (!cached.isBaby) {
        // Non-baby: no file path needed, trust cache date unconditionally.
        return cached.copyWith(
          createdAt: meta.createdAt,
          modifiedAt: meta.modifiedAt,
        );
      }
      // Baby image: verify it's still accessible on-device.
      if (cached.path.isNotEmpty && await File(cached.path).exists()) {
        return cached.copyWith(
          createdAt: meta.createdAt,
          modifiedAt: meta.modifiedAt,
        );
      }
    }

    // ── Slow path: analyse via thumbnail to keep memory low ─────────────
    // ignore: avoid_print
    print('[SCAN] resolving: ${meta.entity.title ?? meta.id}');
    // Request a thumbnail from the Photos framework.
    // 384 px matches processingMaxDimension — small enough to keep
    // ML Kit memory usage manageable across 21 k+ images.
    const thumbMaxDim = AppConstants.processingMaxDimension;
    final thumbFile = await _dataSource.getThumbnailTempFile(meta, size: thumbMaxDim);
    // ignore: avoid_print
    if (thumbFile == null) print('[SCAN] thumbFile=null for ${meta.entity.title ?? meta.id}');
    if (thumbFile == null) return null;

    // Compute scale factor so face bounding-box values (in thumbnail pixel
    // space) can be converted back to full-resolution pixel space inside the
    // face detection service — where all size thresholds are calibrated.
    final origW = meta.entity.width.toDouble();
    final origH = meta.entity.height.toDouble();
    final imageScale = (origW > 0 && origH > 0)
        ? thumbMaxDim / (origW >= origH ? origW : origH)
        : 1.0;

    FaceAnalysisResult analysis;
    try {
      analysis = await _faceDetectionService
          .analyzeImage(thumbFile, quickMode: quickMode, imageScale: imageScale)
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => const FaceAnalysisResult(
              hasFace: false,
              isBaby: false,
              faceCount: 0,
            ),
          );
    } finally {
      // Always remove the temp thumbnail file to avoid accumulating debris.
      try { await thumbFile.delete(); } catch (_) {}
    }

    // Only pay the cost of resolving the full-resolution file path for
    // images that are actually baby photos (a small fraction of the gallery).
    String displayPath = '';
    if (analysis.isBaby) {
      final model = await _dataSource.resolveMetaToModel(meta);
      displayPath = model?.path ?? '';
    }

    return CachedScanRecordModel(
      assetId: meta.id,
      path: displayPath,
      createdAt: meta.createdAt,
      modifiedAt: meta.modifiedAt,
      hasFace: analysis.hasFace,
      isBaby: analysis.isBaby,
      faceCount: analysis.faceCount,
      quickScanned: quickMode,
      faceVector: analysis.faceVector,
    );
  }

  @override
  Future<void> excludeAsset(String assetId) async {
    final excluded = await _loadExcludedAssetIds();
    if (excluded.add(assetId)) {
      await _cacheService.saveExcludedAssetIds(excluded);
    }
  }

  Future<Set<String>> _loadExcludedAssetIds() async {
    if (_excludedAssetIds != null) {
      return _excludedAssetIds!;
    }
    _excludedAssetIds = await _cacheService.loadExcludedAssetIds();
    return _excludedAssetIds!;
  }

  List<GalleryImage> _mapBabyImages(
    List<CachedScanRecordModel> records,
    Set<String> excluded,
  ) {
    final images = records
        .where(
          (record) =>
              record.hasFace &&
              record.isBaby &&
              !excluded.contains(record.assetId),
        )
        .map((record) => record.toEntity())
        .where((image) => image.path.isNotEmpty)
        .toList(growable: false);
    images.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return images;
  }

  @override
  void dispose() {
    _faceDetectionService.close();
  }
}
