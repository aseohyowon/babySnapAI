import '../locale/app_locale.dart';

/// Centralised UI strings for Korean / English.
///
/// Use [AppStrings.current] anywhere that doesn't have a BuildContext,
/// or [AppStrings.of] for widget trees (both are identical — they both
/// read [AppLocaleNotifier.instance]).
class AppStrings {
  const AppStrings._(this._ko);

  factory AppStrings.current() =>
      AppLocaleNotifier.instance.isKorean
          ? const AppStrings._(true)
          : const AppStrings._(false);

  final bool _ko;

  String get(String ko, String en) => _ko ? ko : en;

  // ── App ──────────────────────────────────────────────────────────────
  String get appTitle => get('BabySnap AI', 'BabySnap AI');
  String get premium => get('Premium ✨', 'Premium ✨');

  // ── Home screen ──────────────────────────────────────────────────────
  String get homeHeadline => get('AI 기반 아기 사진', 'AI Baby Photos');
  String get homeSubtitle =>
      get('갤러리에서 아기 얼굴 사진을 자동으로 찾아줍니다',
          'Automatically finds baby face photos from your gallery');
  String get lastScan => get('마지막 스캔', 'Last scan');
  String get scanButton => get('갤러리 스캔', 'Scan Gallery');
  String get scanning => get('스캔 진행 중...', 'Scanning...');
  String get detectedPhotos => get('감지된 사진', 'Detected');
  String get monthlyGroups => get('월별 분류', 'Monthly');
  String get favorites => get('즐겨찾기', 'Favorites');
  String get viewAllPhotos => get('모든 사진 보기', 'View All Photos');
  String get noPhotosYet => get('아직 감지된 사진이 없습니다', 'No photos detected yet');
  String get noPhotosHint =>
      get('갤러리를 스캔하여 아기 사진을 찾아보세요',
          'Scan your gallery to find baby photos');
  String get permissionNeeded =>
      get('갤러리 접근 권한이 필요합니다', 'Gallery access permission required');
  String get langToggleTooltip => get('English', '한국어');

  // ── Profile section ──────────────────────────────────────────────────
  String get childFilter => get('아이 필터', 'Child Filter');
  String get register => get('등록', 'Add');
  String get profileHint =>
      get('아이 얼굴을 등록하면 그 아이만 찾아줍니다',
          'Register a face to filter photos by that child');
  String photosByProfile(String name) =>
      get('$name 사진만 보기', "View $name's Photos");
  String profilePhotosNotFound(String name) =>
      get('$name 사진을 찾지 못했습니다.\n갤러리를 다시 스캔해 보세요.',
          "Couldn't find photos of $name.\nTry scanning the gallery again.");
  String deleteProfileTitle(String name) =>
      get('$name 삭제', 'Delete $name');
  String get deleteProfileConfirm =>
      get('이 프로필을 삭제할까요?', 'Delete this profile?');
  String get addMorePhotos => get('사진 추가 등록', 'Add More Photos');
  String registeredPhotos(int n) =>
      get('$n장 등록된 사진 · 각도가 다른 사진 추가 시 인식률 향상',
          '$n photos registered · More angles improve accuracy');
  String get deleteProfile => get('프로필 삭제', 'Delete Profile');
  String get cancel => get('취소', 'Cancel');
  String get delete => get('삭제', 'Delete');

  // ── Feature cards ─────────────────────────────────────────────────────
  String get timelineTitle => get('AI 성장 타임라인', 'AI Growth Timeline');
  String get timelineSubtitle =>
      get('월별 성장 기록 · 마일스톤 · 자동 캡션',
          'Monthly records · Milestones · Auto captions');
  String get bestPhotosTitle => get('베스트 사진 TOP 10', 'Best Photos TOP 10');
  String get bestPhotosSubtitle =>
      get('미소 · 선명도 · 얼굴크기 AI 자동 분석',
          'Smile · Sharpness · Face size AI analysis');
  String get autoAlbumTitle => get('자동 앨범 생성', 'Auto Album');
  String get autoAlbumSubtitle =>
      get('이벤트 · 장면 인식 · 자동 분류',
          'Events · Scene recognition · Auto categorisation');

  // ── Premium card ──────────────────────────────────────────────────────
  String get upgradeTitle => get('Premium으로 업그레이드', 'Upgrade to Premium');
  String get chipNoAds => get('광고 제거', 'No Ads');
  String get chipFastScan => get('빠른 스캔', 'Fast Scan');
  String get chipUnlimited => get('무제한', 'Unlimited');
  String get chipHdExport => get('HD 내보내기', 'HD Export');
}
