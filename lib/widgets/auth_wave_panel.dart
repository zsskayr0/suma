import 'dart:math' as math;

import 'package:flutter/material.dart';

/// An abstract approximation of the reference's flowing silk/wave art -
/// soft, layered, blurred ribbons in white/silver/pastel-blue. Built purely
/// from gradients (no image asset available), for the desktop login card's
/// left panel.
class AuthWavePanel extends StatelessWidget {
  const AuthWavePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF3F6F8), Color(0xFFE7EDF1)],
        ),
      ),
      child: ClipRect(
        child: Stack(
          children: [
            for (final band in _bands) Positioned.fill(child: CustomPaint(painter: _RibbonPainter(band))),
            // A soft warm highlight, like the reference's pale peach glint
            // catching the folds.
            Positioned(
              top: -80,
              left: 40,
              child: Container(
                width: 340,
                height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [const Color(0xFFFCE3D2).withValues(alpha: 0.35), Colors.transparent],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Band {
  final double verticalFraction;
  final double amplitude;
  final double thickness;
  final Color color;
  final double alpha;
  const _Band(this.verticalFraction, this.amplitude, this.thickness, this.color, this.alpha);
}

const _bands = [
  _Band(0.30, 0.10, 0.16, Color(0xFFFFFFFF), 0.9),
  _Band(0.42, 0.08, 0.14, Color(0xFFDCE6EC), 0.8),
  _Band(0.55, 0.09, 0.18, Color(0xFF9FCBE8), 0.55),
  _Band(0.68, 0.07, 0.15, Color(0xFFFFFFFF), 0.85),
  _Band(0.80, 0.06, 0.20, Color(0xFFC7D3DA), 0.7),
];

class _RibbonPainter extends CustomPainter {
  final _Band band;
  const _RibbonPainter(this.band);

  @override
  void paint(Canvas canvas, Size size) {
    final baseY = size.height * band.verticalFraction;
    final amp = size.height * band.amplitude;
    final thickness = size.height * band.thickness;

    final path = Path()..moveTo(-20, baseY);
    const steps = 5;
    for (var i = 0; i <= steps; i++) {
      final x = size.width * i / steps;
      final y = baseY + amp * math.sin(i * 1.4 + band.verticalFraction * 6);
      final prevX = size.width * (i - 1) / steps;
      final controlX = (prevX + x) / 2;
      path.quadraticBezierTo(controlX, y, x, y);
    }
    final strokePath = path;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          band.color.withValues(alpha: band.alpha * 0.4),
          Colors.white.withValues(alpha: band.alpha),
          band.color.withValues(alpha: band.alpha * 0.5),
        ],
      ).createShader(Rect.fromLTWH(0, baseY - thickness, size.width, thickness * 2))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);

    canvas.drawPath(strokePath, paint);
  }

  @override
  bool shouldRepaint(covariant _RibbonPainter oldDelegate) => false;
}
