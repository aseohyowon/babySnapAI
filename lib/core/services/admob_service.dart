class AdMobService {
  static const String bannerAdUnitId = 'ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy';
  static const String interstitialAdUnitId =
      'ca-app-pub-xxxxxxxxxxxxxxxx/zzzzzzzzzz';

  Future<bool> initializeAds() async {
    return true;
  }

  String getBannerAdUnitId(bool isPremium) {
    if (isPremium) {
      return '';
    }

    return bannerAdUnitId;
  }

  String getInterstitialAdUnitId() {
    return interstitialAdUnitId;
  }

  bool shouldShowAds(bool isPremium) => !isPremium;
}
