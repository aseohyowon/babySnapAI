import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Centralised AdMob manager for BabySnap AI.
///
/// Banner   → ca-app-pub-6516622519474642/4010261332 (iOS)
/// Interstitial → ca-app-pub-6516622519474642/7877443445 (iOS)
///
/// Policy compliance:
///  • Interstitial is only shown on explicit user-initiated navigation
///    (gallery open), never on app start or in the background.
///  • Interval guard: shows at most once every [_interstitialInterval] triggers
///    so the user is not overwhelmed.
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  static const _bannerUnitId =
      'ca-app-pub-6516622519474642/4010261332';
  static const _interstitialUnitId =
      'ca-app-pub-6516622519474642/7877443445';

  // Show interstitial once every N eligible triggers.
  static const _interstitialInterval = 2;
  int _triggerCount = 0;

  bool _isPremium = false;

  InterstitialAd? _interstitialAd;
  bool _adLoading = false;

  /// Call this whenever the user's premium status changes so ads are
  /// automatically suppressed (or re-enabled) without restarting the app.
  void setPremium(bool isPremium) {
    _isPremium = isPremium;
    if (isPremium) {
      // Dispose loaded ad to free memory — premium users won't see it.
      _interstitialAd?.dispose();
      _interstitialAd = null;
    }
  }

  // ── Interstitial ────────────────────────────────────────────────────────

  /// Pre-loads the next interstitial in the background.
  void loadInterstitial() {
    if (_adLoading || _interstitialAd != null) return;
    _adLoading = true;
    InterstitialAd.load(
      adUnitId: _interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _adLoading = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('[AdService] Interstitial failed: $error');
          _adLoading = false;
        },
      ),
    );
  }

  /// Shows an interstitial (subject to interval) then calls [onDone].
  ///
  /// [onDone] is **always** called — immediately when no ad is shown, or
  /// after the ad is dismissed/fails. Callers should use this to perform
  /// navigation or next action.
  void showInterstitialThenRun(VoidCallback onDone) {
    // Premium users never see interstitials.
    if (_isPremium) {
      onDone();
      return;
    }
    _triggerCount++;
    final shouldShow =
        (_triggerCount % _interstitialInterval == 0) && _interstitialAd != null;

    if (!shouldShow) {
      loadInterstitial(); // keep the pipeline warm
      onDone();
      return;
    }

    final ad = _interstitialAd!;
    _interstitialAd = null;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) {
        ad.dispose();
        loadInterstitial();
        onDone();
      },
      onAdFailedToShowFullScreenContent: (_, error) {
        debugPrint('[AdService] Failed to show interstitial: $error');
        ad.dispose();
        loadInterstitial();
        onDone();
      },
    );
    ad.show();
  }

  // ── Banner ───────────────────────────────────────────────────────────────

  /// Creates and loads a standard (320×50) banner ad.
  ///
  /// Returns `null` when the user is premium — callers should treat a null
  /// result as "no banner to show".
  ///
  /// [onLoaded] is called when the ad finishes loading so the caller can
  /// trigger a `setState` to display it. The caller is responsible for
  /// calling `dispose()` on the returned [BannerAd].
  BannerAd? createBanner({required VoidCallback onLoaded}) {
    if (_isPremium) return null; // No ads for premium users.
    return BannerAd(
      adUnitId: _bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded(),
        onAdFailedToLoad: (ad, error) {
          debugPrint('[AdService] Banner failed: $error');
          ad.dispose();
        },
      ),
    )..load();
  }
}
