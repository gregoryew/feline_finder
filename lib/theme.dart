import 'package:flutter/material.dart';

/// Centralized theme definitions for the Feline Finder app
/// Implements the "Meow Now" design system with purple and gold color palette
class AppTheme {
  // Colors - Purple Palette
  static const Color deepPurple = Color(0xFF6B4C93);
  static const Color royalPurple = Color(0xFF8B6FA8);
  
  // Colors - Gold Palette
  static const Color goldBase = Color(0xFFD4AF37);
  static const Color goldHighlight = Color(0xFFFFD700);
  static const Color goldShadow = Color(0xFFB8860B);
  
  // Colors - Neutral Palette
  static const Color offWhite = Color(0xFFF5F5F5);
  static const Color lightLavender = Color(0xFFE6D9F2);
  static const Color darkText = Color(0xFF333333);
  static const Color primaryText = Colors.white;
  static const Color textSecondary = Colors.white;
  
  // Colors - Component Specific
  static const Color traitCardBackground = Color(0xFFFFB84D); // Orange
  
  // Gradients
  static const LinearGradient purpleGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [deepPurple, royalPurple],
  );
  
  // Borders
  static const double borderWidth = 5.0;
  static const double borderRadius = 12.0;
  static const double buttonBorderRadius = 12.0;
  static const double cardBorderRadius = 16.0;
  
  static const BorderSide goldenBorderSide = BorderSide(
    color: goldBase,
    width: borderWidth,
  );
  
  static const Border goldenBorder = Border.fromBorderSide(goldenBorderSide);
  
  static const List<BoxShadow> goldenGlow = [
    BoxShadow(
      color: goldBase,
      blurRadius: 8,
      spreadRadius: 1,
      offset: Offset(0, 2),
    ),
  ];
  
  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  
  // Typography
  static const String fontFamily = 'Poppins';
  
  static const double fontSizeXS = 10.0;
  static const double fontSizeS = 12.0;
  static const double fontSizeM = 14.0;
  static const double fontSizeL = 16.0;
  static const double fontSizeXL = 20.0;
  static const double fontSizeXXL = 24.0;
  
  // Component Specific Sizes
  static const double breedCardImageHeight = 120.0;
  static const double separatorHeight = 2.0;
  
  // Default Theme Data
  static ThemeData get defaultTheme => ThemeData(
    fontFamily: fontFamily,
    primaryColor: deepPurple,
    scaffoldBackgroundColor: deepPurple,
    colorScheme: ColorScheme.fromSeed(
      seedColor: deepPurple,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      foregroundColor: Colors.white,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSizeXXL,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 8,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardBorderRadius),
      ),
      color: null, // Allow GoldenCard to apply gradients
    ),
    buttonTheme: ButtonThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(buttonBorderRadius),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonBorderRadius),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonBorderRadius),
        ),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: deepPurple,
      selectedItemColor: goldBase,
      unselectedItemColor: Colors.white.withOpacity(0.7),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: goldBase,
      inactiveTrackColor: Colors.white.withOpacity(0.3),
      thumbColor: goldBase,
      overlayColor: goldBase.withOpacity(0.2),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: null, // Allow individual customization
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: goldenBorderSide,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: goldenBorderSide,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: goldenBorderSide,
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontFamily: fontFamily, fontSize: fontSizeXXL, color: primaryText),
      displayMedium: TextStyle(fontFamily: fontFamily, fontSize: fontSizeXL, color: primaryText),
      displaySmall: TextStyle(fontFamily: fontFamily, fontSize: fontSizeL, color: primaryText),
      headlineLarge: TextStyle(fontFamily: fontFamily, fontSize: fontSizeXL, color: primaryText),
      headlineMedium: TextStyle(fontFamily: fontFamily, fontSize: fontSizeL, color: primaryText),
      headlineSmall: TextStyle(fontFamily: fontFamily, fontSize: fontSizeM, color: primaryText),
      titleLarge: TextStyle(fontFamily: fontFamily, fontSize: fontSizeL, color: primaryText),
      titleMedium: TextStyle(fontFamily: fontFamily, fontSize: fontSizeM, color: primaryText),
      titleSmall: TextStyle(fontFamily: fontFamily, fontSize: fontSizeS, color: primaryText),
      bodyLarge: TextStyle(fontFamily: fontFamily, fontSize: fontSizeL, color: primaryText),
      bodyMedium: TextStyle(fontFamily: fontFamily, fontSize: fontSizeM, color: primaryText),
      bodySmall: TextStyle(fontFamily: fontFamily, fontSize: fontSizeS, color: primaryText),
      labelLarge: TextStyle(fontFamily: fontFamily, fontSize: fontSizeM, color: primaryText),
      labelMedium: TextStyle(fontFamily: fontFamily, fontSize: fontSizeS, color: primaryText),
      labelSmall: TextStyle(fontFamily: fontFamily, fontSize: fontSizeXS, color: primaryText),
    ),
    useMaterial3: true,
  );
}

