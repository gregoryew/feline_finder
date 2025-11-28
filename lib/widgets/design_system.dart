import 'package:flutter/material.dart';
import '../theme.dart';

/// A card widget with golden border and optional gradient background
class GoldenCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final LinearGradient? gradient;
  final double? width;
  final double? height;
  final Border? border; // Allow custom border override

  const GoldenCard({
    Key? key,
    required this.child,
    this.margin,
    this.padding,
    this.backgroundColor,
    this.gradient,
    this.width,
    this.height,
    this.border,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? (gradient == null ? Colors.transparent : null),
        gradient: gradient ?? (backgroundColor == null ? AppTheme.purpleGradient : null),
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: border ?? AppTheme.goldenBorder, // Use custom border if provided, otherwise default to golden
        boxShadow: AppTheme.goldenGlow,
      ),
      child: child,
    );

    return card;
  }
}

/// A button widget with golden styling
class GoldenButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final EdgeInsetsGeometry? padding;
  final Color? textColor;
  final Color? backgroundColor;
  final LinearGradient? gradient;

  const GoldenButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.icon,
    this.padding,
    this.textColor,
    this.backgroundColor,
    this.gradient,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.buttonBorderRadius),
          side: AppTheme.goldenBorderSide,
        ),
        elevation: 4,
        shadowColor: AppTheme.goldBase.withOpacity(0.5),
      ).copyWith(
        backgroundColor: gradient != null
            ? MaterialStateProperty.all<Color>(Colors.transparent)
            : null,
      ),
      child: Container(
        decoration: gradient != null
            ? BoxDecoration(
                gradient: gradient ?? AppTheme.purpleGradient,
                borderRadius: BorderRadius.circular(AppTheme.buttonBorderRadius),
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: textColor ?? Colors.white, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.fontSizeM,
                fontWeight: FontWeight.bold,
                color: textColor ?? Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An AppBar with gradient background
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  const GradientAppBar({
    Key? key,
    required this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      actions: actions,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.purpleGradient,
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: const TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: AppTheme.fontSizeXXL,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

