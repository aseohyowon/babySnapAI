class AppConstants {
  const AppConstants._();

  static const bool ultraStrictBabyMode = false;
  static const int galleryPageSize = 200;
  static const int detectionBatchSize = 6;
  /// Premium users get larger batches → ~3× faster scan.
  static const int premiumDetectionBatchSize = 20;
  static const String scanCacheKey = 'baby_gallery_scan_cache';
  static const String lastScanAtKey = 'baby_gallery_last_scan_at';
  static const String excludedAssetIdsKey = 'baby_gallery_excluded_asset_ids';
  static const double babyFaceMinAreaThreshold = 8000;
  static const double babyFaceAreaThreshold = 220000;
  static const double babyFaceMinWidthThreshold = 90;
  static const double babyFaceWidthThreshold = 520;
  static const double babyFaceMinAspectRatio = 0.75;
  static const double babyFaceMaxAspectRatio = 1.35;
  static const double babyEyeDistanceThreshold = 140;
  static const double babyEyeNoseDistanceThreshold = 95;
  static const int babyDetectionMinScore = 4;
  static const int minRequiredFaceLandmarks = 3;

  /// Minimum composite real-photo score (0–100) to accept an image.
  static const double realPhotoMinScore = 38.0;

  /// Increment this whenever the photo-filtering logic changes.
  /// The app will automatically invalidate the old scan cache and rescan
  /// all images with the updated filter on the next gallery scan.
  static const int cacheFilterVersion = 5;
  static const String cacheFilterVersionKey = 'baby_gallery_filter_version';

  /// Enable verbose detection logging to the debug console.
  static const bool debugDetection = false;

  /// Auto-trigger a background scan if the last scan was more than this many
  /// hours ago. Users who open the app within this window see cached results
  /// instantly with no scan delay.
  static const int autoScanStaleHours = 6;
}
