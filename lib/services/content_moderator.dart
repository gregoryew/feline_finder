import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:html/parser.dart' show parse;

/// Content moderation service that checks for offensive content
/// Uses keyword list stored in Firestore for easy updates
class ContentModerator {
  // Default fallback keywords if Firestore fetch fails
  static const List<String> _defaultKeywords = [
    // Profanity
    'damn',
    'hell',
    'crap',
    'piss',
    'asshole',
    'bastard',
    'bitch',
    'shit',
    'fuck',
    'fucking',
    'fucked',
    'dick',
    'cock',
    'pussy',
    'cunt',
    // Threats/Violence
    'kill',
    'die',
    'death',
    'murder',
    'harm',
    'hurt',
    'violence',
    'attack',
    'assault',
    'beat',
    'punch',
    'stab',
    'shoot',
    'gun',
    'weapon',
    // Sexual content
    'porn',
    'pornography',
    'nude',
    'naked',
    'orgasm',
    'masturbat',
    // Scam/Spam
    'scam',
    'fraud',
    'steal',
    'rob',
    'cheat',
    'phishing',
    'click here',
    'buy now',
    'free money',
    'winner',
    'prize',
    // Aggressive insults
    'stupid',
    'idiot',
    'moron',
    'retard',
    'dumb',
    'loser',
    'pathetic',
    // Common misspellings
    'f*ck',
    'f**k',
    'f***',
    'sh*t',
    's***',
    'a**',
    r'a$$', // Use raw string to avoid $ interpolation
    'b*tch',
  ];

  // Phrases that are always inappropriate
  static const List<String> _alwaysOffensive = [
    'fuck you',
    'go to hell',
    'kill yourself',
    'i hate',
    'i will kill',
    'i will hurt',
  ];

  // Words that might be false positives in shelter context
  static const List<String> _allowedInContext = [
    'kill', // e.g., "kill shelter" (unfortunate but legitimate term)
  ];

  static List<String>? _cachedKeywords;
  static DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(hours: 1);

  /// Fetch offensive keywords from Firestore
  /// Falls back to default list if fetch fails
  static Future<List<String>> _getOffensiveKeywords() async {
    // Return cached keywords if still valid
    if (_cachedKeywords != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
      return _cachedKeywords!;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('content_moderation')
          .get();

      if (doc.exists) {
        final data = doc.data();
        final keywords = List<String>.from(data?['keywords'] ?? []);
        if (keywords.isNotEmpty) {
          _cachedKeywords = keywords;
          _cacheTimestamp = DateTime.now();
          return keywords;
        }
      }
    } catch (e) {
      print('⚠️ Error fetching keywords from Firestore: $e');
      print('   Using default keyword list');
    }

    // Fallback to default
    _cachedKeywords = _defaultKeywords;
    _cacheTimestamp = DateTime.now();
    return _defaultKeywords;
  }

  /// Sanitize text by removing HTML tags and cleaning whitespace
  static String sanitizeText(String text) {
    try {
      // Remove HTML tags
      final html = parse(text);
      final plainText = html.body?.text ?? text;

      // Remove excessive whitespace and trim
      return plainText.trim().replaceAll(RegExp(r'\s+'), ' ');
    } catch (e) {
      print('⚠️ Error sanitizing text: $e');
      // Fallback: just trim and clean whitespace
      return text.trim().replaceAll(RegExp(r'\s+'), ' ');
    }
  }

  /// Check if text contains offensive content
  static Future<bool> containsOffensiveContent(String text) async {
    final lowerText = text.toLowerCase();

    // Check for always offensive phrases first
    for (final phrase in _alwaysOffensive) {
      if (lowerText.contains(phrase)) {
        return true;
      }
    }

    // Get keywords (from Firestore or default)
    final keywords = await _getOffensiveKeywords();

    // Check for offensive keywords
    for (final keyword in keywords) {
      if (lowerText.contains(keyword.toLowerCase())) {
        // Check if it's an allowed context word
        if (_allowedInContext.contains(keyword.toLowerCase())) {
          // Allow if it's part of a legitimate phrase
          if (lowerText.contains('kill shelter') ||
              lowerText.contains('no-kill') ||
              lowerText.contains('no kill')) {
            continue; // Skip this match
          }
        }
        return true;
      }
    }

    return false;
  }

  /// Get severity level of offensive content (for future use)
  static Future<String> getSeverityLevel(String text) async {
    final lowerText = text.toLowerCase();

    // High severity - threats, violence
    final highSeverity = ['kill', 'murder', 'attack', 'harm', 'hurt', 'weapon'];
    for (final word in highSeverity) {
      if (lowerText.contains(word)) {
        return 'high';
      }
    }

    // Medium severity - profanity, insults
    final mediumSeverity = [
      'fuck',
      'shit',
      'bitch',
      'asshole',
      'stupid',
      'idiot'
    ];
    for (final word in mediumSeverity) {
      if (lowerText.contains(word)) {
        return 'medium';
      }
    }

    // Low severity - mild profanity
    return 'low';
  }

  /// Clear cache (useful for testing or forced refresh)
  static void clearCache() {
    _cachedKeywords = null;
    _cacheTimestamp = null;
  }
}

