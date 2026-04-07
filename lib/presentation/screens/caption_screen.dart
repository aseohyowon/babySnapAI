import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/caption_service.dart';
import '../../core/theme/app_theme.dart';

/// Full-screen caption generator sheet.
///
/// Shows the photo at the top, generates a Korean caption on-mount,
/// and provides Regenerate / Copy / Share actions.
class CaptionScreen extends StatefulWidget {
  const CaptionScreen({
    super.key,
    required this.imagePath,
    this.takenAt,
    this.birthDate,
  });

  final String imagePath;
  final DateTime? takenAt;
  final DateTime? birthDate;

  @override
  State<CaptionScreen> createState() => _CaptionScreenState();
}

class _CaptionScreenState extends State<CaptionScreen> {
  late final CaptionService _service;
  CaptionResult? _result;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = CaptionService();
    _generate();
  }

  @override
  void dispose() {
    _service.close();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _service.generateCaption(
        File(widget.imagePath),
        takenAt: widget.takenAt,
        birthDate: widget.birthDate,
      );
      if (mounted) setState(() { _result = result; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _copy() async {
    if (_result == null) return;
    final text = '${_result!.caption}\n\n${_result!.hashtagLine}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('캡션이 복사되었습니다 ✓'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF334155),
      ),
    );
  }

  Future<void> _share() async {
    if (_result == null) return;
    final caption = '${_result!.caption}\n\n${_result!.hashtagLine}';
    await Share.shareXFiles(
      [XFile(widget.imagePath)],
      text: caption,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('AI 캡션 생성'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '다시 생성',
              onPressed: _generate,
            ),
        ],
      ),
      body: Column(
        children: [
          // Photo preview
          AspectRatio(
            aspectRatio: 1,
            child: Image.file(
              File(widget.imagePath),
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),

          // Caption area
          Expanded(
            child: _isLoading
                ? _buildLoading()
                : _error != null
                    ? _buildError()
                    : _buildCaption(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(Color(0xFFEC4899)),
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 16),
          Text('캡션 생성 중...', style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
            const SizedBox(height: 12),
            Text(
              '캡션 생성 실패\n$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _generate,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaption() {
    final result = _result!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Caption card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFEC4899).withValues(alpha: 0.12),
                  const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFEC4899).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('✨', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    const Text(
                      'AI 캡션',
                      style: TextStyle(
                        color: Color(0xFFEC4899),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    _SceneBadge(scene: result.detectedScene),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  result.caption,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 12),
                // Hashtags
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: result.hashtags
                      .map((tag) => _HashtagChip(tag: tag))
                      .toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copy,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('복사'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _share,
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('공유'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEC4899),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Regenerate
          TextButton.icon(
            onPressed: _generate,
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('다른 캡션 생성'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8B5CF6),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small widgets ─────────────────────────────────────────────────────────────

class _HashtagChip extends StatelessWidget {
  const _HashtagChip({required this.tag});
  final String tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        '#$tag',
        style: TextStyle(
          color: AppTheme.primaryColor.withValues(alpha: 0.9),
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SceneBadge extends StatelessWidget {
  const _SceneBadge({required this.scene});
  final String scene;

  static const _labels = <String, String>{
    'birthday': '🎂 생일',
    'water': '🏊 물놀이',
    'winter': '❄️ 겨울',
    'spring': '🌸 봄',
    'animal': '🐾 동물',
    'meal': '🍽️ 식사',
    'outdoor': '🌳 야외',
    'play': '🎮 놀이',
    'sleep': '💤 수면',
    'learning': '📚 학습',
    'travel': '✈️ 여행',
    'everyday': '📸 일상',
  };

  @override
  Widget build(BuildContext context) {
    final label = _labels[scene] ?? '📸 일상';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white54, fontSize: 11),
      ),
    );
  }
}
