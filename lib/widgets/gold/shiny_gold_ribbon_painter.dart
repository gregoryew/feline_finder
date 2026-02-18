import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme.dart';

/// Paints a shiny golden ribbon banner with folded swallowtail ends,
/// metallic gradients, darker outline, fine glitter texture, and sparkles.
/// Use with CustomPaint; child can hold the ribbon label text.
class ShinyGoldRibbonPainter extends CustomPainter {
  ShinyGoldRibbonPainter({int? seed}) : _rng = math.Random(seed ?? 42);

  final math.Random _rng;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Ribbon proportions: folded ends and central band
    const foldWidth = 0.14; // fraction of width for each folded end
    const bandTopY = 0.18;
    const bandBottomY = 0.82;
    final foldW = w * foldWidth;
    final bandLeft = foldW;
    final bandRight = w - foldW;

    // Build main ribbon path: left V-tail -> top band -> right V-tail -> bottom band
    final path = Path();

    // Left swallowtail: V-cut at left edge
    final leftVx = 0.0;
    final leftVy = h * 0.5;
    final leftTopY = h * (bandTopY - 0.02);
    final leftBottomY = h * (bandBottomY + 0.02);

    path.moveTo(leftVx, leftVy);
    path.lineTo(leftVx, leftTopY);
    path.lineTo(bandLeft, h * bandTopY);
    // Top edge of band (slight upward arc)
    path.quadraticBezierTo(
      (bandLeft + bandRight) / 2,
      h * (bandTopY - 0.06),
      bandRight,
      h * bandTopY,
    );
    path.lineTo(w - leftVx, leftTopY);
    path.lineTo(w, leftVy);
    path.lineTo(w - leftVx, leftBottomY);
    path.lineTo(bandRight, h * bandBottomY);
    // Bottom edge of band (slight upward arc)
    path.quadraticBezierTo(
      (bandLeft + bandRight) / 2,
      h * (bandBottomY + 0.06),
      bandLeft,
      h * bandBottomY,
    );
    path.lineTo(bandLeft, leftBottomY);
    path.close();

    // Fill with metallic gold gradient (bright center, darker edges and folds)
    final fillRect = Rect.fromLTWH(0, 0, w, h);
    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppTheme.goldHighlight,
        Color(0xFFFFE066),
        AppTheme.goldBase,
        Color(0xFFC9A227),
        AppTheme.goldShadow,
      ],
      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
    );
    final paint = Paint()
      ..shader = fillGradient.createShader(fillRect)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    // Secondary gradient overlay for center highlight (radial)
    final highlightGradient = RadialGradient(
      center: Alignment.center,
      radius: 0.7,
      colors: [
        Color(0x22FFFFFF),
        Color(0x08FFFFFF),
        Colors.transparent,
      ],
      stops: const [0.0, 0.4, 1.0],
    );
    final highlightPaint = Paint()
      ..shader = highlightGradient.createShader(fillRect)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, highlightPaint);

    // Darker gold outline
    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Color(0xFF9A7B20)
      ..strokeWidth = 1.8;
    canvas.drawPath(path, outlinePaint);

    // Fine glitter: many small semi-transparent points
    _drawGlitter(canvas, path, w, h);

    // Distinct sparkles: 4-pointed starbursts
    _drawSparkles(canvas, path, w, h);
  }

  void _drawGlitter(Canvas canvas, Path path, double w, double h) {
    final bounds = path.getBounds();
    const count = 180;
    for (var i = 0; i < count; i++) {
      final x = bounds.left + _rng.nextDouble() * bounds.width;
      final y = bounds.top + _rng.nextDouble() * bounds.height;
      if (!path.contains(Offset(x, y))) continue;
      final alpha = (0.15 + _rng.nextDouble() * 0.25).clamp(0.0, 1.0);
      final radius = 0.5 + _rng.nextDouble() * 1.0;
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..color = Color.fromRGBO(255, 255, 255, alpha)
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _drawSparkles(Canvas canvas, Path path, double w, double h) {
    final bounds = path.getBounds();
    // Fixed-ish positions so they look good (with small random offset)
    final sparkleCenters = <Offset>[
      Offset(w * 0.22, h * 0.28),
      Offset(w * 0.5, h * 0.22),
      Offset(w * 0.78, h * 0.28),
      Offset(w * 0.3, h * 0.5),
      Offset(w * 0.7, h * 0.5),
      Offset(w * 0.22, h * 0.72),
      Offset(w * 0.5, h * 0.78),
      Offset(w * 0.78, h * 0.72),
    ];
    for (final c in sparkleCenters) {
      final dx = (c.dx + (_rng.nextDouble() - 0.5) * 12).clamp(bounds.left, bounds.right);
      final dy = (c.dy + (_rng.nextDouble() - 0.5) * 12).clamp(bounds.top, bounds.bottom);
      final pt = Offset(dx, dy);
      if (!path.contains(pt)) continue;
      _drawSparkle(canvas, pt, 2.5 + _rng.nextDouble() * 2.5);
    }
  }

  void _drawSparkle(Canvas canvas, Offset center, double size) {
    final paint = Paint()
      ..color = Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final s = size;
    // 4-pointed starburst
    canvas.drawLine(center - Offset(s, 0), center + Offset(s, 0), paint);
    canvas.drawLine(center - Offset(0, s), center + Offset(0, s), paint);
    canvas.drawLine(center - Offset(s * 0.6, s * 0.6), center + Offset(s * 0.6, s * 0.6), paint);
    canvas.drawLine(center - Offset(-s * 0.6, s * 0.6), center + Offset(-s * 0.6, s * 0.6), paint);
    // Bright center dot
    canvas.drawCircle(
      center,
      0.8,
      Paint()
        ..color = Color(0xFFFFFFFF)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Clipper that matches the central band of [ShinyGoldRibbonPainter].
/// Use with [ClipPath] so text (or other child) is drawn only on the ribbon band.
class ShinyGoldRibbonBandClipper extends CustomClipper<Path> {
  static const double foldWidth = 0.14;
  static const double bandTopY = 0.18;
  static const double bandBottomY = 0.82;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final bandLeft = w * foldWidth;
    final bandRight = w - bandLeft;

    final path = Path();
    path.moveTo(bandLeft, h * bandTopY);
    path.quadraticBezierTo(
      (bandLeft + bandRight) / 2,
      h * (bandTopY - 0.06),
      bandRight,
      h * bandTopY,
    );
    path.lineTo(bandRight, h * bandBottomY);
    path.quadraticBezierTo(
      (bandLeft + bandRight) / 2,
      h * (bandBottomY + 0.06),
      bandLeft,
      h * bandBottomY,
    );
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Shiny gold ribbon with [child] drawn only on the central band (clipped).
/// Use for labels so text does not extend onto the folded ends.
class ShinyGoldRibbon extends StatelessWidget {
  const ShinyGoldRibbon({
    Key? key,
    required this.child,
    this.seed,
  }) : super(key: key);

  final Widget child;
  final int? seed;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ShinyGoldRibbonPainter(seed: seed),
      child: ClipPath(
        clipper: ShinyGoldRibbonBandClipper(),
        child: child,
      ),
    );
  }
}
