import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'animations.dart';

class SkeletonLoading extends StatelessWidget {
  const SkeletonLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class ScanProgressSkeleton extends StatelessWidget {
  const ScanProgressSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Progress bar skeleton
        ShimmerLoading(
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Status text skeleton
        ShimmerLoading(
          child: Container(
            height: 16,
            width: 200,
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}

class GalleryGridSkeleton extends StatelessWidget {
  const GalleryGridSkeleton({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return SkeletonLoading(
          width: double.infinity,
          height: 150,
          borderRadius: 12,
        );
      },
    );
  }
}

class HomeSectionSkeleton extends StatelessWidget {
  const HomeSectionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Title skeleton
        ShimmerLoading(
          child: Container(
            height: 24,
            width: 150,
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Description skeleton
        ShimmerLoading(
          child: Container(
            height: 16,
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Card skeleton
        ShimmerLoading(
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }
}
