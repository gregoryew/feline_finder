import 'package:flutter/material.dart';
import 'package:catapp/models/searchPageConfig.dart';

/// A horizontally scrolling bar of status chips (active filters + optional "+N more").
/// Renders [chips] with consistent styling; chips with [ChipModel.onTap] are tappable.
/// Set [onDarkBackground] true when the bar is on purple/dark gradient so chips stay visible.
class StatusChipBar extends StatelessWidget {
  final List<ChipModel> chips;
  final bool onDarkBackground;

  const StatusChipBar({
    Key? key,
    required this.chips,
    this.onDarkBackground = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();

    final isDark = onDarkBackground;
    final chipColor = isDark ? Colors.white.withOpacity(0.9) : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.6);
    final moreColor = isDark ? Colors.white.withOpacity(0.5) : Colors.white24;
    final textColor = isDark ? const Color(0xFF333333) : Theme.of(context).colorScheme.onPrimaryContainer;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: chips.map((chip) {
          final isMore = chip.label.startsWith('+') && chip.label.endsWith(' more');
          final tappable = chip.onTap != null;
          final bgColor = isMore ? moreColor : chipColor;
          final content = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              chip.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: tappable ? FontWeight.w600 : FontWeight.w500,
                color: textColor,
              ),
            ),
          );
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: tappable
                ? Material(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: chip.onTap,
                      borderRadius: BorderRadius.circular(20),
                      child: content,
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.25)
                          : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.4)
                            : Theme.of(context).colorScheme.outline.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: content,
                  ),
          );
        }).toList(),
      ),
    );
  }
}
