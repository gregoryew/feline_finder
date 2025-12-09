import 'package:flutter/material.dart';
import '../../theme.dart';

class GoldTraitPill extends StatelessWidget {
  final String label;

  const GoldTraitPill({
    Key? key,
    required this.label,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: AppTheme.purpleGradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 6,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        trimmed,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: AppTheme.fontSizeS,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontFamily: AppTheme.fontFamily,
          shadows: [
            Shadow(
              color: Colors.black54,
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}

