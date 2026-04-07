import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/auto_album.dart';
import '../../domain/entities/gallery_image.dart';
import '../models/gallery_section.dart';
import '../viewmodels/auto_album_view_model.dart';
import '../viewmodels/gallery_view_model.dart';
import 'gallery_screen.dart';

class AutoAlbumsScreen extends StatefulWidget {
  const AutoAlbumsScreen({
    super.key,
    required this.images,
    this.galleryViewModel,
  });

  final List<GalleryImage> images;
  final GalleryViewModel? galleryViewModel;

  @override
  State<AutoAlbumsScreen> createState() => _AutoAlbumsScreenState();
}

class _AutoAlbumsScreenState extends State<AutoAlbumsScreen> {
  late final AutoAlbumViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = AutoAlbumViewModel();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _generate() => _viewModel.generate(widget.images);

  void _openAlbum(AutoAlbum album) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GalleryScreen(
          sections: [GallerySection(title: '${album.emoji} ${album.title}', images: album.images)],
          viewModel: widget.galleryViewModel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('자동 앨범'),
        actions: [
          AnimatedBuilder(
            animation: _viewModel,
            builder: (_, __) => IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '다시 생성',
              onPressed: _viewModel.isGenerating ? null : _generate,
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, _) {
          switch (_viewModel.state) {
            case AutoAlbumState.idle:
              return _buildIdleState();
            case AutoAlbumState.generating:
              return _buildGeneratingState();
            case AutoAlbumState.done:
              return _buildAlbumGrid();
            case AutoAlbumState.error:
              return _buildErrorState();
          }
        },
      ),
    );
  }

  // ── Idle ─────────────────────────────────────────────────────────────────

  Widget _buildIdleState() {
    final babyCount = widget.images.where((i) => i.isBaby).length;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.photo_album, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 28),
            const Text(
              'AI 자동 앨범 생성',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              '촬영 시간, 장면 유형, 이벤트를 자동 감지해\n$babyCount장의 사진을 앨범으로 분류해 드려요',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _buildFeatureRow(),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: babyCount == 0 ? null : _generate,
                icon: const Icon(Icons.auto_awesome),
                label: Text(babyCount == 0 ? '분류할 사진이 없습니다' : '앨범 생성 시작'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow() {
    final items = [
      (Icons.schedule, '시간대별\n이벤트'),
      (Icons.landscape, '장면\n인식'),
      (Icons.merge_type, '유사 장면\n자동 병합'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: items.map((t) {
        return Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF06B6D4).withValues(alpha: 0.3),
                ),
              ),
              child: Icon(t.$1, color: const Color(0xFF06B6D4), size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              t.$2,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      }).toList(),
    );
  }

  // ── Generating ──────────────────────────────────────────────────────────

  Widget _buildGeneratingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: CircularProgressIndicator(
                value: _viewModel.progressFraction == 0
                    ? null
                    : _viewModel.progressFraction,
                strokeWidth: 5,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF06B6D4),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              '앨범 생성 중...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '이벤트 분석 ${_viewModel.progress} / ${_viewModel.total}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _viewModel.progressFraction,
                minHeight: 6,
                backgroundColor: AppTheme.cardColor,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF06B6D4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Album grid ──────────────────────────────────────────────────────────

  Widget _buildAlbumGrid() {
    final albums = _viewModel.albums;

    if (albums.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_album_outlined,
                size: 64, color: Colors.white.withValues(alpha: 0.25)),
            const SizedBox(height: 16),
            const Text(
              '생성된 앨범이 없습니다',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 4),
            Text(
              '사진이 최소 2장 이상인 이벤트부터 앨범이 생성돼요',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.photo_album, color: Color(0xFF06B6D4), size: 18),
                const SizedBox(width: 8),
                Text(
                  '${albums.length}개 앨범 생성됨',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return _AlbumCard(
                  album: albums[index],
                  onTap: () => _openAlbum(albums[index]),
                );
              },
              childCount: albums.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  // ── Error ────────────────────────────────────────────────────────────────

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 56),
            const SizedBox(height: 16),
            Text(
              _viewModel.errorMessage ?? '오류가 발생했습니다',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _generate,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Album card ───────────────────────────────────────────────────────────────

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({required this.album, required this.onTap});

  final AutoAlbum album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typeColor = album.type.color;
    final dateLabel = _formatDateRange(album.date, album.endDate);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Cover photo
            Image.file(
              File(album.coverImage.path),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppTheme.cardColor,
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: Colors.white24,
                  size: 40,
                ),
              ),
            ),

            // Gradient overlay at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 90,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Top: photo count badge
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${album.images.length}장',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // Top-left: type color accent dot
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: typeColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: typeColor.withValues(alpha: 0.7),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),

            // Bottom: title + date
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        album.emoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          album.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateLabel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateRange(DateTime start, DateTime end) {
    String fmt(DateTime d) =>
        '${d.year.toString().substring(2)}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return fmt(start);
    }
    return '${fmt(start)} – ${fmt(end)}';
  }
}
