import 'dart:math';

import '../../domain/entities/baby_milestone.dart';
import '../../domain/entities/gallery_image.dart';
import '../../domain/entities/timeline_entry.dart';

/// Builds a list of [TimelineEntry] objects from a flat list of baby
/// [GalleryImage]s.  All detection logic runs on-device in pure Dart —
/// no network required.
class MilestoneService {
  /// Groups [images] by calendar month and annotates each month with
  /// automatically-detected milestones and an AI-generated caption.
  ///
  /// [birthDate] is optional; when provided, age labels use "생후 N개월"
  /// format and milestone thresholds (100-day, 1st birthday, …) are
  /// anchored to that date.  When omitted the earliest photo date is
  /// used as the anchor, which is a reasonable approximation for typical
  /// usage patterns.
  ///
  /// Returns entries ordered newest-first (most recent entry at index 0).
  List<TimelineEntry> buildTimeline(
    List<GalleryImage> images, {
    DateTime? birthDate,
  }) {
    if (images.isEmpty) return const [];

    // ── 1. Group by year-month key ────────────────────────────────────────
    final grouped = <String, List<GalleryImage>>{};
    for (final img in images) {
      final key =
          '${img.createdAt.year}-${img.createdAt.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(img);
    }

    final sortedKeys = grouped.keys.toList()..sort();

    // ── 2. Determine anchor date for age calculations ─────────────────────
    final firstPhotoDate = images
        .map((i) => i.createdAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final anchor = birthDate ?? firstPhotoDate;
    final hasBirthDate = birthDate != null;

    // ── 3. Max photo count for "busiest month" detection ─────────────────
    final maxCount =
        grouped.values.map((l) => l.length).reduce(max);

    // ── 4. Average face-vectors per period (for growth-change detection) ──
    final avgVectors = <String, List<double>>{};
    for (final entry in grouped.entries) {
      final vecs = entry.value
          .where((img) => img.faceVector != null && img.faceVector!.isNotEmpty)
          .map((img) => img.faceVector!)
          .toList();
      if (vecs.isNotEmpty) {
        avgVectors[entry.key] = _averageVector(vecs);
      }
    }

    // ── 5. Build one entry per period ─────────────────────────────────────
    final entries = <TimelineEntry>[];
    for (int i = 0; i < sortedKeys.length; i++) {
      final key = sortedKeys[i];
      final parts = key.split('-');
      final periodDate = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      final periodImages = grouped[key]!
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // Days elapsed from anchor to start of this period
      final ageDays = periodDate.difference(anchor).inDays;

      // ── Milestone detection ────────────────────────────────────────────
      final milestones = <BabyMilestone>[];

      if (i == 0) {
        milestones.add(const BabyMilestone(type: BabyMilestoneType.firstCapture));
      }
      if (i == sortedKeys.length - 1 && i > 0) {
        milestones.add(const BabyMilestone(type: BabyMilestoneType.latestCapture));
      }
      if (ageDays >= 90 && ageDays <= 120) {
        milestones.add(const BabyMilestone(type: BabyMilestoneType.hundredDays));
      }
      if (ageDays >= 350 && ageDays <= 390) {
        milestones.add(const BabyMilestone(type: BabyMilestoneType.firstBirthday));
      }
      if (ageDays >= 715 && ageDays <= 755) {
        milestones.add(const BabyMilestone(type: BabyMilestoneType.secondBirthday));
      }
      if (ageDays >= 1075 && ageDays <= 1115) {
        milestones.add(const BabyMilestone(type: BabyMilestoneType.thirdBirthday));
      }
      if (periodImages.length >= maxCount && maxCount > 2) {
        milestones.add(const BabyMilestone(type: BabyMilestoneType.mostPhotos));
      }

      // Face-change score vs. previous period
      double changeScore = 0.0;
      if (i > 0) {
        final prevKey = sortedKeys[i - 1];
        final thisVec = avgVectors[key];
        final prevVec = avgVectors[prevKey];
        if (thisVec != null && prevVec != null) {
          changeScore = _l2Distance(thisVec, prevVec);
          if (changeScore > 0.30) {
            milestones.add(
              const BabyMilestone(type: BabyMilestoneType.growthChange),
            );
          }
        }
      }

      // ── Labels and caption ─────────────────────────────────────────────
      final ageLabel = _buildAgeLabel(periodDate, anchor, hasBirthDate);
      final caption = _buildCaption(
        periodImages.length,
        milestones,
        ageDays,
        periodDate,
      );

      entries.add(TimelineEntry(
        period: periodDate,
        heroImage: periodImages.first,
        images: periodImages,
        milestones: milestones,
        caption: caption,
        ageLabel: ageLabel,
        faceChangeScore: changeScore,
      ));
    }

    // Newest first so parents see recent memories at the top
    return entries.reversed.toList();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _buildAgeLabel(
    DateTime period,
    DateTime anchor,
    bool hasBirthDate,
  ) {
    final totalMonths =
        (period.year - anchor.year) * 12 + (period.month - anchor.month);

    if (!hasBirthDate || totalMonths < 0) {
      return '${period.year}년 ${period.month}월';
    }
    if (totalMonths == 0) return '신생아';
    if (totalMonths < 12) return '생후 $totalMonths개월';

    final years = totalMonths ~/ 12;
    final rem = totalMonths % 12;
    if (rem == 0) return '$years살';
    return '$years살 $rem개월';
  }

  String _buildCaption(
    int photoCount,
    List<BabyMilestone> milestones,
    int ageDays,
    DateTime period,
  ) {
    // Milestone-specific captions take priority
    for (final m in milestones) {
      switch (m.type) {
        case BabyMilestoneType.firstCapture:
          return '소중한 첫 번째 기록이에요. 이 순간을 영원히 기억해요 💝';
        case BabyMilestoneType.hundredDays:
          return '백일을 진심으로 축하해요! 건강하게 자라줘서 정말 고마워 🎂';
        case BabyMilestoneType.firstBirthday:
          return '첫 번째 생일 축하해! 벌써 1년이 지났네요. 넘 사랑해 🎉';
        case BabyMilestoneType.secondBirthday:
          return '두 번째 생일을 축하해요! 날마다 더 멋있어지고 있어 🎁';
        case BabyMilestoneType.thirdBirthday:
          return '세 살이 됐어요! 아이의 밝은 미래를 응원해요 🎈';
        case BabyMilestoneType.mostPhotos:
          return '이번 달은 사진이 유독 많네요! 즐거운 일이 가득했나봐요 📸';
        case BabyMilestoneType.growthChange:
          return '눈에 띄게 쑥쑥 자란 게 느껴져요. 우리 아이 정말 대견해 ✨';
        case BabyMilestoneType.latestCapture:
          return '지금 이 순간도 언젠가 가장 소중한 추억이 될 거예요 💕';
      }
    }

    // Age-based generic captions
    if (ageDays < 30) return '세상에 온 지 얼마 되지 않았어요. 건강하게 자라렴 🌱';
    if (ageDays < 60) return '조금씩 표정이 풍부해지고 있어요 😊';
    if (ageDays < 90) return '매일 조금씩 달라지는 모습이 신기하고 경이로워요 🌿';
    if (ageDays < 180) return '웃음이 점점 늘어가고 있어요. 행복한 시간이에요 🌸';
    if (ageDays < 270) return '세상이 온통 신기한가봐요. 호기심이 반짝이는 눈빛이에요 👀';
    if (ageDays < 365) return '기어다니고, 일어서고, 매일 새로운 도전을 하고 있어요 🚀';
    if (ageDays < 548) return '말을 배우고, 걷고, 세상과 소통하기 시작했어요 💬';
    if (ageDays < 730) return '장난이 늘고 웃음이 끊이지 않는 행복한 시간이에요 🎈';

    final season = _season(period.month);
    return '$season의 소중한 추억이에요. $photoCount장의 사진에 담아뒀어요 📷';
  }

  String _season(int month) {
    if (month >= 3 && month <= 5) return '봄';
    if (month >= 6 && month <= 8) return '여름';
    if (month >= 9 && month <= 11) return '가을';
    return '겨울';
  }

  List<double> _averageVector(List<List<double>> vecs) {
    final dim = vecs.first.length;
    final result = List<double>.filled(dim, 0.0);
    for (final v in vecs) {
      for (int i = 0; i < dim; i++) {
        result[i] += v[i];
      }
    }
    for (int i = 0; i < dim; i++) {
      result[i] /= vecs.length;
    }
    return result;
  }

  double _l2Distance(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    var sum = 0.0;
    for (int i = 0; i < a.length; i++) {
      final d = a[i] - b[i];
      sum += d * d;
    }
    return sqrt(sum);
  }
}
