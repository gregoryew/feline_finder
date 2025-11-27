import 'package:flutter/material.dart';

/// A widget that displays text on a gold plaque.
/// 
/// Supports 1-3 lines of text, centered horizontally and vertically.
class GoldPlaque extends StatelessWidget {
  final List<String> lines;
  final double maxWidth;
  
  static const String _plaqueAsset = 'assets/frame/gold_plaque_refined.png';
  static const Rect _plaqueCenterSlice = Rect.fromLTWH(71, 93, 849, 835);
  
  static const double _horizontalPadding = 24.0;
  static const double _verticalPadding = 10.0;
  static const Color _textColor = Color(0xFF4A2C00);

  const GoldPlaque({
    Key? key,
    required this.lines,
    required this.maxWidth,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return const SizedBox.shrink();
    }

    return IntrinsicHeight(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(_plaqueAsset),
                fit: BoxFit.fill,
                centerSlice: _plaqueCenterSlice,
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: _horizontalPadding,
              vertical: _verticalPadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: lines.map((line) {
                return Text(
                  line,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _textColor,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

