/// Types of life milestones that can be detected automatically from a baby's
/// photo timeline.
enum BabyMilestoneType {
  firstCapture,
  hundredDays,
  firstBirthday,
  secondBirthday,
  thirdBirthday,
  mostPhotos,
  growthChange,
  latestCapture,
}

class BabyMilestone {
  const BabyMilestone({required this.type, this.label});

  final BabyMilestoneType type;

  /// Override label. Falls back to [defaultLabel] when null.
  final String? label;

  String get emoji {
    switch (type) {
      case BabyMilestoneType.firstCapture:
        return '🌟';
      case BabyMilestoneType.hundredDays:
        return '🎂';
      case BabyMilestoneType.firstBirthday:
        return '🎉';
      case BabyMilestoneType.secondBirthday:
        return '🎁';
      case BabyMilestoneType.thirdBirthday:
        return '🎈';
      case BabyMilestoneType.mostPhotos:
        return '📸';
      case BabyMilestoneType.growthChange:
        return '✨';
      case BabyMilestoneType.latestCapture:
        return '💕';
    }
  }

  String get defaultLabel {
    switch (type) {
      case BabyMilestoneType.firstCapture:
        return '첫 번째 사진';
      case BabyMilestoneType.hundredDays:
        return '백일 🎂';
      case BabyMilestoneType.firstBirthday:
        return '첫 돌 🎉';
      case BabyMilestoneType.secondBirthday:
        return '두 돌 🎁';
      case BabyMilestoneType.thirdBirthday:
        return '세 돌 🎈';
      case BabyMilestoneType.mostPhotos:
        return '사진이 가장 많은 달';
      case BabyMilestoneType.growthChange:
        return '눈에 띄는 성장';
      case BabyMilestoneType.latestCapture:
        return '최근 추억';
    }
  }

  String get displayLabel => label ?? defaultLabel;
}
