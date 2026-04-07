import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/services/image_enhancement_service.dart';
import '../../core/theme/app_theme.dart';
import '../viewmodels/enhancement_view_model.dart';

/// Full-screen photo enhancement editor (premium only).
///
/// Shows a before/after swipe preview, brightness/contrast/sharpness sliders,
/// and a save button that writes the result to "Pictures/BabySnap AI".
class EnhancementScreen extends StatefulWidget {
  const EnhancementScreen({super.key, required this.imagePath});

  final String imagePath;

  @override
  State<EnhancementScreen> createState() => _EnhancementScreenState();
}

class _EnhancementScreenState extends State<EnhancementScreen> {
  late final EnhancementViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = EnhancementViewModel(
      sourcePath: widget.imagePath,
      service: ImageEnhancementService(),
    );
    // Kick off a first pass with default (identity) params so we get the
    // enhanced image file ready even before the user moves any slider.
    _vm.updateSharpness(0.5);
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('AI 사진 향상'),
        actions: [
          AnimatedBuilder(
            animation: _vm,
            builder: (_, __) => TextButton.icon(
              onPressed: (_vm.hasResult && !_vm.isBusy)
                  ? _onSave
                  : null,
              icon: _vm.status == EnhancementStatus.saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_alt, size: 20),
              label: Text(
                _vm.status == EnhancementStatus.saved ? '저장됨 ✓' : '저장',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _vm,
        builder: (context, _) => Column(
          children: [
            // ── Preview area ────────────────────────────────────────────────
            Expanded(
              child: _PreviewArea(
                originalPath: widget.imagePath,
                enhancedPath: _vm.enhancedPath,
                isProcessing: _vm.status == EnhancementStatus.processing,
              ),
            ),
            // ── Controls ────────────────────────────────────────────────────
            _ControlPanel(vm: _vm),
          ],
        ),
      ),
    );
  }

  Future<void> _onSave() async {
    final ok = await _vm.saveEnhanced();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '향상된 사진을 \'BabySnap AI\' 앨범에 저장했습니다 ✓'
              : _vm.errorMessage ?? '저장에 실패했습니다.',
        ),
        backgroundColor:
            ok ? AppTheme.primaryColor : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 2500),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Before / After preview with drag-divider
// ────────────────────────────────────────────────────────────────────────────

class _PreviewArea extends StatefulWidget {
  const _PreviewArea({
    required this.originalPath,
    required this.enhancedPath,
    required this.isProcessing,
  });

  final String originalPath;
  final String? enhancedPath;
  final bool isProcessing;

  @override
  State<_PreviewArea> createState() => _PreviewAreaState();
}

class _PreviewAreaState extends State<_PreviewArea> {
  // Horizontal divider position [0..1]. Start at 0.5 (50/50).
  double _split = 0.5;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final splitX = totalWidth * _split;

          return GestureDetector(
            onHorizontalDragUpdate: (d) {
              setState(() {
                _split = ((_split * totalWidth + d.delta.dx) / totalWidth)
                    .clamp(0.05, 0.95);
              });
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Original (full width, clipped right) ────────────────────
                Positioned.fill(
                  child: Image.file(
                    File(widget.originalPath),
                    fit: BoxFit.contain,
                  ),
                ),

                // ── Enhanced (shown on the right half) ──────────────────────
                if (widget.enhancedPath != null)
                  ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: _split,
                      child: SizedBox(
                        width: totalWidth,
                        child: widget.isProcessing
                            ? Image.file(
                                File(widget.enhancedPath!),
                                fit: BoxFit.contain,
                                color: Colors.black26,
                                colorBlendMode: BlendMode.darken,
                              )
                            : Image.file(
                                File(widget.enhancedPath!),
                                fit: BoxFit.contain,
                                // Passing a key that changes whenever the path
                                // changes forces Flutter to reload the image.
                                key: ValueKey(widget.enhancedPath),
                              ),
                      ),
                    ),
                  ),

                // ── Divider line + handle ────────────────────────────────────
                Positioned(
                  left: splitX - 1,
                  top: 0,
                  bottom: 0,
                  width: 2,
                  child: Container(color: Colors.white),
                ),
                Positioned(
                  left: splitX - 20,
                  top: constraints.maxHeight / 2 - 20,
                  width: 40,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(blurRadius: 6, color: Colors.black38),
                      ],
                    ),
                    child: const Icon(
                      Icons.compare_arrows,
                      color: Colors.black87,
                      size: 20,
                    ),
                  ),
                ),

                // ── Labels ───────────────────────────────────────────────────
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: _label('원본'),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: _label('향상'),
                ),

                // ── Processing overlay ────────────────────────────────────────
                if (widget.isProcessing)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'AI 처리 중…',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _label(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

// ────────────────────────────────────────────────────────────────────────────
// Sliders + reset
// ────────────────────────────────────────────────────────────────────────────

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({required this.vm});

  final EnhancementViewModel vm;

  @override
  Widget build(BuildContext context) {
    final p = vm.params;

    return Container(
      color: AppTheme.surfaceColor,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Preset button row
          Row(
            children: [
              Expanded(
                child: _PresetButton(
                  label: '☀️ 밝게',
                  onTap: () {
                    vm.updateBrightness(0.3);
                    vm.updateContrast(0.1);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PresetButton(
                  label: '🔍 선명하게',
                  onTap: () => vm.updateSharpness(0.9),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PresetButton(
                  label: '👶 얼굴 향상',
                  onTap: () {
                    vm.updateBrightness(0.15);
                    vm.updateContrast(0.2);
                    vm.updateSharpness(0.8);
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Reset
              IconButton(
                onPressed: vm.resetParams,
                icon: const Icon(Icons.refresh, color: Colors.white60),
                tooltip: '초기화',
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Brightness
          _SliderRow(
            icon: Icons.brightness_6,
            label: '밝기',
            value: p.brightness,
            min: -1.0,
            max: 1.0,
            onChanged: vm.updateBrightness,
            disabled: vm.isBusy,
          ),

          // Contrast
          _SliderRow(
            icon: Icons.contrast,
            label: '대비',
            value: p.contrast,
            min: -1.0,
            max: 1.0,
            onChanged: vm.updateContrast,
            disabled: vm.isBusy,
          ),

          // Sharpness
          _SliderRow(
            icon: Icons.search,
            label: '선명도',
            value: p.sharpness,
            min: 0.0,
            max: 1.0,
            onChanged: vm.updateSharpness,
            disabled: vm.isBusy,
          ),

          if (vm.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                vm.errorMessage!,
                style:
                    const TextStyle(color: Colors.redAccent, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.disabled,
  });

  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 18),
        const SizedBox(width: 6),
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.primaryColor,
              inactiveTrackColor: AppTheme.cardColor,
              thumbColor: Colors.white,
              overlayColor: AppTheme.primaryColor.withValues(alpha: 0.2),
              trackHeight: 3,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: disabled ? null : onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            value >= 0 ? '+${value.toStringAsFixed(1)}' : value.toStringAsFixed(1),
            style: const TextStyle(color: Colors.white38, fontSize: 10),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ),
    );
  }
}
