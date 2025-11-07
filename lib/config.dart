import 'dart:io';
import 'package:flutter/foundation.dart';

class AppConfig {
  // RescueGroups API Configuration
  static const String rescueGroupsApiKey = 'eqXAy6VJ';

  // YouTube API Configuration
  static const String youTubeApiKey = 'AIzaSyBGj_Duj__ivCxJ2ya3ilkVfEzX1ZSRlpE';

  // Google Maps API Configuration (used in toolbar)
  static const String googleMapsApiKey =
      'AIzaSyBNEcaJtpfNh1ako5P_XexuILvjnPlscdE';

  // Gemini AI API Configuration
  // Get from: https://aistudio.google.com/app/apikey
  static const String geminiApiKey = 'AIzaSyCW9hT-FVf1Xsj4eXHMPZrMeRGgRz4pTzQ';

  // Email Service Configuration
  // Option 1: Use Postmark API directly (requires POSTMARK_SERVER_TOKEN)
  static const String postmarkApiUrl = 'https://api.postmarkapp.com';

  // Get Postmark token from environment variable
  // Option 1: Use --dart-define when running: flutter run --dart-define=POSTMARK_SERVER_TOKEN=your-token
  // Option 2: Set system environment variable: export POSTMARK_SERVER_TOKEN=your-token
  // Option 3: Add to .env file: POSTMARK_SERVER_TOKEN=your-token (will be loaded via existing .env loader)
  static String? get postmarkServerToken {
    // First try --dart-define (for builds, most secure)
    const tokenFromDefine = String.fromEnvironment('POSTMARK_SERVER_TOKEN');
    if (tokenFromDefine.isNotEmpty) {
      return tokenFromDefine;
    }

    // Then try system environment variable (for development)
    if (!kIsWeb) {
      final tokenFromEnv = Platform.environment['POSTMARK_SERVER_TOKEN'];
      if (tokenFromEnv != null && tokenFromEnv.isNotEmpty) {
        return tokenFromEnv;
      }
    }

    // For .env file, use the existing parseStringToMap system in globals.dart
    // The token will be loaded there if .env contains POSTMARK_SERVER_TOKEN
    return null;
  }

  // Helper method to get token from loaded .env map
  static String? postmarkServerTokenFromEnv(Map<String, String> envMap) {
    return envMap['POSTMARK_SERVER_TOKEN'];
  }

  // Option 2: Use custom email service
  static const String emailServiceUrl = 'https://your-email-service-url.com';

  // External Service URLs
  static const String wikipediaApiUrl = 'https://en.wikipedia.org/w/api.php';
  static const String zippopotamApiUrl = 'https://api.zippopotam.us/us';
  static const String rescueGroupsApiUrl =
      'https://api.rescuegroups.org/v5/public';
  static const String youtubeApiUrl = 'https://www.googleapis.com/youtube/v3';

  // Default Image URLs
  static const String defaultCatImageUrl =
      'https://upload.wikimedia.org/wikipedia/commons/6/65/No-Image-Placeholder.svg';
  static const String placeholderImageUrl =
      'https://via.placeholder.com/200x90.png?text=Cat+Image+Not+Available';

  // Other configuration constants can be added here
  static const String defaultZipCode = '94043';
  static const int defaultDistance = 1000;
}
