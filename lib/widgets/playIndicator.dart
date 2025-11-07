import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class CustomPlayIndicatorBorder extends ShapeBorder {
  final double borderWidth;
  final BorderRadius borderRadius;

  const CustomPlayIndicatorBorder({
    this.borderWidth = 1.0,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  EdgeInsetsGeometry get dimensions {
    return EdgeInsets.all(borderWidth);
  }

  @override
  ShapeBorder scale(double t) {
    return CustomPlayIndicatorBorder(
      borderWidth: borderWidth * (t),
      borderRadius: borderRadius * (t),
    );
  }

  @override
  ShapeBorder lerpFrom(ShapeBorder? a, double t) {
    if (a is CustomPlayIndicatorBorder) {
      return CustomPlayIndicatorBorder(
        borderWidth: ui.lerpDouble(a.borderWidth, borderWidth, t)!,
        borderRadius: BorderRadius.lerp(a.borderRadius, borderRadius, t)!,
      );
    }
    return super.lerpFrom(a, t)!;
  }

  @override
  ShapeBorder lerpTo(ShapeBorder? b, double t) {
    if (b is CustomPlayIndicatorBorder) {
      return CustomPlayIndicatorBorder(
        borderWidth: ui.lerpDouble(borderWidth, b.borderWidth, t)!,
        borderRadius: BorderRadius.lerp(borderRadius, b.borderRadius, t)!,
      );
    }
    return super.lerpTo(b, t)!;
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return triangle(rect);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return triangle(rect);
  }

  Path triangle(Rect rect) {
    Path path = Path();
    path.moveTo(rect.left, rect.top);
    path.lineTo(rect.width + rect.left, rect.top + (rect.height * 0.5));
    path.lineTo(rect.left, rect.top + rect.height);
    path.lineTo(rect.left, rect.top);
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    Paint paint;
    paint = Paint()
      ..color = Colors.transparent
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawPath(triangle(rect), paint);
  }
}
