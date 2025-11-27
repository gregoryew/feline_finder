import 'package:flutter/material.dart';
import 'gold_plaque.dart';

/// A widget that displays a child within a gold frame, with an optional bottom plaque.
/// 
/// The frame uses 9-slice scaling to maintain border thickness regardless of size.
/// For unbounded height (e.g., in ListView), it uses a Column-based layout.
/// For bounded height, it uses a Stack-based layout.
class GoldFramedPanel extends StatelessWidget {
  final Widget child;
  final List<String>? plaqueLines;
  
  static const String _frameAsset = 'assets/frame/gold_frame_no_plaque.png';
  static const Rect _frameCenterSlice = Rect.fromLTWH(108, 106, 806, 810);

  const GoldFramedPanel({
    Key? key,
    required this.child,
    this.plaqueLines,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Check if height is unbounded (e.g., in ListView)
        final bool isUnboundedHeight = constraints.maxHeight == double.infinity;
        
        // Determine border thickness based on card size
        final bool useSmallBorders = constraints.maxWidth < 200;
        // Increased top and bottom padding to ensure borders are visible
        final EdgeInsets borderThickness = useSmallBorders
            ? const EdgeInsets.only(left: 4, top: 12, right: 4, bottom: 12)
            : const EdgeInsets.only(left: 108, top: 106, right: 108, bottom: 106);

        // Calculate plaque height if needed
        double plaqueHeight = 0;
        if (plaqueLines != null && plaqueLines!.isNotEmpty) {
          // Estimate plaque height based on number of lines
          plaqueHeight = (plaqueLines!.length * 24.0) + 20.0; // ~24px per line + padding
        }

        if (isUnboundedHeight) {
          // Unbounded height case (ListView, etc.)
          // Use Column-based layout with BoxDecoration for frame
          return SizedBox(
            width: constraints.maxWidth,
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(_frameAsset),
                  fit: BoxFit.fill,
                  repeat: ImageRepeat.noRepeat,
                ),
              ),
              padding: EdgeInsets.only(
                left: borderThickness.left,
                top: borderThickness.top,
                right: borderThickness.right,
                bottom: borderThickness.bottom + (plaqueHeight > 0 ? plaqueHeight + 12 : 0),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Child content - constrained to prevent overflow
                  // Use ClipRect to ensure content doesn't overflow and cover borders
                  ClipRect(
                    child: SizedBox(
                      width: double.infinity,
                      child: child,
                    ),
                  ),
                  // Plaque if provided
                  if (plaqueLines != null && plaqueLines!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: GoldPlaque(
                        lines: plaqueLines!,
                        maxWidth: constraints.maxWidth - (borderThickness.left + borderThickness.right),
                      ),
                    ),
                ],
              ),
            ),
          );
        } else {
          // Bounded height case
          // Use Stack-based layout with centerSlice for 9-slice scaling
          return Stack(
            children: [
              // Frame background with 9-slice scaling
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(_frameAsset),
                      fit: BoxFit.fill,
                      centerSlice: _frameCenterSlice,
                    ),
                  ),
                ),
              ),
              // Child content with padding
              Positioned(
                left: borderThickness.left,
                top: borderThickness.top,
                right: borderThickness.right,
                bottom: borderThickness.bottom + (plaqueHeight > 0 ? plaqueHeight + 12 : 0),
                child: SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: child,
                ),
              ),
              // Plaque if provided
              if (plaqueLines != null && plaqueLines!.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: borderThickness.bottom,
                  child: Center(
                    child: GoldPlaque(
                      lines: plaqueLines!,
                      maxWidth: constraints.maxWidth - (borderThickness.left + borderThickness.right),
                    ),
                  ),
                ),
            ],
          );
        }
      },
    );
  }
}

