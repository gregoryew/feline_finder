import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Loads API keys from Firestore at app startup and keeps them in memory only.
///
/// Collection: `key_store`
/// Document schema:
/// - key_name:  String
/// - key_value: String
///
/// IMPORTANT: If your Firestore rules allow any client to read `key_store`,
/// these keys are effectively public. This is what the current app behavior
/// requests (send keys to client). For truly secret keys, use a backend proxy.
class KeyStoreService {
  KeyStoreService._();

  static final KeyStoreService instance = KeyStoreService._();

  static const String collectionName = 'key_store';

  final Map<String, String> _keys = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  /// Returns a key value from memory (empty if missing).
  String getKey(String keyName) => _keys[keyName] ?? '';

  /// Loads all keys from Firestore into memory.
  Future<void> load() async {
    final snapshot =
        await FirebaseFirestore.instance.collection(collectionName).get();

    _keys.clear();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final name = (data['key_name'] as String?)?.trim().isNotEmpty == true
          ? (data['key_name'] as String).trim()
          : doc.id;
      final value = (data['key_value'] as String?) ?? '';
      if (name.trim().isEmpty) continue;
      _keys[name] = value;
    }

    _loaded = true;
  }

  /// Debug-only: seed Firestore `key_store` from compile-time defines.
  ///
  /// Run once (debug/profile), then remove the flag:
  /// flutter run --dart-define=SEED_KEY_STORE=true --dart-define=GEMINI_API_KEY=... (etc)
  Future<void> seedFromDefinesIfEnabled() async {
    const enabled = bool.fromEnvironment('SEED_KEY_STORE', defaultValue: false);
    if (!enabled) return;

    if (kReleaseMode) {
      // Never seed from a release build.
      // ignore: avoid_print
      print('⚠️ SEED_KEY_STORE ignored in release mode');
      return;
    }

    const seeds = <String, String>{
      'GEMINI_API_KEY': String.fromEnvironment('GEMINI_API_KEY'),
      'YOUTUBE_API_KEY': String.fromEnvironment('YOUTUBE_API_KEY'),
      'GOOGLE_MAPS_API_KEY': String.fromEnvironment('GOOGLE_MAPS_API_KEY'),
      'RESCUE_GROUPS_API_KEY': String.fromEnvironment('RESCUE_GROUPS_API_KEY'),
    };

    final batch = FirebaseFirestore.instance.batch();
    final col = FirebaseFirestore.instance.collection(collectionName);

    int wrote = 0;
    seeds.forEach((name, value) {
      if (value.trim().isEmpty) return;
      final ref = col.doc(name);
      batch.set(ref, {'key_name': name, 'key_value': value},
          SetOptions(merge: true));
      wrote += 1;
    });

    if (wrote == 0) {
      // ignore: avoid_print
      print('⚠️ SEED_KEY_STORE enabled, but no keys were provided via --dart-define');
      return;
    }

    await batch.commit();
    // ignore: avoid_print
    print('✅ Seeded $wrote keys into Firestore collection "$collectionName"');
  }
}

