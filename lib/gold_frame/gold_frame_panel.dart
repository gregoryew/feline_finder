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
  final List<Widget>? plaqueWidgets;
  
  static const String _frameAsset = 'assets/frame/gold_frame_no_plaque.png';
  static const Rect _frameCenterSlice = Rect.fromLTWH(108, 106, 806, 810);

  const GoldFramedPanel({
    Key? key,
    required this.child,
    this.plaqueLines,
    this.plaqueWidgets,
  }) : assert(plaqueLines == null || plaqueWidgets == null, 'Cannot provide both plaqueLines and plaqueWidgets'),
       super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Check if height is unbounded (e.g., in ListView)
        final bool isUnboundedHeight = constraints.maxHeight == double.infinity;
        
        // Determine border thickness based on card size
        final bool useSmallBorders = constraints.maxWidth < 200;
        
        // Calculate proportional border thickness
        // Original frame: 886x886px with 108px left/right, 106px top/bottom borders
        // Border ratio: ~12.2% for width, ~12.0% for height
        final double borderRatioWidth = 108.0 / 886.0;  // ~12.2%
        final double borderRatioHeight = 106.0 / 886.0; // ~12.0%
        
        final EdgeInsets borderThickness = useSmallBorders
            ? const EdgeInsets.only(left: 4, top: 12, right: 4, bottom: 12)
            : EdgeInsets.only(
                left: constraints.maxWidth * borderRatioWidth,
                top: constraints.maxHeight != double.infinity 
                    ? constraints.maxHeight * borderRatioHeight 
                    : 106.0,
                right: constraints.maxWidth * borderRatioWidth,
                bottom: constraints.maxHeight != double.infinity 
                    ? constraints.maxHeight * borderRatioHeight 
                    : 106.0,
              );

        // Calculate plaque height if needed
        double plaqueHeight = 0;
        if ((plaqueLines != null && plaqueLines!.isNotEmpty) || 
            (plaqueWidgets != null && plaqueWidgets!.isNotEmpty)) {
          // Estimate plaque height based on number of lines/widgets (increased to ensure full visibility)
          // Using 20px per line + 20px for padding to ensure the plaque is fully visible
          final int itemCount = plaqueLines?.length ?? plaqueWidgets?.length ?? 0;
          plaqueHeight = (itemCount * 20.0) + 20.0;
        }

        // For small cards, use Column-based layout to avoid centerSlice issues
        // centerSlice requires the image to be large enough, which small cards aren't
        final bool shouldUseColumnLayout = isUnboundedHeight || useSmallBorders;

        if (shouldUseColumnLayout) {
          // Unbounded height case (ListView, etc.)
          // Use Column-based layout with frame decoration
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
                bottom: borderThickness.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Child content - constrained to prevent overflow
                  ClipRect(
                    child: SizedBox(
                      width: double.infinity,
                      child: child,
                    ),
                  ),
                  // Plaque positioned directly below image (no spacing)
                  if ((plaqueLines != null && plaqueLines!.isNotEmpty) || 
                      (plaqueWidgets != null && plaqueWidgets!.isNotEmpty))
                    GoldPlaque(
                      lines: plaqueLines,
                      widgets: plaqueWidgets,
                      // Increase maxWidth to reduce left/right margins (add 20px total, 10px each side)
                      maxWidth: constraints.maxWidth - (borderThickness.left + borderThickness.right) + 20,
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
                bottom: borderThickness.bottom + (plaqueHeight > 0 ? plaqueHeight : 0), // Removed extra spacing
                child: SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: child,
                ),
              ),
              // Plaque if provided
              if ((plaqueLines != null && plaqueLines!.isNotEmpty) || 
                  (plaqueWidgets != null && plaqueWidgets!.isNotEmpty))
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0, // Position at the very bottom of the frame
                  child: Center(
                    child: GoldPlaque(
                      lines: plaqueLines,
                      widgets: plaqueWidgets,
                      // Increase maxWidth to reduce left/right margins (add 20px total, 10px each side)
                      maxWidth: constraints.maxWidth - (borderThickness.left + borderThickness.right) + 20,
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

