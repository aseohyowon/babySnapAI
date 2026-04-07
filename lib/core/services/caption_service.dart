import 'dart:io';
import 'dart:math';

import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

/// Result returned by [CaptionService.generateCaption].
class CaptionResult {
  const CaptionResult({
    required this.caption,
    required this.hashtags,
    required this.detectedScene,
  });

  /// Main Korean caption sentence(s).
  final String caption;

  /// Suggested Korean hashtags (without the # prefix each is a word).
  final List<String> hashtags;

  /// Short English scene description used internally (for debug / display).
  final String detectedScene;

  String get hashtagLine =>
      hashtags.map((t) => '#$t').join(' ');
}

/// Generates Korean captions for a photo entirely on-device.
///
/// Strategy:
///   1. Run ML Kit ImageLabeler on the photo.
///   2. Map labels → scene category.
///   3. Pick a caption from a large pool keyed by (scene × date-vibe).
///   4. Append season/time-of-day flavour + hashtags.
class CaptionService {
  CaptionService()
      : _labeler = ImageLabeler(
          options: ImageLabelerOptions(confidenceThreshold: 0.45),
        );

  final ImageLabeler _labeler;
  final Random _rng = Random();

  /// Generates a caption for [imageFile], optionally using [takenAt] for
  /// season/time-of-day context and [birthDate] for age-aware phrasing.
  Future<CaptionResult> generateCaption(
    File imageFile, {
    DateTime? takenAt,
    DateTime? birthDate,
  }) async {
    final date = takenAt ?? DateTime.now();

    // 1. Run ML Kit
    Set<String> labels = {};
    try {
      final input = InputImage.fromFile(imageFile);
      final results = await _labeler.processImage(input);
      labels = results.map((l) => l.label).toSet();
    } catch (_) {
      // Proceed with empty label set — date/face signals still work.
    }

    // 2. Classify scene
    final scene = _detectScene(labels);

    // 3. Date vibe
    final vibe = _dateVibe(date);

    // 4. Age phrase (if birthDate given)
    final agePhrase = birthDate != null ? _agePhrase(birthDate, date) : '';

    // 5. Pick caption
    final base = _pickCaption(scene, vibe);

    // 6. Assemble
    final caption = agePhrase.isEmpty ? base : '$agePhrase\n$base';

    // 7. Hashtags
    final tags = _buildHashtags(scene, date, agePhrase.isNotEmpty);

    return CaptionResult(
      caption: caption,
      hashtags: tags,
      detectedScene: scene,
    );
  }

  // ── Scene classification ─────────────────────────────────────────────────

  static const Map<String, String> _labelToScene = {
    'Birthday cake': 'birthday', 'Cake': 'birthday',
    'Candle': 'birthday', 'Balloon': 'birthday',
    'Confetti': 'birthday', 'Celebration': 'birthday', 'Party': 'birthday',

    'Swimming pool': 'water', 'Beach': 'water', 'Sea': 'water',
    'Ocean': 'water', 'Swimming': 'water', 'Water': 'water',
    'Lake': 'water', 'River': 'water', 'Sand': 'water',

    'Snow': 'winter', 'Winter': 'winter', 'Ice': 'winter', 'Frost': 'winter',

    'Flower': 'spring', 'Blossom': 'spring', 'Cherry blossom': 'spring',
    'Garden': 'spring', 'Petal': 'spring',

    'Dog': 'animal', 'Cat': 'animal', 'Pet': 'animal',
    'Puppy': 'animal', 'Kitten': 'animal', 'Rabbit': 'animal',
    'Animal': 'animal', 'Bird': 'animal',

    'Food': 'meal', 'Meal': 'meal', 'Plate': 'meal',
    'Bowl': 'meal', 'Dessert': 'meal', 'Cake (food)': 'meal',
    'Fruit': 'meal', 'Beverage': 'meal', 'Tableware': 'meal',

    'Park': 'outdoor', 'Nature': 'outdoor', 'Tree': 'outdoor',
    'Grass': 'outdoor', 'Sky': 'outdoor', 'Mountain': 'outdoor',
    'Forest': 'outdoor', 'Field': 'outdoor', 'Landscape': 'outdoor',
    'Meadow': 'outdoor', 'Playground': 'outdoor',

    'Book': 'learning', 'Toy': 'play', 'Ball': 'play',

    'Bed': 'sleep', 'Pillow': 'sleep',

    'Architecture': 'travel', 'Building': 'travel',
    'Landmark': 'travel', 'Museum': 'travel', 'Castle': 'travel',
  };

  String _detectScene(Set<String> labels) {
    final counts = <String, int>{};
    for (final label in labels) {
      final scene = _labelToScene[label];
      if (scene != null) counts[scene] = (counts[scene] ?? 0) + 1;
    }
    if (counts.isEmpty) return 'everyday';
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  // ── Date vibe (time-of-day + weekday) ────────────────────────────────────

  String _dateVibe(DateTime d) {
    final hour = d.hour;
    if (hour >= 5 && hour < 9) return 'morning';
    if (hour >= 9 && hour < 12) return 'midmorning';
    if (hour >= 12 && hour < 14) return 'noon';
    if (hour >= 14 && hour < 18) return 'afternoon';
    if (hour >= 18 && hour < 21) return 'evening';
    return 'night';
  }

  // ── Age phrase ────────────────────────────────────────────────────────────

  String _agePhrase(DateTime birth, DateTime taken) {
    final days = taken.difference(birth).inDays;
    if (days < 0) return '';
    if (days < 30) return '태어난 지 ${days + 1}일째 되는 날 📅';
    final months = (days / 30.4).round();
    if (months < 12) return '생후 $months개월 아가의 하루 🌱';
    final years = days ~/ 365;
    final remMonths = ((days % 365) / 30.4).round();
    if (remMonths == 0) return '$years살 생일을 맞이했어요 🎂';
    return '$years살 $remMonths개월, 이 순간도 소중해 💕';
  }

  // ── Caption pools ────────────────────────────────────────────────────────

  static const Map<String, List<String>> _captions = {
    'birthday': [
      '오늘은 정말 특별한 날! 생일을 진심으로 축하해요 🎉',
      '케이크의 촛불만큼 소원이 이뤄지길 바랍니다 🎂',
      '세상에서 제일 행복한 축하 파티예요 🎈',
      '매년 이 날이 오면 얼마나 감사한지 몰라요 💝',
      '생일 축하해! 앞으로도 건강하게, 행복하게 자라렴 🌟',
    ],
    'water': [
      '첨벙첨벙! 물놀이가 이렇게 신나는 거였구나 🏊',
      '햇살 아래 물 위에서 온종일 행복했어요 ☀️',
      '발끝을 적시는 물이 간질간질해서 웃음이 났나봐요 😄',
      '파도 소리와 함께한 그 하루, 영원히 기억될 거예요 🌊',
      '신나게 물장구치는 모습이 너무 귀여워요 💦',
    ],
    'winter': [
      '눈 위에 처음 발걸음을 남긴 순간이에요 ❄️',
      '하얀 세상 속에서 더욱 빛나는 우리 아이 ⛄',
      '차가운 바람도 웃음으로 이겨낼 수 있어요 🧣',
      '눈꽃처럼 소중하고 특별한 하루였어요 ❄️',
      '겨울 나라에서 온 것 같은 천사 같은 모습이에요 👼',
    ],
    'spring': [
      '꽃처럼 활짝 피어나는 우리 아이의 봄날이에요 🌸',
      '봄바람과 함께 웃음꽃이 활짝 피었어요 🌷',
      '벚꽃보다 더 예쁜 미소네요 🌸',
      '새싹이 돋는 계절처럼, 매일 자라는 우리 아이 🌱',
      '봄 향기 가득한 하루, 너무 예뻤어요 🌼',
    ],
    'animal': [
      '동물 친구들과의 만남이 이렇게 설렐 줄이야 🐾',
      '폭신폭신한 친구에게 눈을 못 떼고 있어요 🐕',
      '세상 모든 생명에 관심이 많은 호기심쟁이예요 👀',
      '동물 친구랑 금방 친해졌어요! 연신 웃음이 나와요 😊',
      '귀여운 동물과의 첫 만남, 오래오래 기억할 거예요 🐾',
    ],
    'meal': [
      '오물오물 맛있게 잘 먹어줘서 고마워요 🍽️',
      '밥을 먹을 때 가장 행복해 보여요 😋',
      '이유식부터 밥상까지, 함께 먹는 시간이 소중해요 🥄',
      '세상에서 가장 맛있는 한 끼였어요 😍',
      '먹는 게 즐거운 아이로 자라줘서 기뻐요 💛',
    ],
    'outdoor': [
      '파란 하늘 아래서 신나게 뛰노는 우리 아이예요 🌳',
      '바깥 바람이 이렇게 상쾌하고 좋았나봐요 🍃',
      '자연 속에 있을 때 가장 빛이 나는 것 같아요 🌤️',
      '세상이 놀이터! 뭐든 신기하고 재밌는 하루 🌿',
      '맑은 하늘 아래, 소중한 추억을 쌓았어요 ☁️',
    ],
    'play': [
      '장난감이랑 노는 시간이 이렇게 즐거울 수가 없어요 🎮',
      '온 집안이 놀이터가 됐어요! 에너지가 넘쳐요 ⚡',
      '상상력이 가득한 놀이 시간이었어요 🎲',
      '노는 모습 하나하나가 다 예뻐요 😊',
    ],
    'sleep': [
      '잠든 얼굴을 보면 천사 같다는 말이 딱 맞아요 😇',
      '할 일 다 하고 곤히 잠든 우리 아이 💤',
      '세상 편하게 자고 있는 모습이 너무 사랑스러워요 🌙',
      '꿈속에서도 웃고 있을 것 같아요 💭',
    ],
    'learning': [
      '집중하는 눈빛이 너무 真真 예쁩니다 📚',
      '배우고 싶은 마음이 넘쳐흘러요 ✏️',
      '하나씩 배워가는 모습이 대견하고 뿌듯해요 🌟',
    ],
    'travel': [
      '새로운 곳에서의 설레는 하루였어요 ✈️',
      '여행지에서도 밝게 빛나는 우리 아이예요 🗺️',
      '어디서든 즐겁게 탐험하는 모험가예요 🌍',
      '이 특별한 여행, 오래오래 기억할 거예요 📍',
    ],
    'everyday': [
      '오늘 하루도 눈부시게 사랑스러운 우리 아이예요 💕',
      '아무 날도 소중하지 않은 날이 없어요 📷',
      '평범한 하루도 이렇게 예쁘게 빛날 수 있어요 ✨',
      '오늘 이 순간, 영원히 간직하고 싶어요 🌟',
      '매일 보고 싶고, 매일 사랑스러운 우리 아이 💛',
      '찰칵! 이 미소를 평생 간직할게요 😊',
      '하루하루가 선물같은 우리 아이의 일상이에요 🎁',
    ],
  };

  static const Map<String, String> _vibeSuffix = {
    'morning': '맑은 아침, 새로운 하루의 시작이에요 🌅',
    'midmorning': '눈부신 오전, 신나는 하루가 펼쳐져요 🌞',
    'noon': '점심 빛 아래 더욱 빛나는 미소네요 ☀️',
    'afternoon': '햇살 좋은 오후, 행복이 가득해요 🌤️',
    'evening': '노을빛 아래 더욱 따뜻한 순간이에요 🌇',
    'night': '오늘 하루도 수고했어요. 밤이 되어도 예뻐요 🌙',
  };

  String _pickCaption(String scene, String vibe) {
    final pool = _captions[scene] ?? _captions['everyday']!;
    final base = pool[_rng.nextInt(pool.length)];
    // 50% chance to append a vibe suffix so captions stay varied.
    if (_rng.nextBool()) return '$base\n${_vibeSuffix[vibe]!}';
    return base;
  }

  // ── Hashtags ─────────────────────────────────────────────────────────────

  List<String> _buildHashtags(
      String scene, DateTime date, bool hasAge) {
    final tags = <String>[
      '아기사진', '육아일기', '베이비스냅',
    ];

    const sceneTags = <String, List<String>>{
      'birthday': ['생일축하', '생일파티', '케이크'],
      'water': ['물놀이', '여름추억'],
      'winter': ['겨울', '눈사람', '설경'],
      'spring': ['봄나들이', '꽃놀이'],
      'animal': ['동물친구', '반려동물'],
      'meal': ['이유식', '아기밥상', '먹스타그램'],
      'outdoor': ['야외나들이', '자연'],
      'play': ['놀이시간', '장난감'],
      'sleep': ['잠든아기', '꿀잠'],
      'travel': ['여행', '아기여행'],
    };

    tags.addAll(sceneTags[scene] ?? ['일상', '오늘의아기']);

    if (hasAge) { tags.add('성장일기'); }

    // Season tag
    final m = date.month;
    if (m >= 3 && m <= 5) {
      tags.add('봄');
    } else if (m >= 6 && m <= 8) {
      tags.add('여름');
    } else if (m >= 9 && m <= 11) {
      tags.add('가을');
    } else {
      tags.add('겨울');
    }

    return tags;
  }

  void close() => _labeler.close();
}
