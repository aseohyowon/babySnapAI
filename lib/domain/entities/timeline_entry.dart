import 'gallery_image.dart';
import 'baby_milestone.dart';

/// One entry on the AI baby timeline — covers a single calendar month.
class TimelineEntry {
  const TimelineEntry({
    required this.period,
    required this.heroImage,
    required this.images,
    required this.milestones,
    required this.caption,
    required this.ageLabel,
    this.faceChangeScore = 0.0,
  });

  /// First day of the month this entry covers.
  final DateTime period;

  /// The "hero" photo shown prominently at the top of the card (first photo
  /// in chronological order for this period).
  final GalleryImage heroImage;

  /// All baby photos captured during this period (sorted oldest-first).
  final List<GalleryImage> images;

  /// Automatically detected lifecycle milestones for this period.
  final List<BabyMilestone> milestones;

  /// AI-generated caption summarising this period.
  final String caption;

  /// Human-readable age label, e.g. "생후 3개월" or "2024년 3월".
  final String ageLabel;

  /// L2 distance of the average face-vector from the previous period.
  /// Higher value → more visible face change. 0.0 means no comparison data.
  final double faceChangeScore;

  /// Pretty header string: "YYYY년 MM월"
  String get periodLabel =>
      '${period.year}년 ${period.month.toString().padLeft(2, '0')}월';
}
