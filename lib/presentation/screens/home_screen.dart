import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/di/service_locator.dart';
import '../../core/locale/app_locale.dart';
import '../../core/locale/app_strings.dart';
import '../../core/services/ad_service.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/baby_profile.dart';
import '../models/gallery_section.dart';
import '../viewmodels/gallery_view_model.dart';
import '../widgets/animations.dart';
import '../widgets/skeleton_loading.dart';
import 'auto_albums_screen.dart';
import 'baby_profile_screen.dart';
import 'best_photos_screen.dart';
import 'gallery_screen.dart';
import 'paywall_screen.dart';
import 'timeline_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.viewModel,
    this.autoInitialize = true,
  });

  final GalleryViewModel? viewModel;
  final bool autoInitialize;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final GalleryViewModel _viewModel;
  late final bool _ownsViewModel;

  // ── AdMob ──────────────────────────────────────────────────────────────
  BannerAd? _bannerAd;
  bool _bannerAdIsLoaded = false;

  @override
  void initState() {
    super.initState();

    _ownsViewModel = widget.viewModel == null;
    _viewModel = widget.viewModel ?? _buildViewModel();

    if (widget.autoInitialize) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _viewModel.initialize();
      });
    }

    // Load banner ad.
    _bannerAd = AdService.instance.createBanner(
      onLoaded: () {
        if (mounted) setState(() => _bannerAdIsLoaded = true);
      },
    );
    // Warm up interstitial (will only show after 2nd gallery tap).
    AdService.instance.loadInterstitial();
  }

  GalleryViewModel _buildViewModel() {
    final locator = ServiceLocator();
    return GalleryViewModel(
      locator.getImagesWithFacesUsecase,
      locator.getFavoritesUsecase,
      locator.getPremiumStatusUsecase,
      locator.manageBabyProfilesUsecase,
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    if (_ownsViewModel) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BabySnap AI'),
        actions: [
          // Language toggle button
          IconButton(
            icon: const Icon(Icons.language),
            tooltip: AppStrings.current().langToggleTooltip,
            onPressed: AppLocaleNotifier.instance.toggle,
          ),
          if (_viewModel.isPremium)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Premium ✨',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, _) {
          if (_viewModel.isLoading && _viewModel.images.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: _buildLoadingSkeleton(),
            );
          }

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header with animation
                  FadeInUpAnimation(
                    delay: const Duration(milliseconds: 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.current().homeHeadline,
                          style: Theme.of(context).textTheme.displayLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppStrings.current().homeSubtitle,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Last scan info
                  if (_viewModel.lastScanAt != null)
                    FadeInUpAnimation(
                      delay: const Duration(milliseconds: 150),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.update, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              '${AppStrings.current().lastScan}: ${_formatDateTime(_viewModel.lastScanAt!)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_viewModel.lastScanAt != null) const SizedBox(height: 16),

                  // Scan button
                  FadeInUpAnimation(
                    delay: const Duration(milliseconds: 200),
                    child: ElevatedButton.icon(
                      onPressed: _viewModel.isScanning
                          ? null
                          : () => _viewModel.scanGallery(forceRescan: false),
                      icon: _viewModel.isScanning
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(
                        _viewModel.isScanning
                            ? AppStrings.current().scanning
                            : AppStrings.current().scanButton,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Progress indicator
                  if (_viewModel.progress != null)
                    FadeInUpAnimation(
                      delay: const Duration(milliseconds: 250),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: LinearProgressIndicator(
                              value: _viewModel.progress!.fraction,
                              minHeight: 8,
                              backgroundColor: AppTheme.cardColor,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _viewModel.progress!.message,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                '${_viewModel.progress!.processed}/${_viewModel.progress!.total}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (_viewModel.progress != null) const SizedBox(height: 24),

                  // Error message
                  if (_viewModel.errorMessage != null)
                    FadeInUpAnimation(
                      delay: const Duration(milliseconds: 300),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _viewModel.errorMessage!,
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_viewModel.errorMessage != null) const SizedBox(height: 16),

                  // Baby profile filter section
                  FadeInUpAnimation(
                    delay: const Duration(milliseconds: 280),
                    child: _buildProfileSection(),
                  ),
                  const SizedBox(height: 16),

                  // Permission error
                  if (!_viewModel.hasPermission)
                    FadeInUpAnimation(
                      delay: const Duration(milliseconds: 350),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.secondaryColor),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lock_outline),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                AppStrings.current().permissionNeeded,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!_viewModel.hasPermission) const SizedBox(height: 20),

                  // Stats
                  FadeInUpAnimation(
                    delay: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withValues(alpha: 0.2),
                            AppTheme.secondaryColor.withValues(alpha: 0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatCard(
                            icon: Icons.image,
                            value: _viewModel.images.length.toString(),
                            label: AppStrings.current().detectedPhotos,
                          ),
                          _buildStatCard(
                            icon: Icons.calendar_month,
                            value: _viewModel.sections.length.toString(),
                            label: AppStrings.current().monthlyGroups,
                          ),
                          _buildStatCard(
                            icon: Icons.favorite,
                            value: _viewModel.favoriteAssetIds.length.toString(),
                            label: AppStrings.current().favorites,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Premium upgrade card (only shown for free users)
                  if (!_viewModel.isPremium)
                    FadeInUpAnimation(
                      delay: const Duration(milliseconds: 320),
                      child: _buildPremiumUpgradeCard(),
                    ),
                  if (!_viewModel.isPremium) const SizedBox(height: 16),

                  // Gallery sections or view all button
                  if (_viewModel.images.isNotEmpty) ...[
                    FadeInUpAnimation(
                      delay: const Duration(milliseconds: 350),
                      child: ElevatedButton(
                        onPressed: () => _openGallery(_viewModel.sections),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.grid_on),
                              SizedBox(width: 8),
                              Text(AppStrings.current().viewAllPhotos),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Timeline card
                    FadeInUpAnimation(
                      delay: const Duration(milliseconds: 380),
                      child: _buildTimelineCard(),
                    ),
                    const SizedBox(height: 12),
                    // Best photos card
                    FadeInUpAnimation(
                      delay: const Duration(milliseconds: 410),
                      child: _buildBestPhotosCard(),
                    ),
                    const SizedBox(height: 12),
                    // Auto albums card
                    FadeInUpAnimation(
                      delay: const Duration(milliseconds: 440),
                      child: _buildAutoAlbumsCard(),
                    ),
                  ],

                  // Empty state
                  if (_viewModel.sections.isEmpty && !_viewModel.isLoading)
                    FadeInUpAnimation(
                      delay: const Duration(milliseconds: 300),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          children: [
                            Icon(
                              Icons.child_care,
                              size: 80,
                              color: AppTheme.primaryColor.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              AppStrings.current().noPhotosYet,
                              style: Theme.of(context).textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppStrings.current().noPhotosHint,
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
      // ── Banner ad anchored at the bottom ─────────────────────────────
      bottomNavigationBar: _bannerAdIsLoaded && _bannerAd != null
          ? SafeArea(
              child: SizedBox(
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            )
          : null,
    );
  }

  Widget _buildProfileSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.face, color: Color(0xFF818CF8), size: 20),
              const SizedBox(width: 8),
              Text(
                AppStrings.current().childFilter,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _viewModel.images.isEmpty
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                BabyProfileScreen(viewModel: _viewModel),
                          ),
                        ),
                icon: const Icon(Icons.add, size: 16),
                label: Text(AppStrings.current().register),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF818CF8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
          if (_viewModel.profiles.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                AppStrings.current().profileHint,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                ),
              ),
            )
          else ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _viewModel.profiles.map((profile) {
                  final isActive = _viewModel.activeProfile?.id == profile.id;
                  return GestureDetector(
                    onTap: () =>
                        _viewModel.setActiveProfile(isActive ? null : profile),
                    onLongPress: () => _showProfileOptions(profile),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundImage: FileImage(
                                  File(profile.referencePhotoPath),
                                ),
                                backgroundColor: const Color(0xFF1E293B),
                              ),
                              if (isActive)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF6366F1)
                                          .withValues(alpha: 0.7),
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.name,
                            style: TextStyle(
                              color: isActive
                                  ? const Color(0xFF818CF8)
                                  : Colors.white70,
                              fontSize: 11,
                              fontWeight: isActive
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            if (_viewModel.activeProfile != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openFilteredGallery,
                  icon: const Icon(Icons.face_retouching_natural, size: 18),
                  label: Text(AppStrings.current().photosByProfile(_viewModel.activeProfile!.name)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<bool> _ensurePremium() async {
    if (_viewModel.isPremium) return true;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaywallScreen(
          onPurchase: (monthly) => _viewModel.upgradeToPremium(monthly),
          onRestore: _viewModel.restorePremium,
          isPremium: () => _viewModel.isPremium,
        ),
      ),
    );
    return result == true;
  }

  Future<void> _openPaywall() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaywallScreen(
          onPurchase: (monthly) => _viewModel.upgradeToPremium(monthly),
          onRestore: _viewModel.restorePremium,
          isPremium: () => _viewModel.isPremium,
        ),
      ),
    );
    // ViewModel already notified -> AnimatedBuilder will rebuild.
  }

  void _openGallery(List<GallerySection> sections) {
    void navigate() {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              GalleryScreen(sections: sections, viewModel: _viewModel),
        ),
      );
    }

    if (_viewModel.isPremium) {
      navigate();
    } else {
      AdService.instance.showInterstitialThenRun(navigate);
    }
  }

  Future<void> _openTimeline() async {
    if (_viewModel.images.isEmpty) return;
    if (!await _ensurePremium()) return;
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TimelineScreen(viewModel: _viewModel),
      ),
    );
  }

  Widget _buildTimelineCard() {
    return GestureDetector(
      onTap: _openTimeline,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFEC4899).withValues(alpha: 0.15),
              const Color(0xFF8B5CF6).withValues(alpha: 0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFEC4899).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.auto_awesome_mosaic,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.current().timelineTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppStrings.current().timelineSubtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            _viewModel.isPremium
                ? const Icon(Icons.chevron_right, color: Colors.white38)
                : _PremiumLockBadge(),
          ],
        ),
      ),
    );
  }

  Future<void> _openAutoAlbums() async {
    if (_viewModel.images.isEmpty) return;
    if (!await _ensurePremium()) return;
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AutoAlbumsScreen(
          images: _viewModel.images,
          galleryViewModel: _viewModel,
        ),
      ),
    );
  }

  Widget _buildAutoAlbumsCard() {
    return GestureDetector(
      onTap: _openAutoAlbums,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF06B6D4).withValues(alpha: 0.15),
              const Color(0xFF0891B2).withValues(alpha: 0.10),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF06B6D4).withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.photo_album, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.current().autoAlbumTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppStrings.current().autoAlbumSubtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            _viewModel.isPremium
                ? const Icon(Icons.chevron_right, color: Colors.white38)
                : _PremiumLockBadge(),
          ],
        ),
      ),
    );
  }

  Future<void> _openBestPhotos() async {
    if (_viewModel.images.isEmpty) return;
    if (!mounted) return;
    // Non-premium users are allowed to enter — BestPhotosScreen shows a
    // blurred preview and the paywall when analysis completes.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BestPhotosScreen(
          images: _viewModel.images,
          galleryViewModel: _viewModel,
        ),
      ),
    );
  }

  Widget _buildBestPhotosCard() {
    return GestureDetector(
      onTap: _openBestPhotos,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFBBF24).withValues(alpha: 0.15),
              const Color(0xFFF59E0B).withValues(alpha: 0.10),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFBBF24).withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.emoji_events, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.current().bestPhotosTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppStrings.current().bestPhotosSubtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            _viewModel.isPremium
                ? const Icon(Icons.chevron_right, color: Colors.white38)
                : _PremiumLockBadge(),
          ],
        ),
      ),
    );
  }

  void _openFilteredGallery() {
    final filtered = _viewModel.displaySections;
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.current().profilePhotosNotFound(_viewModel.activeProfile!.name),
          ),
          backgroundColor: const Color(0xFF374151),
        ),
      );
      return;
    }
    _openGallery(filtered);
  }

  Future<void> _showProfileOptions(BabyProfile profile) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                profile.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            ListTile(
              leading: const Icon(Icons.add_photo_alternate_outlined,
                  color: Color(0xFF818CF8)),
              title: Text(AppStrings.current().addMorePhotos,
                  style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                AppStrings.current().registeredPhotos(profile.faceVectors.length),
                style:
                    const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              onTap: () => Navigator.pop(ctx, 'add'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: Text(AppStrings.current().deleteProfile,
                  style: const TextStyle(color: Colors.redAccent)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (action == 'add') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BabyProfileScreen(
            viewModel: _viewModel,
            existingProfile: profile,
          ),
        ),
      );
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text(AppStrings.current().deleteProfileTitle(profile.name),
              style: const TextStyle(color: Colors.white)),
          content: Text(AppStrings.current().deleteProfileConfirm,
              style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppStrings.current().cancel,
                  style: const TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppStrings.current().delete,
                  style: const TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) {
        await _viewModel.deleteProfile(profile.id);
      }
    }
  }

  Widget _buildPremiumUpgradeCard() {
    return GestureDetector(
      onTap: _openPaywall,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor.withValues(alpha: 0.12),
              AppTheme.secondaryColor.withValues(alpha: 0.12),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('✨', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Premium으로 업그레이드',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.secondaryColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '₩4,900',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _premiumChip(Icons.block, AppStrings.current().chipNoAds),
                _premiumChip(Icons.bolt, AppStrings.current().chipFastScan),
                _premiumChip(Icons.all_inclusive, AppStrings.current().chipUnlimited),
                _premiumChip(Icons.high_quality, AppStrings.current().chipHdExport),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _premiumChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.primaryColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionSkeleton(),
        const SizedBox(height: 24),
        HomeSectionSkeleton(),
        const SizedBox(height: 24),
        HomeSectionSkeleton(),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryColor),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '${dateTime.year}.$month.$day $hour:$minute';
  }
}

class _PremiumLockBadge extends StatelessWidget {
  const _PremiumLockBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock, size: 10, color: Colors.white),
          SizedBox(width: 3),
          Text(
            'Premium',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
