import 'package:flutter/material.dart';

/// Styling utilities for SearchScreen
/// Self-contained to avoid AppTheme coupling
class SearchScreenStyle {
  // ===== COLORS =====
  static const Color gold = Color(0xFFD4AF37);
  static const Color deepPurple = Color(0xFF2A0E4F);
  static const Color purpleSurface = Color(0xFF3B1A63); // Controls (darkest)
  static const Color fieldBackground = Color(0xFF5A4280); // Field backgrounds at 75% purple intensity
  static const Color mediumPurple = Color(0xFF4A2D6B); // Darker medium purple for background

  // ===== GRADIENTS =====
  static const Gradient background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF6E5788), // 20% lighter purple (20% lighter than 0xFF4A2D6B)
      Color(0xFF6E5788), // 20% lighter purple (solid color)
    ],
  );

  static const Gradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF6B4C93), // Medium purple
      Color(0xFF6B4C93), // Medium purple (solid color)
    ],
  );

  // ===== EFFECTS =====
  static List<BoxShadow> goldenGlow = [
    BoxShadow(
      color: gold.withOpacity(0.25),
      blurRadius: 12,
      spreadRadius: 1,
    ),
  ];

  // ===== APP BAR =====
  static AppBar appBar() {
    return AppBar(
      title: const Text(
        'Find Purrfect Cat',
        style: TextStyle(
          color: gold,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: deepPurple,
      elevation: 0,
      iconTheme: const IconThemeData(color: gold),
    );
  }

  // ===== CARDS =====
  static BoxDecoration card({bool highlighted = false}) {
    return BoxDecoration(
      gradient: cardGradient,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: highlighted ? gold : gold.withOpacity(0.35),
        width: highlighted ? 2 : 1,
      ),
      boxShadow: highlighted ? goldenGlow : [],
    );
  }

  // ===== FILTER ROW =====
  static BoxDecoration filterRow({required bool animating}) {
    return BoxDecoration(
      color: animating ? gold.withOpacity(0.12) : purpleSurface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: animating ? gold : gold.withOpacity(0.3),
        width: animating ? 2 : 1,
      ),
      boxShadow: animating ? goldenGlow : [],
    );
  }

  // ===== SEARCH FIELD =====
  static InputDecoration searchFieldDecoration(VoidCallback onClear) {
    return InputDecoration(
      hintText: 'What Do You Want In A Cat',
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
      filled: true,
      fillColor: fieldBackground,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: gold, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: gold, width: 2),
      ),
      prefixIcon: const Icon(Icons.search, color: gold),
      suffixIcon: IconButton(
        icon: const Icon(Icons.cleaning_services, color: gold),
        onPressed: onClear,
      ),
    );
  }

  // ===== CHIPS =====
  static ChipThemeData chipTheme = ChipThemeData(
    backgroundColor: purpleSurface,
    selectedColor: gold.withOpacity(0.25),
    labelStyle: const TextStyle(color: Colors.white),
    secondaryLabelStyle: const TextStyle(color: Colors.white),
    checkmarkColor: gold,
    shape: const StadiumBorder(
      side: BorderSide(color: gold),
    ),
  );

  // ===== BUTTON =====
  static ButtonStyle breedButton = ElevatedButton.styleFrom(
    backgroundColor: purpleSurface,
    foregroundColor: gold,
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: gold, width: 1.5),
    ),
    elevation: 0,
  );
}
