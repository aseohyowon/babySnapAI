import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/services/milestone_service.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/baby_milestone.dart';
import '../../domain/entities/gallery_image.dart';
import '../../domain/entities/timeline_entry.dart';
import '../viewmodels/gallery_view_model.dart';
import '../viewmodels/timeline_view_model.dart';
import 'gallery_screen.dart';

/// Full-screen scrollable baby growth timeline.
///
/// Receives a [GalleryViewModel] as its data source; computes timeline
/// entries on first build and whenever the ViewModel's images change.
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key, required this.viewModel});

  final GalleryViewModel viewModel;

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  late final TimelineViewModel _timelineVM;

  @override
  void initState() {
    super.initState();
    _timelineVM = TimelineViewModel(MilestoneService());
    // Build synchronously — fast for typical gallery sizes.
    _timelineVM.buildFromImages(
      widget.viewModel.displayImages,
      activeProfile: widget.viewModel.activeProfile,
    );
  }

  @override
  void dispose() {
    _timelineVM.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('아기 성장 타임라인'),
        backgroundColor: AppTheme.surfaceColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '타임라인 새로고침',
            onPressed: () => _timelineVM.buildFromImages(
              widget.viewModel.displayImages,
              activeProfile: widget.viewModel.activeProfile,
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _timelineVM,
        builder: (context, _) {
          if (_timelineVM.isBuilding) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_timelineVM.isEmpty) {
            return _EmptyTimelineState();
          }
          return _TimelineList(entries: _timelineVM.entries);
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Empty state
// ────────────────────────────────────────────────────────────────────────────

class _EmptyTimelineState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timeline,
              size: 80,
              color: AppTheme.primaryColor.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 20),
            Text(
              '아직 타임라인을 만들 수 없어요',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '갤러리를 스캔하여 아기 사진을 찾아보세요.\n사진이 많을수록 더 풍성한 타임라인이 만들어져요.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Scrollable list
// ────────────────────────────────────────────────────────────────────────────

class _TimelineList extends StatelessWidget {
  const _TimelineList({required this.entries});

  final List<TimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 12, bottom: 40),
      itemCount: entries.length,
      itemBuilder: (ctx, i) => _TimelineCard(
        entry: entries[i],
        isLast: i == entries.length - 1,
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Single timeline card
// ────────────────────────────────────────────────────────────────────────────

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({
    required this.entry,
    required this.isLast,
  });

  final TimelineEntry entry;
  final bool isLast;

  static void _openFullScreen(BuildContext context, GalleryImage image) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImage(
          imagePath: image.path,
          heroTag: 'timeline_${image.assetId}',
        ),
      ),
    );
  }

  static void _showMonthSheet(BuildContext context, TimelineEntry entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${entry.periodLabel} · ${entry.images.length}장',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(8),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: entry.images.length,
                itemBuilder: (gridCtx, i) {
                  final img = entry.images[i];
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _openFullScreen(context, img);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        File(img.path),
                        fit: BoxFit.cover,
                        cacheWidth: 300,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppTheme.cardColor,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white24,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Warm amber tint for age-stage colour coding
  Color _stageColor() {
    // 0 = newborn (purple), 1 = infant (pink-red), 2 = toddler (amber)
    final months =
        (entry.period.year * 12 + entry.period.month);
    // Just use a gradient from primary → secondary → accent over 36 months
    if (months % 3 == 0) return AppTheme.primaryColor;
    if (months % 3 == 1) return AppTheme.secondaryColor;
    return AppTheme.accentColor;
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = _stageColor();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left: timeline spine ────────────────────────────────────
          SizedBox(
            width: 56,
            child: Column(
              children: [
                // Dot
                Container(
                  margin: const EdgeInsets.only(top: 18),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                    boxShadow: [
                      BoxShadow(
                        color: dotColor.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.circle, size: 8, color: Colors.white),
                ),
                // Line below dot (not shown for last item)
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            dotColor.withValues(alpha: 0.8),
                            AppTheme.cardColor.withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Right: card content ─────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  // Age label + period
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: dotColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: dotColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          entry.ageLabel,
                          style: TextStyle(
                            color: dotColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        entry.periodLabel,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Hero image — tappable
                  GestureDetector(
                    onTap: () => _openFullScreen(context, entry.heroImage),
                    child: _HeroImage(image: entry.heroImage),
                  ),
                  const SizedBox(height: 10),

                  // Milestone badges
                  if (entry.milestones.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: entry.milestones
                          .map((m) => _MilestoneBadge(milestone: m))
                          .toList(),
                    ),
                  if (entry.milestones.isNotEmpty) const SizedBox(height: 10),

                  // Caption
                  Text(
                    entry.caption,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Photo strip — thumbnails tappable
                  _PhotoStrip(
                    entry: entry,
                    onThumbnailTap: (img) => _openFullScreen(context, img),
                    onOverflowTap: () => _showMonthSheet(context, entry),
                  ),

                  // Growth indicator
                  if (entry.faceChangeScore > 0.30)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _GrowthIndicator(score: entry.faceChangeScore),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Hero image widget
// ────────────────────────────────────────────────────────────────────────────

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.image});

  final GalleryImage image;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Image.file(
          File(image.path),
          fit: BoxFit.cover,
          cacheWidth: 800,
          errorBuilder: (_, __, ___) => Container(
            color: AppTheme.cardColor,
            child: const Center(
              child: Icon(Icons.broken_image_outlined,
                  color: Colors.white24, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Milestone badge
// ────────────────────────────────────────────────────────────────────────────

class _MilestoneBadge extends StatelessWidget {
  const _MilestoneBadge({required this.milestone});

  final BabyMilestone milestone;

  Color _badgeColor() {
    switch (milestone.type) {
      case BabyMilestoneType.firstCapture:
        return const Color(0xFF6366F1);
      case BabyMilestoneType.hundredDays:
        return const Color(0xFFF59E0B);
      case BabyMilestoneType.firstBirthday:
        return const Color(0xFFEC4899);
      case BabyMilestoneType.secondBirthday:
        return const Color(0xFF8B5CF6);
      case BabyMilestoneType.thirdBirthday:
        return const Color(0xFF10B981);
      case BabyMilestoneType.mostPhotos:
        return const Color(0xFF3B82F6);
      case BabyMilestoneType.growthChange:
        return const Color(0xFF06B6D4);
      case BabyMilestoneType.latestCapture:
        return const Color(0xFFEC4899);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _badgeColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(milestone.emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text(
            milestone.displayLabel,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Photo count chip + horizontal thumbnail strip
// ────────────────────────────────────────────────────────────────────────────

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({
    required this.entry,
    this.onThumbnailTap,
    this.onOverflowTap,
  });

  final TimelineEntry entry;
  final void Function(GalleryImage)? onThumbnailTap;
  final VoidCallback? onOverflowTap;

  @override
  Widget build(BuildContext context) {
    final extraCount = entry.images.length - 1; // hero already shown above
    if (extraCount <= 0) {
      return Text(
        '1장의 사진',
        style:
            TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11),
      );
    }

    // Show up to 5 thumbnails (+ overflow chip if more)
    final thumbs = entry.images.skip(1).take(5).toList();
    final overflow = extraCount > 5 ? extraCount - 5 : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${entry.images.length}장의 사진',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 64,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ...thumbs.map(
                (img) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: onThumbnailTap != null
                        ? () => onThumbnailTap!(img)
                        : null,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(img.path),
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        cacheWidth: 128,
                        errorBuilder: (_, __, ___) => Container(
                          width: 64,
                          height: 64,
                          color: AppTheme.cardColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (overflow > 0)
                GestureDetector(
                  onTap: onOverflowTap,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '+$overflow',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const Text(
                            '더보기',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Growth change indicator bar
// ────────────────────────────────────────────────────────────────────────────

class _GrowthIndicator extends StatelessWidget {
  const _GrowthIndicator({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    // Normalise to 0–1 (scores > 1.0 are unusually large, clamp to 1)
    final normalised = (score / 1.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF06B6D4).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.trending_up, color: Color(0xFF06B6D4), size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '이번 달 얼굴 변화가 뚜렷해요',
              style: TextStyle(color: Color(0xFF06B6D4), fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: LinearProgressIndicator(
              value: normalised,
              backgroundColor:
                  const Color(0xFF06B6D4).withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF06B6D4),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}
