import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/gallery_image.dart';
import '../models/gallery_section.dart';
import '../viewmodels/gallery_view_model.dart';
import '../widgets/animations.dart';
import 'caption_screen.dart';
import 'enhancement_screen.dart';
import 'paywall_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({
    super.key,
    required this.sections,
    this.viewModel,
  });

  final List<GallerySection> sections;
  final GalleryViewModel? viewModel;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final Set<String> _selectedPaths = {};
  bool _isSelectMode = false;

  void _enterSelectMode(String path) {
    setState(() {
      _isSelectMode = true;
      _selectedPaths.add(path);
    });
  }

  void _exitSelectMode() {
    setState(() {
      _isSelectMode = false;
      _selectedPaths.clear();
    });
  }

  void _toggleSelection(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
        if (_selectedPaths.isEmpty) _isSelectMode = false;
      } else {
        _selectedPaths.add(path);
      }
    });
  }

  Future<void> _shareSelected() async {
    if (_selectedPaths.isEmpty) return;
    final xFiles = _selectedPaths.map((p) => XFile(p)).toList();
    await Share.shareXFiles(xFiles);
  }

  Future<void> _exportSelected(BuildContext context) async {
    if (_selectedPaths.isEmpty) return;

    final isPremium = widget.viewModel?.isPremium ?? false;

    if (!isPremium) {
      if (!mounted) return;
      final purchased = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaywallScreen(
            onPurchase: (monthly) => widget.viewModel!.upgradeToPremium(monthly),
            onRestore: () => widget.viewModel!.restorePremium(),
            isPremium: () => widget.viewModel?.isPremium ?? false,
          ),
        ),
      );
      // Abort if the user closed the paywall without purchasing.
      if (purchased != true || !mounted) return;
    }

    final paths = List<String>.of(_selectedPaths);
    _exitSelectMode();

    final successCount =
        await ServiceLocator().exportService.exportImages(paths);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          successCount > 0
              ? '$successCount장을 \'BabySnap AI\' 앨범에 저장했습니다 ✓'
              : '저장 실패: 갤러리 저장 권한을 확인해 주세요',
        ),
        backgroundColor:
            successCount > 0 ? AppTheme.primaryColor : Colors.redAccent,
        duration: const Duration(milliseconds: 2500),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _enhanceSelected(BuildContext context) async {
    if (_selectedPaths.isEmpty) return;

    final isPremium = widget.viewModel?.isPremium ?? false;
    if (!isPremium) {
      if (!mounted) return;
      final purchased = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaywallScreen(
            onPurchase: (monthly) => widget.viewModel!.upgradeToPremium(monthly),
            onRestore: () => widget.viewModel!.restorePremium(),
            isPremium: () => widget.viewModel?.isPremium ?? false,
          ),
        ),
      );
      if (purchased != true || !context.mounted) return;
    }

    // Enhance only the first selected image (one at a time for best UX).
    final path = _selectedPaths.first;
    _exitSelectMode();

    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EnhancementScreen(imagePath: path),
      ),
    );
  }

  Future<void> _excludeSelected(BuildContext context) async {
    if (widget.viewModel == null || _selectedPaths.isEmpty) return;
    final count = _selectedPaths.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('아기 사진 아님'),
        content: Text(
          count == 1
              ? '이 사진을 감지 결과에서 제외할까요?\n다음 스캔에서도 표시되지 않습니다.'
              : '선택한 $count장을 감지 결과에서 제외할까요?\n다음 스캔에서도 표시되지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('제외'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final paths = Set<String>.of(_selectedPaths);
    _exitSelectMode();
    for (final section in widget.sections) {
      for (final image in section.images) {
        if (paths.contains(image.path)) {
          await widget.viewModel!.excludeImage(image);
        }
      }
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count장을 감지 결과에서 제외했습니다'),
          duration: const Duration(milliseconds: 1400),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSelectMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitSelectMode();
      },
      child: Scaffold(
        appBar: _isSelectMode
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _exitSelectMode,
                ),
                title: Text('${_selectedPaths.length}장 선택됨'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share),
                    tooltip: '공유',
                    onPressed: _shareSelected,
                  ),
                  if (widget.viewModel != null)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'exclude') _excludeSelected(context);
                        if (value == 'export') _exportSelected(context);
                        if (value == 'enhance') _enhanceSelected(context);
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'enhance',
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFEC4899),
                                      Color(0xFF8B5CF6),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('✨',
                                    style: TextStyle(fontSize: 11)),
                              ),
                              const SizedBox(width: 10),
                              const Text('AI 사진 향상'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'export',
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppTheme.primaryColor,
                                      AppTheme.secondaryColor,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('✨',
                                    style: TextStyle(fontSize: 11)),
                              ),
                              const SizedBox(width: 10),
                              const Text('고화질 내보내기'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'exclude',
                          child: Row(
                            children: [
                              Icon(Icons.remove_circle_outline,
                                  color: Colors.redAccent, size: 20),
                              SizedBox(width: 8),
                              Text('아기 사진 아님 (제외)',
                                  style:
                                      TextStyle(color: Colors.redAccent)),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              )
            : AppBar(
                title: const Text('아기 사진 갤러리'),
                elevation: 0,
              ),
        body: widget.sections.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported_outlined,
                      size: 64,
                      color: AppTheme.primaryColor.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '아기 얼굴 사진이 없습니다',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              )
            : CustomScrollView(
                slivers: [
                  for (int sectionIndex = 0;
                      sectionIndex < widget.sections.length;
                      sectionIndex++) ...[
                    _buildSectionHeader(
                      context,
                      widget.sections[sectionIndex],
                      sectionIndex,
                    ),
                    _buildSectionGrid(
                      context,
                      widget.sections[sectionIndex],
                      sectionIndex,
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    GallerySection section,
    int sectionIndex,
  ) {
    return SliverToBoxAdapter(
      child: FadeInUpAnimation(
        delay: Duration(milliseconds: sectionIndex * 100),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                section.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${section.images.length}장',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionGrid(
    BuildContext context,
    GallerySection section,
    int sectionIndex,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final image = section.images[index];
            final isFavorite =
                widget.viewModel?.isFavorite(image.assetId) ?? false;
            final isSelected = _selectedPaths.contains(image.path);

            return ScaleAnimation(
              delay: Duration(
                milliseconds: sectionIndex * 100 + (index % 3) * 50,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_isSelectMode) {
                        _toggleSelection(image.path);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FullScreenImage(
                              imagePath: image.path,
                              heroTag: image.assetId,
                              viewModel: widget.viewModel,
                            ),
                          ),
                        );
                      }
                    },
                    onLongPress: () {
                      if (_isSelectMode) {
                        _toggleSelection(image.path);
                      } else if (widget.viewModel != null) {
                        _enterSelectMode(image.path);
                      }
                    },
                    child: Hero(
                      tag: image.assetId,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          image.file,
                          fit: BoxFit.cover,
                          cacheWidth: 300,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ),
                  ),
                  // Gradient overlay
                  IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.3),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  // Selection overlay
                  if (_isSelectMode)
                    IgnorePointer(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryColor.withValues(alpha: 0.4)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: isSelected
                              ? Border.all(
                                  color: AppTheme.primaryColor,
                                  width: 2.5,
                                )
                              : null,
                        ),
                      ),
                    ),
                  // Checkmark badge
                  if (_isSelectMode)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: IgnorePointer(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 150),
                          child: isSelected
                              ? Container(
                                  key: const ValueKey('checked'),
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                )
                              : Container(
                                  key: const ValueKey('unchecked'),
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  // Favorite button (hidden in select mode)
                  if (widget.viewModel != null && !_isSelectMode)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          widget.viewModel!.toggleFavorite(image);
                          setState(() {});
                          _showFeedback(context, isFavorite);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
          childCount: section.images.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
      ),
    );
  }

  void _showFeedback(BuildContext context, bool wasFavorite) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasFavorite ? '즐겨찾기에서 제거되었습니다' : '즐겨찾기에 추가되었습니다',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryColor,
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ignore: unused_element
  Future<void> _confirmExcludeImage(
    BuildContext context,
    GalleryImage image,
  ) async {
    final shouldExclude = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('아기 사진 아님'),
        content: const Text('이 사진을 감지 결과에서 제외할까요?\n다음 스캔에서도 표시되지 않습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('제외'),
          ),
        ],
      ),
    );

    if (shouldExclude != true || widget.viewModel == null) {
      return;
    }

    await widget.viewModel!.excludeImage(image);
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('감지 결과에서 제외했습니다'),
        duration: Duration(milliseconds: 1400),
      ),
    );
    setState(() {});
  }
}

class FullScreenImage extends StatelessWidget {
  const FullScreenImage({
    super.key,
    required this.imagePath,
    required this.heroTag,
    this.viewModel,
  });

  final String imagePath;
  final String heroTag;
  final GalleryViewModel? viewModel;

  Future<void> _share() async {
    await Share.shareXFiles([XFile(imagePath)]);
  }

  Future<void> _openCaption(BuildContext context) async {
    final isPremium = viewModel?.isPremium ?? false;
    if (!isPremium && viewModel != null) {
      final purchased = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaywallScreen(
            onPurchase: (monthly) => viewModel!.upgradeToPremium(monthly),
            onRestore: () => viewModel!.restorePremium(),
            isPremium: () => viewModel?.isPremium ?? false,
          ),
        ),
      );
      if (purchased != true || !context.mounted) return;
    }
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CaptionScreen(imagePath: imagePath),
      ),
    );
  }

  Future<void> _openEnhancement(BuildContext context) async {
    final isPremium = viewModel?.isPremium ?? false;
    if (!isPremium) {
      final purchased = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaywallScreen(
            onPurchase: (monthly) => viewModel!.upgradeToPremium(monthly),
            onRestore: () => viewModel!.restorePremium(),
            isPremium: () => viewModel?.isPremium ?? false,
          ),
        ),
      );
      if (purchased != true || !context.mounted) return;
    }
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EnhancementScreen(imagePath: imagePath),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('이미지 보기'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: 'AI 캡션',
            onPressed: () => _openCaption(context),
          ),
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            tooltip: 'AI 향상',
            onPressed: () => _openEnhancement(context),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: '공유',
            onPressed: _share,
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 3.0,
            child: Image.file(
              File(imagePath),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

