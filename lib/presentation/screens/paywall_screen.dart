import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/premium_state.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({
    super.key,
    required this.onPurchase,
    required this.onRestore,
    required this.isPremium,
  });

  /// Called when the user taps "Buy". Receives [monthly] = true for a
  /// subscription purchase, false for a lifetime purchase.
  /// Throws [PurchasePendingException] on pending approval, or [Exception]
  /// on cancellation / billing error.
  final Future<void> Function(bool monthly) onPurchase;

  /// Called when the user taps "Restore". Same contract as [onPurchase].
  final Future<void> Function() onRestore;

  /// Returns true if the user currently has premium (checked after restore).
  final bool Function() isPremium;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isProcessing = false;
  bool _selectedMonthly = false;

  static const _features = [
    (
      icon: Icons.block,
      color: Color(0xFFEF4444),
      title: '광고 완전 제거',
      subtitle: '배너 광고 · 전면 광고 없이 깨끗한 사용 경험',
    ),
    (
      icon: Icons.bolt,
      color: Color(0xFFF59E0B),
      title: '3배 빠른 스캔 속도',
      subtitle: '확장된 배치 처리로 대용량 갤러리도 빠르게',
    ),
    (
      icon: Icons.all_inclusive,
      color: Color(0xFF10B981),
      title: '무제한 이미지 처리',
      subtitle: '갤러리 전체를 제한 없이 스캔하고 분류',
    ),
    (
      icon: Icons.high_quality,
      color: Color(0xFF6366F1),
      title: '고화질 내보내기',
      subtitle: '원본 화질로 \'BabySnap AI\' 앨범에 저장',
    ),
    (
      icon: Icons.auto_awesome_mosaic,
      color: Color(0xFFEC4899),
      title: 'AI 성장 타임라인',
      subtitle: '월별 마일스톤 · 성장 기록 · 자동 캡션',
    ),
    (
      icon: Icons.emoji_events,
      color: Color(0xFFFBBF24),
      title: '베스트 사진 TOP 10',
      subtitle: '미소 · 선명도 · 얼굴크기 AI 자동 분석',
    ),
    (
      icon: Icons.photo_album,
      color: Color(0xFF06B6D4),
      title: '자동 앨범 생성',
      subtitle: '이벤트 · 장면 인식 · 자동 분류',
    ),
    (
      icon: Icons.edit_note,
      color: Color(0xFF8B5CF6),
      title: 'AI 캡션 생성',
      subtitle: '한국어 자동 캡션 · 해시태그 · 복사/공유',
    ),
  ];

  Future<void> _onPurchase() async {
    setState(() => _isProcessing = true);
    try {
      await widget.onPurchase(_selectedMonthly);
      if (mounted) Navigator.pop(context, true);
    } on PurchasePendingException catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('구매 처리 중 오류가 발생했습니다')),
        );
      }
    }
  }

  Future<void> _onRestore() async {
    setState(() => _isProcessing = true);
    try {
      await widget.onRestore();
    } catch (_) {}
    if (!mounted) return;
    if (widget.isPremium()) {
      Navigator.pop(context, true);
    } else {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('복원할 구매 내역이 없습니다')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Background glow
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.5),
                  radius: 1.3,
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.22),
                    const Color(0xFF0F172A),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Close button row
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8, top: 4),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed:
                          _isProcessing ? null : () => Navigator.pop(context),
                    ),
                  ),
                ),
                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    child: Column(
                      children: [
                        // ── Header ────────────────────────────────────────
                        const Text('✨',
                            style: TextStyle(fontSize: 60)),
                        const SizedBox(height: 12),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              Color(0xFF818CF8),
                              Color(0xFFA78BFA),
                              Color(0xFFF472B6),
                            ],
                          ).createShader(bounds),
                          child: const Text(
                            'BabySnap Premium',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppTheme.primaryColor,
                                AppTheme.secondaryColor
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _selectedMonthly ? '월간 구독' : '평생 이용권',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '소중한 아기 사진을 더 스마트하게 관리하세요',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),

                        // ── AI Feature Preview ─────────────────────────────
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'PREMIUM AI 기능 미리보기',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.40),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 160,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.zero,
                            children: [
                              _buildPreviewCard(
                                Icons.auto_awesome_mosaic,
                                [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                                'AI 타임라인',
                                '월별 마일스톤\n자동 감지',
                              ),
                              _buildPreviewCard(
                                Icons.emoji_events,
                                [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                                '베스트 사진',
                                'TOP 10\nAI 품질 분석',
                              ),
                              _buildPreviewCard(
                                Icons.photo_album,
                                [Color(0xFF06B6D4), Color(0xFF0891B2)],
                                '자동 앨범',
                                '장면 인식\n자동 분류',
                              ),
                              _buildPreviewCard(
                                Icons.edit_note,
                                [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                                'AI 캡션',
                                '한국어 캡션\n해시태그',
                              ),
                              _buildPreviewCard(
                                Icons.auto_fix_high,
                                [Color(0xFFEC4899), Color(0xFFF97316)],
                                '사진 향상',
                                'AI 보정\n비포/애프터',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Feature list ──────────────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.primaryColor
                                  .withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              for (int i = 0;
                                  i < _features.length;
                                  i++) ...[
                                if (i > 0)
                                  Divider(
                                    color:
                                        Colors.white.withValues(alpha: 0.07),
                                    height: 1,
                                    indent: 72,
                                    endIndent: 20,
                                  ),
                                _buildFeatureRow(_features[i]),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),

                        // ── Plan selector ─────────────────────────────────
                        Row(
                          children: [
                            Expanded(child: _buildPlanCard(monthly: true)),
                            const SizedBox(width: 10),
                            Expanded(child: _buildPlanCard(monthly: false)),
                          ],
                        ),
                        const SizedBox(height: 22),

                        // ── CTA button ────────────────────────────────────
                        _GradientButton(
                          onPressed: _isProcessing ? null : _onPurchase,
                          child: _isProcessing
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation(
                                        Colors.white),
                                  ),
                                )
                              : Text(
                                  _selectedMonthly
                                      ? '월간 구독 시작하기'
                                      : '평생 이용권 구매하기',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 14),

                        // ── Restore ───────────────────────────────────────
                        TextButton(
                          onPressed: _isProcessing ? null : _onRestore,
                          child: Text(
                            '기존 구매 복원',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // ── Footer ────────────────────────────────────────
                        Text(
                          '결제는 Google Play를 통해 처리됩니다',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.28),
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({required bool monthly}) {
    final selected = _selectedMonthly == monthly;
    return GestureDetector(
      onTap: () => setState(() => _selectedMonthly = monthly),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withValues(alpha: 0.18)
              : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : Colors.white12,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (monthly)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '\uc778\uae30',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              const SizedBox(height: 22),
            const SizedBox(height: 8),
            Text(
              monthly ? '\uc6d4\uac04 \uad6c\ub3c5' : '\ud3c9\uc0dd \uc774\uc6a9\uad8c',
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              monthly ? '\u20a91,900/\uc6d4' : '\u20a94,900',
              style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              monthly ? '\uc5b8\uc81c\ub4e0\uc9c0 \ucde8\uc18c \uac00\ub2a5' : '\uc77c\ud68c \uacb0\uc81c \u00b7 \ud3c9\uc0dd \uc774\uc6a9',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(
      ({IconData icon, Color color, String title, String subtitle}) feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: feature.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(feature.icon, color: feature.color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  feature.subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.check_circle,
            color: feature.color.withValues(alpha: 0.7),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(
    IconData icon,
    List<Color> colors,
    String title,
    String desc,
  ) {
    return Container(
      width: 112,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors[0].withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              desc,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: colors[0].withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '✓ 잠금 해제',
              style: TextStyle(
                color: colors[0],
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A full-width button with a gradient background and press shadow.
class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.onPressed, required this.child});

  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed != null
              ? const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                )
              : LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.4),
                    AppTheme.secondaryColor.withValues(alpha: 0.4),
                  ],
                ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: onPressed != null
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
