import 'dart:io';
import 'package:flutter/foundation.dart';

import 'services/key_store_service.dart';

class AppConfig {
  // RescueGroups API Configuration
  // SECURITY: Prefer runtime KeyStoreService value (fetched from Firestore).
  // Fallbacks: --dart-define / environment variable (dev).
  static String get rescueGroupsApiKey {
    final fromKeyStore = KeyStoreService.instance.getKey('RESCUE_GROUPS_API_KEY');
    if (fromKeyStore.isNotEmpty) {
      return fromKeyStore;
    }

    const keyFromDefine = String.fromEnvironment('RESCUE_GROUPS_API_KEY');
    if (keyFromDefine.isNotEmpty) {
      return keyFromDefine;
    }

    if (!kIsWeb) {
      final keyFromEnv = Platform.environment['RESCUE_GROUPS_API_KEY'];
      if (keyFromEnv != null && keyFromEnv.isNotEmpty) {
        return keyFromEnv;
      }
    }

    return '';
  }

  // YouTube API Configuration
  // SECURITY: Use environment variable or --dart-define to avoid committing keys to git
  // Option 1: flutter run --dart-define=YOUTUBE_API_KEY=your-key
  // Option 2: export YOUTUBE_API_KEY=your-key (then flutter run)
  static String get youTubeApiKey {
    final fromKeyStore = KeyStoreService.instance.getKey('YOUTUBE_API_KEY');
    if (fromKeyStore.isNotEmpty) {
      return fromKeyStore;
    }

    // First try --dart-define (for builds, most secure)
    const keyFromDefine = String.fromEnvironment('YOUTUBE_API_KEY');
    if (keyFromDefine.isNotEmpty) {
      return keyFromDefine;
    }
    
    // Then try system environment variable (for development)
    if (!kIsWeb) {
      final keyFromEnv = Platform.environment['YOUTUBE_API_KEY'];
      if (keyFromEnv != null && keyFromEnv.isNotEmpty) {
        return keyFromEnv;
      }
    }
    
    // Fallback: Return empty string if not set
    return '';
  }

  // Google Maps API Configuration (used in toolbar)
  // SECURITY: Use environment variable or --dart-define to avoid committing keys to git
  // Option 1: flutter run --dart-define=GOOGLE_MAPS_API_KEY=your-key
  // Option 2: export GOOGLE_MAPS_API_KEY=your-key (then flutter run)
  static String get googleMapsApiKey {
    final fromKeyStore = KeyStoreService.instance.getKey('GOOGLE_MAPS_API_KEY');
    if (fromKeyStore.isNotEmpty) {
      return fromKeyStore;
    }

    // First try --dart-define (for builds, most secure)
    const keyFromDefine = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
    if (keyFromDefine.isNotEmpty) {
      return keyFromDefine;
    }
    
    // Then try system environment variable (for development)
    if (!kIsWeb) {
      final keyFromEnv = Platform.environment['GOOGLE_MAPS_API_KEY'];
      if (keyFromEnv != null && keyFromEnv.isNotEmpty) {
        return keyFromEnv;
      }
    }
    
    // Fallback: Return empty string if not set
    return '';
  }

  // Gemini AI API Configuration
  // Get from: https://aistudio.google.com/app/apikey
  // SECURITY: Use environment variable or --dart-define to avoid committing keys to git
  // Option 1: flutter run --dart-define=GEMINI_API_KEY=your-key
  // Option 2: export GEMINI_API_KEY=your-key (then flutter run)
  static String get geminiApiKey {
    final fromKeyStore = KeyStoreService.instance.getKey('GEMINI_API_KEY');
    if (fromKeyStore.isNotEmpty) {
      return fromKeyStore;
    }

    // First try --dart-define (for builds, most secure)
    const keyFromDefine = String.fromEnvironment('GEMINI_API_KEY');
    if (keyFromDefine.isNotEmpty) {
      return keyFromDefine;
    }
    
    // Then try system environment variable (for development)
    if (!kIsWeb) {
      final keyFromEnv = Platform.environment['GEMINI_API_KEY'];
      if (keyFromEnv != null && keyFromEnv.isNotEmpty) {
        return keyFromEnv;
      }
    }
    
    // Fallback: Return empty string if not set (will show warning in service)
    return '';
  }

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

  // App Store URLs
  // Update this with your actual Bitly link once created: bit.ly/FelineFinder
  static const String appStoreUrl = 'https://bit.ly/FelineFinder';

  // Other configuration constants can be added here
  static const String defaultZipCode = '94043';
  static const int defaultDistance = 1000;
}
