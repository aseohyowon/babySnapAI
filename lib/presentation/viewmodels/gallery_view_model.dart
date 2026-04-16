import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/ad_service.dart';
import '../../domain/entities/baby_profile.dart';
import '../../domain/entities/favorite_image.dart';
import '../../domain/entities/gallery_image.dart';
import '../../domain/entities/gallery_scan_progress.dart';
import '../../domain/entities/premium_state.dart';
import '../../domain/usecases/get_favorites_usecase.dart';
import '../../domain/usecases/get_images_with_faces_usecase.dart';
import '../../domain/usecases/get_premium_status_usecase.dart';
import '../../domain/usecases/manage_baby_profiles_usecase.dart';
import '../models/gallery_section.dart';

class GalleryViewModel extends ChangeNotifier {
  GalleryViewModel(
    this._getImagesWithFacesUseCase,
    this._getFavoritesUsecase,
    this._getPremiumStatusUsecase,
    this._manageBabyProfilesUsecase,
  );

  final GetImagesWithFacesUseCase _getImagesWithFacesUseCase;
  final GetFavoritesUseCase _getFavoritesUsecase;
  final GetPremiumStatusUseCase _getPremiumStatusUsecase;
  final ManageBabyProfilesUseCase _manageBabyProfilesUsecase;

  bool _isLoading = false;
  bool _isScanning = false;
  bool _hasPermission = true;
  String? _errorMessage;
  List<GalleryImage> _images = <GalleryImage>[];
  List<GallerySection> _sections = const <GallerySection>[];
  GalleryScanProgress? _progress;
  DateTime? _lastScanAt;
  Set<String> _favoriteAssetIds = <String>{};
  PremiumState? _premiumState;
  bool _isDisposed = false;
  List<BabyProfile> _profiles = <BabyProfile>[];
  BabyProfile? _activeProfile;

  static const double _similarityThreshold = 0.45;

  bool get isLoading => _isLoading;
  bool get isScanning => _isScanning;
  bool get hasPermission => _hasPermission;
  String? get errorMessage => _errorMessage;
  List<GalleryImage> get images => _images;
  List<GallerySection> get sections => _sections;
  GalleryScanProgress? get progress => _progress;
  DateTime? get lastScanAt => _lastScanAt;
  Set<String> get favoriteAssetIds => _favoriteAssetIds;
  bool get isPremium => _premiumState?.isPremium ?? false;
  List<BabyProfile> get profiles => _profiles;
  BabyProfile? get activeProfile => _activeProfile;

  /// Images filtered by the active baby profile (or all images if no profile active).
  List<GalleryImage> get displayImages =>
      _activeProfile != null ? _getProfileFilteredImages() : _images;

  /// Sections for the currently active view (filtered or all).
  List<GallerySection> get displaySections =>
      _activeProfile != null ? _buildSections(displayImages) : _sections;

  void _notifySafely() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    _notifySafely();

    try {
      final granted = await _getImagesWithFacesUseCase.requestGalleryPermission();
      if (!granted) {
        _hasPermission = false;
        _images = <GalleryImage>[];
        return;
      }

      _hasPermission = true;

      // Load the last scan timestamp first so we can decide whether to
      // trigger a background scan after the UI is shown.
      _lastScanAt = await _getImagesWithFacesUseCase.loadLastScanAt();

      // Kick off the remaining cache loads in parallel for faster startup.
      final cacheImagesFuture = _getImagesWithFacesUseCase.loadCachedBabyImages();
      final parallelLoads = Future.wait([
        _loadFavorites(),
        _loadPremiumStatus(),
        loadProfiles(),
      ]);

      _images = await cacheImagesFuture;
      _sections = _buildSections(_images);

      await parallelLoads; // favorites + premium + profiles
    } catch (_) {
      _errorMessage = '캐시를 불러오는 중 오류가 발생했습니다.';
    } finally {
      _isLoading = false;
      _notifySafely(); // ← UI renders from cache here, startup complete
    }

    // Trigger a background incremental scan only when the cache is stale or
    // this is the very first launch (no previous scan stored).
    final needsScan = _lastScanAt == null ||
        DateTime.now().difference(_lastScanAt!).inHours >=
            AppConstants.autoScanStaleHours;
    if (needsScan) {
      unawaited(scanGallery(forceRescan: false, startupFastScan: true));
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final favorites = await _getFavoritesUsecase.execute();
      _favoriteAssetIds = favorites.map((fav) => fav.assetId).toSet();
    } catch (_) {}
  }

  Future<void> _loadPremiumStatus() async {
    try {
      _premiumState = await _getPremiumStatusUsecase.execute();
      // Propagate premium status to services and scan repository.
      AdService.instance.setPremium(isPremium);
      _getImagesWithFacesUseCase.setPremium(isPremium);
    } catch (_) {}
  }

  Future<void> upgradeToPremium([bool monthly = false]) async {
    // Do NOT catch here — let errors propagate to PaywallScreen so it can
    // show appropriate UI (cancel message, billing error, pending, etc.).
    await _getPremiumStatusUsecase.upgradeToPremium(monthly: monthly);
    _premiumState = await _getPremiumStatusUsecase.execute();
    AdService.instance.setPremium(isPremium);
    _getImagesWithFacesUseCase.setPremium(isPremium);
    _notifySafely();
  }

  Future<void> restorePremium() async {
    try {
      await _getPremiumStatusUsecase.restorePremium();
      _premiumState = await _getPremiumStatusUsecase.execute();
      AdService.instance.setPremium(isPremium);
      _getImagesWithFacesUseCase.setPremium(isPremium);
      _notifySafely();
    } catch (_) {}
  }

  Future<void> toggleFavorite(GalleryImage image) async {
    try {
      if (_favoriteAssetIds.contains(image.assetId)) {
        await _getFavoritesUsecase.removeFavorite(image.assetId);
        _favoriteAssetIds.remove(image.assetId);
      } else {
        await _getFavoritesUsecase.addFavorite(
          FavoriteImage(assetId: image.assetId, path: image.path, addedAt: DateTime.now()),
        );
        _favoriteAssetIds.add(image.assetId);
      }
      _notifySafely();
    } catch (_) {}
  }

  Future<void> excludeImage(GalleryImage image) async {
    try {
      await _getImagesWithFacesUseCase.excludeAsset(image.assetId);
      _images = _images.where((it) => it.assetId != image.assetId).toList();
      _sections = _buildSections(_images);
      _notifySafely();
    } catch (_) {}
  }

  // ── Profile management ────────────────────────────────────────────────────

  Future<void> loadProfiles() async {
    try {
      _profiles = await _manageBabyProfilesUsecase.loadProfiles();
      _notifySafely();
    } catch (_) {}
  }

  void setActiveProfile(BabyProfile? profile) {
    _activeProfile = profile;
    _notifySafely();
  }

  /// Analyzes [imagePath] and returns the extracted face vector (null if
  /// landmarks are insufficient).
  Future<List<double>?> extractFaceVectorFromImage(String imagePath) =>
      _manageBabyProfilesUsecase.extractFaceVector(imagePath);

  Future<void> addProfile(BabyProfile profile) async {
    try {
      await _manageBabyProfilesUsecase.saveProfile(profile);
      await loadProfiles();
      // Rescan so that existing images get their faceVectors populated.
      await scanGallery(forceRescan: true);
    } catch (_) {}
  }

  Future<void> deleteProfile(String id) async {
    try {
      await _manageBabyProfilesUsecase.deleteProfile(id);
      if (_activeProfile?.id == id) _activeProfile = null;
      await loadProfiles();
    } catch (_) {}
  }

  List<GalleryImage> _getProfileFilteredImages() {
    final profile = _activeProfile!;
    if (profile.faceVectors.isEmpty) return <GalleryImage>[];
    return _images.where((img) {
      final vec = img.faceVector;
      if (vec == null || vec.isEmpty) return false;
      // Use the highest similarity across all registered reference photos.
      var best = 0.0;
      for (final ref in profile.faceVectors) {
        if (ref.isEmpty) continue;
        final sim = _manageBabyProfilesUsecase.computeSimilarity(ref, vec);
        if (sim > best) best = sim;
      }
      return best >= _similarityThreshold;
    }).toList();
  }

  /// Add an extra reference photo to [profile] for better recognition.
  Future<String?> addPhotoToProfile(BabyProfile profile, String imagePath) async {
    try {
      final vec = await _manageBabyProfilesUsecase.extractFaceVector(imagePath);
      if (vec == null) return '얼굴을 인식할 수 없습니다. 다른 사진을 선택해 주세요.';
      final updated = profile.copyWith(
        faceVectors: [...profile.faceVectors, vec],
      );
      await _manageBabyProfilesUsecase.saveProfile(updated);
      if (_activeProfile?.id == profile.id) _activeProfile = updated;
      await loadProfiles();
      return null; // success
    } catch (_) {
      return '사진 추가 중 오류가 발생했습니다.';
    }
  }

  bool isFavorite(String assetId) => _favoriteAssetIds.contains(assetId);

  Future<void> scanGallery({
    bool forceRescan = false,
    bool startupFastScan = false,
  }) async {
    _isScanning = true;
    _errorMessage = null;
    _progress = const GalleryScanProgress(
      processed: 0,
      total: 0,
      message: '스캔을 준비하는 중...',
    );
    _notifySafely();

    try {
      _images = await _getImagesWithFacesUseCase.execute(
        forceRescan: forceRescan,
        startupFastScan: startupFastScan,
        onProgress: (progress) {
          _progress = progress;
          _notifySafely();
        },
        // Progressive update: show baby photos as they are discovered so the
        // gallery populates in real-time rather than all at once at the end.
        onBabyFound: (partial) {
          _images = partial;
          _sections = _buildSections(partial);
          _notifySafely();
        },
      );
      _sections = _buildSections(_images);
      _lastScanAt = await _getImagesWithFacesUseCase.loadLastScanAt();
    } catch (_) {
      _errorMessage = '갤러리 스캔 중 오류가 발생했습니다.';
    } finally {
      _isScanning = false;
      _progress = null;
      _notifySafely();
    }
  }

  List<GallerySection> _buildSections(List<GalleryImage> images) {
    if (images.isEmpty) {
      return const <GallerySection>[];
    }

    final grouped = <String, List<GalleryImage>>{};
    for (final image in images) {
      final key = '${image.createdAt.year}.${image.createdAt.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => <GalleryImage>[]).add(image);
    }

    return grouped.entries
        .map((entry) => GallerySection(title: entry.key, images: entry.value))
        .toList(growable: false);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _getImagesWithFacesUseCase.dispose();
    super.dispose();
  }
}
