import 'dart:io';

import '../../core/constants/app_constants.dart';
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
  }) async {
    // ── 1. Fast metadata fetch (no asset.file calls) ──────────────────────
    final metas = await _dataSource.fetchAssetsMetaFiltered();
    if (metas.isEmpty) {
      onProgress(
        const GalleryScanProgress(
          processed: 0,
          total: 0,
          message: '갤러리에 이미지가 없습니다.',
        ),
      );
      await _cacheService.saveRecords(<CachedScanRecordModel>[]);
      return <GalleryImage>[];
    }

    // ── 2. Load existing scan cache ───────────────────────────────────────
    final storedVersion = await _cacheService.loadFilterVersion();
    final versionMismatch = storedVersion != AppConstants.cacheFilterVersion;

    final cachedRecords = (forceRescan || versionMismatch)
        ? <CachedScanRecordModel>[]
        : await _cacheService.loadRecords();
    final cachedByAssetId = <String, CachedScanRecordModel>{
      for (final r in cachedRecords) r.assetId: r,
    };

    // ── 3. Process in batches ─────────────────────────────────────────────
    final updatedRecords = <CachedScanRecordModel>[];
    final partialBabyImages = <GalleryImage>[];
    final excluded = await _loadExcludedAssetIds();
    final total = metas.length;
    var processed = 0;

    onProgress(GalleryScanProgress(
      processed: 0,
      total: total,
      message: '갤러리 메타데이터를 불러오는 중...',
    ));

    final batchSize = _isPremium
        ? AppConstants.premiumDetectionBatchSize
        : AppConstants.detectionBatchSize;

    for (var i = 0; i < metas.length; i += batchSize) {
      final end = (i + batchSize).clamp(0, metas.length);
      final batch = metas.sublist(i, end);

      final batchResults = await Future.wait(
        batch.map(
          (meta) => _resolveRecordFromMeta(meta, cachedByAssetId[meta.id]),
        ),
      );

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
    }

    await _cacheService.saveRecords(updatedRecords);
    await _cacheService.saveFilterVersion();
    return _mapBabyImages(updatedRecords, excluded);
  }

  /// Resolves a [GalleryAssetMeta] to a [CachedScanRecordModel].
  ///
  /// **Fast path** (cache hit): if [cached] has the same [modifiedAt] and the
  /// file still exists on disk, return the cached record without calling
  /// [asset.file] — saving one expensive async I/O call per asset.
  ///
  /// **Slow path** (cache miss or stale): resolve the actual file path via
  /// [resolveMetaToModel], then run face detection.
  Future<CachedScanRecordModel?> _resolveRecordFromMeta(
    GalleryAssetMeta meta,
    CachedScanRecordModel? cached,
  ) async {
    if (cached != null &&
        cached.modifiedAt.millisecondsSinceEpoch ==
            meta.modifiedAt.millisecondsSinceEpoch) {
      // Verify the file is still reachable before trusting the cached record.
      if (cached.path.isNotEmpty && await File(cached.path).exists()) {
        return cached.copyWith(
          createdAt: meta.createdAt,
          modifiedAt: meta.modifiedAt,
        );
      }
    }

    // Resolve the actual file path (calls asset.file once).
    final model = await _dataSource.resolveMetaToModel(meta);
    if (model == null) return null;

    final analysis = await _faceDetectionService.analyzeImage(File(model.path));
    return CachedScanRecordModel(
      assetId: meta.id,
      path: model.path,
      createdAt: meta.createdAt,
      modifiedAt: meta.modifiedAt,
      hasFace: analysis.hasFace,
      isBaby: analysis.isBaby,
      faceCount: analysis.faceCount,
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
