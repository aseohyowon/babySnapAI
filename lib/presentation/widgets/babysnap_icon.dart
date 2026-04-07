import 'dart:math';

import 'package:flutter/material.dart';

/// BabySnap AI Icon Widget
/// 
/// This widget renders the BabySnap AI icon design using Flutter primitives.
/// Can be scaled to any size and rendered as PNG for use in app assets.
/// 
/// Usage:
/// ```dart
/// BabySnapAIIcon(size: 192) // renders 192x192 icon
/// ```
class BabySnapAIIcon extends StatelessWidget {
  const BabySnapAIIcon({
    super.key,
    this.size = 192,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: BabySnapAIIconPainter(size: size),
      ),
    );
  }
}

class BabySnapAIIconPainter extends CustomPainter {
  final double size;

  BabySnapAIIconPainter({required this.size});

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final Offset center = Offset(size / 2, size / 2);

    // 1. Draw gradient background
    _drawGradientBackground(canvas, canvasSize);

    // 2. Draw baby head (rounded face)
    _drawBabyHead(canvas, center, size * 0.35);

    // 3. Draw eyes
    _drawEyes(canvas, center, size);

    // 4. Draw smile
    _drawSmile(canvas, center, size);

    // 5. Draw cheeks (subtle circles)
    _drawCheeks(canvas, center, size);

    // 6. Draw AI scan frame
    _drawScanFrame(canvas, center, size);

    // 7. Draw sparkles
    _drawSparkles(canvas, center, size);
  }

  void _drawGradientBackground(Canvas canvas, Size canvasSize) {
    final Rect rect = Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height);
    final Gradient gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFF87CEEB), // Sky blue
        const Color(0xFFB0E0E6), // Powder blue
        const Color(0xFF98FFD2), // Mint (subtle)
      ],
    );
    canvas.drawRect(
      rect,
      Paint()..shader = gradient.createShader(rect),
    );
  }

  void _drawBabyHead(Canvas canvas, Offset center, double headRadius) {
    // Head with soft peach color
    canvas.drawCircle(
      center,
      headRadius,
      Paint()
        ..color = const Color(0xFFFDBFC8) // Soft peach
        ..style = PaintingStyle.fill,
    );

    // Head outline (subtle)
    canvas.drawCircle(
      center,
      headRadius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.02,
    );
  }

  void _drawEyes(Canvas canvas, Offset center, double size) {
    final double eyeY = center.dy - size * 0.08;
    final double leftEyeX = center.dx - size * 0.12;
    final double rightEyeX = center.dx + size * 0.12;
    final double eyeRadius = size * 0.05;

    const Color eyeColor = Color(0xFF4A90E2); // Soft blue

    // Left eye
    canvas.drawCircle(
      Offset(leftEyeX, eyeY),
      eyeRadius,
      Paint()
        ..color = eyeColor
        ..style = PaintingStyle.fill,
    );

    // Right eye
    canvas.drawCircle(
      Offset(rightEyeX, eyeY),
      eyeRadius,
      Paint()
        ..color = eyeColor
        ..style = PaintingStyle.fill,
    );

    // Eye shine (white highlight)
    final double shineRadius = eyeRadius * 0.4;
    canvas.drawCircle(
      Offset(leftEyeX - eyeRadius * 0.2, eyeY - eyeRadius * 0.2),
      shineRadius,
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
    canvas.drawCircle(
      Offset(rightEyeX - eyeRadius * 0.2, eyeY - eyeRadius * 0.2),
      shineRadius,
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
  }

  void _drawSmile(Canvas canvas, Offset center, double size) {
    final double mouthY = center.dy + size * 0.05;
    final double leftX = center.dx - size * 0.08;
    final double rightX = center.dx + size * 0.08;
    final double curveDepth = size * 0.04;

    final Path path = Path();
    path.moveTo(leftX, mouthY);
    path.quadraticBezierTo(center.dx, mouthY + curveDepth, rightX, mouthY);

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF87CEEB) // Sky blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.025
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawCheeks(Canvas canvas, Offset center, double size) {
    final double cheekY = center.dy + size * 0.05;
    final double leftCheekX = center.dx - size * 0.22;
    final double rightCheekX = center.dx + size * 0.22;
    final double cheekRadius = size * 0.04;

    const Color cheekColor = Color(0xFFFFB6C1); // Light pink

    canvas.drawCircle(
      Offset(leftCheekX, cheekY),
      cheekRadius,
      Paint()
        ..color = cheekColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(rightCheekX, cheekY),
      cheekRadius,
      Paint()
        ..color = cheekColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawScanFrame(Canvas canvas, Offset center, double size) {
    final double frameSize = size * 0.5;
    final double frameThickness = size * 0.015;
    final double cornerSize = size * 0.06;

    const Color frameColor = Color(0xFF98FFD2); // Mint green

    // Top-left corner
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx - frameSize / 2,
        center.dy - frameSize / 2,
        cornerSize,
        frameThickness,
      ),
      Paint()..color = frameColor.withValues(alpha: 0.5),
    );
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx - frameSize / 2,
        center.dy - frameSize / 2,
        frameThickness,
        cornerSize,
      ),
      Paint()..color = frameColor.withValues(alpha: 0.5),
    );

    // Top-right corner
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx + frameSize / 2 - cornerSize,
        center.dy - frameSize / 2,
        cornerSize,
        frameThickness,
      ),
      Paint()..color = frameColor.withValues(alpha: 0.5),
    );
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx + frameSize / 2 - frameThickness,
        center.dy - frameSize / 2,
        frameThickness,
        cornerSize,
      ),
      Paint()..color = frameColor.withValues(alpha: 0.5),
    );

    // Bottom-left corner
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx - frameSize / 2,
        center.dy + frameSize / 2 - frameThickness,
        cornerSize,
        frameThickness,
      ),
      Paint()..color = frameColor.withValues(alpha: 0.5),
    );
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx - frameSize / 2,
        center.dy + frameSize / 2 - cornerSize,
        frameThickness,
        cornerSize,
      ),
      Paint()..color = frameColor.withValues(alpha: 0.5),
    );

    // Bottom-right corner
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx + frameSize / 2 - cornerSize,
        center.dy + frameSize / 2 - frameThickness,
        cornerSize,
        frameThickness,
      ),
      Paint()..color = frameColor.withValues(alpha: 0.5),
    );
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx + frameSize / 2 - frameThickness,
        center.dy + frameSize / 2 - cornerSize,
        frameThickness,
        cornerSize,
      ),
      Paint()..color = frameColor.withValues(alpha: 0.5),
    );
  }

  void _drawSparkles(Canvas canvas, Offset center, double size) {
    final Color sparkleColor = const Color(0xFFFFD700).withValues(alpha: 0.8);
    final double sparkleSize = size * 0.03;

    // Sparkle 1 (top-right)
    _drawStar(
      canvas,
      Offset(center.dx + size * 0.25, center.dy - size * 0.25),
      sparkleSize,
      sparkleColor,
    );

    // Sparkle 2 (top-left)
    _drawStar(
      canvas,
      Offset(center.dx - size * 0.2, center.dy - size * 0.3),
      sparkleSize * 0.7,
      sparkleColor,
    );

    // Sparkle 3 (bottom-right)
    _drawStar(
      canvas,
      Offset(center.dx + size * 0.22, center.dy + size * 0.28),
      sparkleSize * 0.6,
      sparkleColor,
    );
  }

  void _drawStar(Canvas canvas, Offset center, double size, Color color) {
    final Path path = Path();
    const double starRad = 5;
    for (int i = 0; i < starRad * 2; i++) {
      final double radius = i % 2 == 0 ? size : size * 0.5;
      final double angle = (i * 3.14159) / starRad - 3.14159 / 2;
      final double x = center.dx + radius * cos(angle);
      final double y = center.dy + radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(BabySnapAIIconPainter oldDelegate) {
    return oldDelegate.size != size;
  }
}
