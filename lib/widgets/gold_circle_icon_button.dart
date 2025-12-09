import 'package:flutter/material.dart';
import '../theme.dart';

class GoldCircleIconButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final bool isSelected;
  final VoidCallback? onTap;

  const GoldCircleIconButton({
    super.key,
    required this.icon,
    this.size = 46,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? [
                    AppTheme.goldHighlight,
                    AppTheme.goldBase,
                    AppTheme.goldShadow,
                  ]
                : [
                    Color(0xFFFFF3C4),
                    Color(0xFFE6B750),
                    Color(0xFFC8922E),
                  ],
          ),
          boxShadow: [
            // Outer glow
            BoxShadow(
              color: AppTheme.goldBase.withOpacity(0.45),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
            // Depth shadow
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 6,
              offset: const Offset(2, 4),
            ),
          ],
          border: Border.all(
            color: Color(0xFFB67A24),
            width: 2,
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            size: size * 0.55,
            color: Colors.white,
            shadows: const [
              Shadow(
                color: Colors.black54,
                offset: Offset(0, 1),
                blurRadius: 2,
              )
            ],
          ),
        ),
      ),
    );
  }
}
