import 'package:flutter/material.dart';

/// A widget that displays text on a gold plaque.
/// 
/// Supports 1-3 lines of text or widgets, centered horizontally and vertically.
class GoldPlaque extends StatelessWidget {
  final List<String>? lines;
  final List<Widget>? widgets;
  final double maxWidth;
  
  static const String _plaqueAsset = 'assets/frame/gold_plaque_refined.png';
  static const Rect _plaqueCenterSlice = Rect.fromLTWH(71, 93, 849, 835);
  
  static const double _horizontalPadding = 14.0; // Reduced from 24.0 to decrease left/right margins
  static const double _verticalPadding = 10.0; // Restored to ensure text is fully visible within the plaque
  static const Color _textColor = Color(0xFF4A2C00);

  const GoldPlaque({
    Key? key,
    this.lines,
    this.widgets,
    required this.maxWidth,
  }) : assert(lines != null || widgets != null, 'Either lines or widgets must be provided'),
       assert(lines == null || widgets == null, 'Cannot provide both lines and widgets'),
       super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool hasContent = (lines != null && lines!.isNotEmpty) || (widgets != null && widgets!.isNotEmpty);
    if (!hasContent) {
      return const SizedBox.shrink();
    }

    // Calculate minimum size needed for centerSlice
    // centerSlice is Rect.fromLTWH(71, 93, 849, 835)
    // Minimum width: 71 + 849 = 920, Minimum height: 93 + 835 = 928
    final double minWidthForCenterSlice = _plaqueCenterSlice.left + _plaqueCenterSlice.width;
    final double minHeightForCenterSlice = _plaqueCenterSlice.top + _plaqueCenterSlice.height;
    
    // Use centerSlice only if container is large enough, otherwise use regular fit
    final bool canUseCenterSlice = maxWidth >= minWidthForCenterSlice;

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(_plaqueAsset),
          fit: BoxFit.fill,
          centerSlice: canUseCenterSlice ? _plaqueCenterSlice : null,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: _horizontalPadding,
        vertical: _verticalPadding,
      ),
      child: ClipRect(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: widgets != null
              ? widgets!.map((widget) => ClipRect(child: widget)).toList()
              : lines!.map((line) {
                  return ClipRect(
                    child: Text(
                      line,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _textColor,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.clip,
                      maxLines: 2,
                      softWrap: true,
                    ),
                  );
                }).toList(),
        ),
      ),
    );
  }
}

