import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/photo_ranking_service.dart';
import '../../domain/entities/gallery_image.dart';
import '../viewmodels/best_photos_view_model.dart';
import '../viewmodels/gallery_view_model.dart';
import 'gallery_screen.dart';
import 'paywall_screen.dart';

class BestPhotosScreen extends StatefulWidget {
  const BestPhotosScreen({
    super.key,
    required this.images,
    this.galleryViewModel,
  });

  final List<GalleryImage> images;
  final GalleryViewModel? galleryViewModel;

  @override
  State<BestPhotosScreen> createState() => _BestPhotosScreenState();
}

class _BestPhotosScreenState extends State<BestPhotosScreen> {
  late final BestPhotosViewModel _viewModel;

  /// True after the paywall has been triggered for the current analysis run.
  /// Reset every time a new analysis starts so the prompt appears once per session.
  bool _paywallShown = false;

  @override
  void initState() {
    super.initState();
    _viewModel = BestPhotosViewModel();
        // Auto-start analysis so the user doesn't need an extra tap.
        WidgetsBinding.instance.addPostFrameCallback((_) => _startAnalysis());
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _startAnalysis({bool clearCache = false}) {
    if (clearCache) PhotoRankingService.clearCache();
    _paywallShown = false; // reset so paywall shows once for each new analysis
    _viewModel.analyze(widget.images);
  }

  void _openFullScreen(PhotoScore score) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImage(
          imagePath: score.image.path,
          heroTag: 'best_${score.image.assetId}',
          viewModel: widget.galleryViewModel,
        ),
      ),
    );
  }

  /// Opens the PaywallScreen. On successful purchase/restore forces a rebuild
  /// so the blurred overlay is replaced with the real results.
  Future<void> _openPaywall() async {
    if (!mounted) return;
    final vm = widget.galleryViewModel;
    if (vm == null) return;
    final acquired = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaywallScreen(
          onPurchase: (monthly) => vm.upgradeToPremium(monthly),
          onRestore: vm.restorePremium,
          isPremium: () => vm.isPremium,
        ),
      ),
    );
    if (acquired == true && mounted) {
      setState(() {}); // re-evaluate isPremium -> unblur results
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('베스트 사진 TOP 10'),
        actions: [
          AnimatedBuilder(
            animation: _viewModel,
            builder: (_, __) => IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '다시 분석',
              onPressed: _viewModel.isAnalyzing
                  ? null
                  : () => _startAnalysis(clearCache: true),
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, _) {
          switch (_viewModel.state) {
            case BestPhotosState.idle:
              return _buildIdleState();
            case BestPhotosState.analyzing:
              // If we already have partial results (from cache or completed
              // batches), show the live-updating grid with a compact progress
              // banner instead of a full-screen spinner.
              if (_viewModel.scores.isNotEmpty) {
                final isPremium =
                    widget.galleryViewModel?.isPremium ?? false;
                return Column(
                  children: [
                    _buildProgressBanner(),
                    Expanded(
                      child: isPremium
                          ? _buildResultsContent(_viewModel.scores)
                          : _buildLockedResults(_viewModel.scores),
                    ),
                  ],
                );
              }
              return _buildAnalyzingState();
            case BestPhotosState.done:
              final isPremium =
                  widget.galleryViewModel?.isPremium ?? false;
              if (!isPremium && !_paywallShown) {
                _paywallShown = true;
                WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _openPaywall());
              }
              return _buildResultsGrid();
            case BestPhotosState.error:
              return _buildErrorState();
          }
        },
      ),
    );
  }

  // ── States ─────────────────────────────────────────────────────────────

  /// Compact top banner shown while analysis is running but partial results
  /// are already visible in the grid below.
  Widget _buildProgressBanner() {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (_, __) => Container(
        color: AppTheme.backgroundColor,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFFFBBF24)),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'AI 분석 중… ${_viewModel.progress} / ${_viewModel.total}장',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.80),
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(_viewModel.progressFraction * 100).round()}%',
                  style: const TextStyle(
                    color: Color(0xFFFBBF24),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _viewModel.progressFraction,
                minHeight: 4,
                backgroundColor: AppTheme.cardColor,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFFFBBF24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdleState() {
    final babyCount = widget.images.length;
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
                  colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFBBF24).withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.emoji_events, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 28),
            const Text(
              'AI 베스트 사진 분석',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              '미소, 선명도, 얼굴 크기를 AI로 분석해\n최고의 사진 $babyCount장 중 TOP 10을 골라드려요',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            _buildLegendRow(),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: babyCount == 0 ? null : _startAnalysis,
                icon: const Icon(Icons.auto_awesome),
                label: Text(babyCount == 0 ? '분석할 사진이 없습니다' : '분석 시작'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFBBF24),
                  foregroundColor: Colors.black,
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

  Widget _buildLegendRow() {
    final items = [
      ('😊', '미소', '25%'),
      ('🔍', '선명도', '30%'),
      ('👶', '얼굴크기', '20%'),
      ('👁️', '눈 뜨임', '15%'),
      ('☀️', '밝기', '10%'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: items
          .map(
            (t) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Column(
                children: [
                  Text(t.$1, style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 2),
                  Text(
                    t.$2,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    t.$3,
                    style: const TextStyle(
                      color: Color(0xFFFBBF24),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildAnalyzingState() {
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
                  Color(0xFFFBBF24),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              '사진 분석 중...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_viewModel.progress} / ${_viewModel.total}장 완료',
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
                  Color(0xFFFBBF24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsGrid() {
    final isPremium = widget.galleryViewModel?.isPremium ?? false;
    final scores = _viewModel.scores;
    if (scores.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              '분석 가능한 사진이 없습니다',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    if (!isPremium) {
      return _buildLockedResults(scores);
    }
    return _buildResultsContent(scores);
  }

  /// The real results grid shown to premium users.
  Widget _buildResultsContent(List<PhotoScore> scores) {
    return CustomScrollView(
      slivers: [
        // Top 3 podium section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: _buildPodium(scores),
          ),
        ),
        // Remaining cards
        if (scores.length > 3)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final score = scores[index + 3];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RankListTile(
                      score: score,
                      onTap: () => _openFullScreen(score),
                    ),
                  );
                },
                childCount: scores.length - 3,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  /// Blurred results with a centered upgrade card shown to non-premium users.
  Widget _buildLockedResults(List<PhotoScore> scores) {
    return Stack(
      children: [
        // Results blurred in the background to hint at content
        AbsorbPointer(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: _buildResultsContent(scores),
          ),
        ),
        // Dark scrim for readability
        Container(color: Colors.black.withValues(alpha: 0.45)),
        // Upgrade card centred over the blur
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.45),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.25),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.secondaryColor
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child:
                        const Icon(Icons.lock, color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Premium 전용 기능',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'AI 베스트 사진 분석은\nPremium 사용자만 확인할 수 있습니다',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openPaywall,
                      icon: const Icon(Icons.star, size: 18),
                      label: const Text(
                        '프리미엄으로 업그레이드',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      '나중에',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

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
              onPressed: _startAnalysis,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Podium for ranks 1–3 ───────────────────────────────────────────────

  Widget _buildPodium(List<PhotoScore> scores) {
    const podiumColors = [
      Color(0xFFFBBF24), // Gold #1
      Color(0xFF94A3B8), // Silver #2
      Color(0xFFCD7C2F), // Bronze #3
    ];

    // Arrange as 2, 1, 3 so #1 is in the center.
    final arranged = <int>[1, 0, 2]
        .where((i) => i < scores.length)
        .map((i) => scores[i])
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          '🏆 TOP 3',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: arranged.map((score) {
            final rank = score.rank;
            final isFirst = rank == 1;
            final colorIdx = rank - 1;
            final medalColor = podiumColors[colorIdx];

            return Expanded(
              child: GestureDetector(
                onTap: () => _openFullScreen(score),
                child: Column(
                  children: [
                    // Crown for #1
                    if (isFirst)
                      const Text('👑', style: TextStyle(fontSize: 22)),
                    // Photo
                    Container(
                      height: isFirst ? 150 : 120,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: medalColor, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: medalColor.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.file(
                          File(score.image.path),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppTheme.cardColor,
                            child: const Icon(Icons.broken_image,
                                color: Colors.white24),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Rank badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: medalColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '#$rank  ${score.totalPct}',
                        style: TextStyle(
                          color: isFirst ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _SmileChip(smile: score.smileScore),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        const Divider(color: Colors.white12),
      ],
    );
  }
}

// ── List tile for ranks 4–10 ─────────────────────────────────────────────

class _RankListTile extends StatelessWidget {
  const _RankListTile({required this.score, required this.onTap});

  final PhotoScore score;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 88,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // Rank number
            SizedBox(
              width: 32,
              child: Text(
                '#${score.rank}',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 68,
                height: 68,
                child: Image.file(
                  File(score.image.path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppTheme.surfaceColor,
                    child:
                        const Icon(Icons.broken_image, color: Colors.white24),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Score details
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _ScoreChip(
                          label: score.totalPct,
                          color: const Color(0xFFFBBF24)),
                      const SizedBox(width: 6),
                      _ScoreChip(
                          label: '😊 ${score.smilePct}',
                          color: const Color(0xFFEC4899)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _ScoreChip(
                          label: '🔍 ${score.sharpPct}',
                          color: AppTheme.primaryColor),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Small reusable widgets ────────────────────────────────────────────────

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SmileChip extends StatelessWidget {
  const _SmileChip({required this.smile});

  final double smile;

  @override
  Widget build(BuildContext context) {
    final pct = (smile * 100).round();
    Color color;
    if (pct >= 70) {
      color = const Color(0xFF34D399); // green
    } else if (pct >= 40) {
      color = const Color(0xFFFBBF24); // yellow
    } else {
      color = Colors.white38;
    }
    return Text(
      '😊 $pct%',
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
