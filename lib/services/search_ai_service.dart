import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../config.dart';

class _SearchCacheEntry {
  final Map<String, dynamic> result;
  final DateTime expiresAt;
  _SearchCacheEntry(this.result, this.expiresAt);
}

class SearchAIService {
  static final SearchAIService _instance = SearchAIService._internal();
  factory SearchAIService() => _instance;
  SearchAIService._internal();

  static Duration get _timeout => const Duration(seconds: 10);
  static const Duration _searchCacheTtl = Duration(minutes: 10);
  final Map<String, _SearchCacheEntry> _searchQueryCache = {};

  late GenerativeModel _model;
  bool _initialized = false;
  int _currentModelIndex = 0;
  // Prefer cheaper models first to avoid high bills (2.5-flash-lite ~$0.10/1M in; 2.5-flash/1.5-pro are much higher).
  static const List<String> _modelCandidates = [
    'gemini-2.5-flash-lite', // Cheapest: same as profile callable (~$0.10/1M in, $0.40/1M out)
    'gemini-2.0-flash-exp',  // Fallback 1: was working well for query understanding
    'gemini-2.0-flash',      // Fallback 2: stable 2.0
    'gemini-2.5-flash',      // Fallback 3: newer stable (higher cost)
    'gemini-1.5-flash',      // Fallback 4: faster, less capable
    // 'gemini-1.5-pro' removed from default list — very expensive ($1.25/1M in, $5/1M out)
  ];

  void initialize() {
    if (!_initialized) {
      final apiKey = AppConfig.geminiApiKey;
      
      if (apiKey.isEmpty) {
        // Debug: Print environment variable values when key is missing
        const keyFromDefine = String.fromEnvironment('GEMINI_API_KEY');
        final keyFromEnv = !kIsWeb ? Platform.environment['GEMINI_API_KEY'] : null;
        
        print('⚠️ Warning: Gemini API key not configured');
        print('🔍 DEBUG - Environment variable check:');
        print('   String.fromEnvironment("GEMINI_API_KEY"): "${keyFromDefine.isEmpty ? "empty" : (keyFromDefine.length > 15 ? "${keyFromDefine.substring(0, 15)}..." : keyFromDefine)}"');
        print('   Platform.environment["GEMINI_API_KEY"]: "${keyFromEnv == null ? "null" : (keyFromEnv.isEmpty ? "empty" : (keyFromEnv.length > 15 ? "${keyFromEnv.substring(0, 15)}..." : keyFromEnv))}"');
        print('   Final apiKey from AppConfig: "${apiKey.isEmpty ? "empty" : (apiKey.length > 15 ? "${apiKey.substring(0, 15)}..." : apiKey)}"');
        print('⚠️ Set it using one of these methods:');
        print('   1. flutter run --dart-define=GEMINI_API_KEY=your-key');
        print('   2. export GEMINI_API_KEY=your-key (then flutter run)');
        print('⚠️ Search AI features will not work without a valid API key');
        return;
      }

      // Try models in order of preference, with fallback if experimental is phased out
      for (int i = 0; i < _modelCandidates.length; i++) {
        final modelName = _modelCandidates[i];
        try {
          _model = GenerativeModel(
            model: modelName,
            apiKey: apiKey,
          );
          _currentModelIndex = i;
          _initialized = true;
          print('✅ SearchAIService initialized with model: $modelName');
          
          // List available models on initialization (async, don't wait)
          _listAvailableModels(apiKey);
          break; // Success, exit the loop
        } catch (e) {
          print('⚠️ Failed to initialize with $modelName: $e');
          if (i == _modelCandidates.length - 1) {
            // Last model failed, give up
            print('❌ All model candidates failed. Search AI features will not work.');
            print('⚠️ Check your API key and network connection');
            _initialized = false;
          }
          // Continue to next model candidate
        }
      }
    }
  }

  /// List available models for debugging (optional; failure does not affect Search AI or personality fit).
  Future<void> _listAvailableModels(String apiKey) async {
    try {
      print('\n🔍 Checking available Gemini models...');
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey');
      final response = await http.get(url).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = data['models'] as List?;

        if (models != null && models.isNotEmpty) {
          print('✅ Found ${models.length} available models:');
          for (var model in models) {
            final name = model['name'] as String?;
            final displayName = model['displayName'] as String?;
            final supportedMethods =
                model['supportedGenerationMethods'] as List?;

            if (name != null) {
              // Extract just the model name (remove "models/" prefix if present)
              final modelName = name.replaceFirst('models/', '');
              final methods = supportedMethods?.join(', ') ?? 'N/A';
              print('   📋 $modelName ($displayName) - Methods: $methods');
            }
          }
          print('');
        } else {
          print('⚠️ No models found in response');
        }
      } else {
        print('⚠️ Failed to list models: ${response.statusCode}');
        print('   Response: ${response.body}');
      }
    } on TimeoutException {
      print('⚠️ List-models check timed out (diagnostic only; Search AI and personality fit are unaffected).');
    } catch (e) {
      print('⚠️ List-models check failed: $e (diagnostic only; Search AI and personality fit are unaffected).');
    }
  }

  /// Parse natural language search with comprehensive error handling.
  /// Results are cached in memory for [_searchCacheTtl] to avoid duplicate Gemini calls for the same query.
  Future<Map<String, dynamic>> parseSearchQuery(String query, {int retryCount = 0}) async {
    // Edge case: Empty or whitespace-only query
    if (query.trim().isEmpty) {
      return _emptyResponse();
    }

    // Edge case: Query too long (prevent excessive API calls)
    if (query.length > 500) {
      query = query.substring(0, 500);
    }

    // Cache: same query within TTL returns cached result (no Gemini call)
    final cacheKey = query.trim().toLowerCase();
    final cached = _searchQueryCache[cacheKey];
    if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
      return Map<String, dynamic>.from(cached.result);
    }
    if (cached != null) _searchQueryCache.remove(cacheKey);

    if (!_initialized) {
      throw Exception(
          'SearchAIService not initialized. Call initialize() first.');
    }

    Map<String, dynamic> raw;
    try {
      raw = await _parseSearchQueryViaCloud(query);
      if (raw.isNotEmpty && (raw.containsKey('location') || raw.containsKey('filters'))) {
        print('🤖 Search parse via Cloud Function (cached prompt)');
      } else {
        raw = await _parseSearchQueryViaGemini(query, retryCount: retryCount);
      }
    } catch (e, stack) {
      print('🔴 [Search] Cloud failed, falling back to Gemini: $e');
      print('🔴 [Search] Stack: $stack');
      raw = await _parseSearchQueryViaGemini(query, retryCount: retryCount);
    }

    if (raw.isEmpty) raw = _emptyResponse();

    Map<String, dynamic> normalized;
    try {
      normalized = await _normalizeResponse(raw);
    } catch (e, stack) {
      print('🔴 [Search] _normalizeResponse error: $e');
      print('🔴 [Search] raw keys: ${raw.keys.toList()}, location type: ${raw['location'].runtimeType}, filters type: ${raw['filters'].runtimeType}');
      print('🔴 [Search] Stack: $stack');
      rethrow;
    }
    print('🤖 Normalized response: $normalized');
    _searchQueryCache[cacheKey] = _SearchCacheEntry(
      Map<String, dynamic>.from(normalized),
      DateTime.now().add(_searchCacheTtl),
    );
    return normalized;
  }

  /// Call Cloud Function parseSearchQuery (Gemini with prompt cache). Returns raw JSON map or empty on failure.
  Future<Map<String, dynamic>> _parseSearchQueryViaCloud(String query) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('parseSearchQuery');
      final result = await callable.call({'query': query}).timeout(_timeout);
      final data = result.data;
      if (data == null) {
        print('🔴 [Search] Cloud function returned null data');
        return _emptyResponse();
      }
      // Deep-convert so nested maps/lists are Map<String, dynamic> / List<dynamic> (avoids "object" type errors)
      return _deepMapStringDynamic(data as Map) ?? _emptyResponse();
    } catch (e, stack) {
      print('🔴 [Search] Cloud parseSearchQuery error: $e');
      print('🔴 [Search] Stack: $stack');
      rethrow;
    }
  }

  /// Recursively convert Map/List to Map<String, dynamic> / List for JSON from Cloud Function.
  static Map<String, dynamic>? _deepMapStringDynamic(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      final out = <String, dynamic>{};
      for (final e in value.entries) {
        final k = e.key?.toString();
        if (k == null) continue;
        final v = e.value;
        if (v is Map) {
          out[k] = _deepMapStringDynamic(v);
        } else if (v is List) {
          out[k] = v.map((e) => e is Map ? (_deepMapStringDynamic(e) ?? <String, dynamic>{}) : e).toList();
        } else {
          out[k] = v;
        }
      }
      return out;
    }
    return null;
  }

  /// Direct Gemini call (no prompt cache). Returns parsed JSON map or empty. Used when cloud is unavailable or fails.
  Future<Map<String, dynamic>> _parseSearchQueryViaGemini(String query, {int retryCount = 0}) async {
    const schemaDefinition = '''
{
         "location": {
           "field": "location",
           "description": "Specifies the user's location and search radius. Extract ZIP codes when mentioned explicitly (e.g., 'cats in 90210', 'zip code 94040', 'near 10001') or when user says 'nearby', 'near me', 'close', or 'local' without specifying distance, default to 20 miles.",
           "subfields": {
             "zip": "User's ZIP code OR city name for location-based searching. Extract from queries like 'in 90210', 'zip code 94040', 'near 10001', 'cats in ZIP 12345', '90210 area', 'cats in Los Angeles', 'near New York', 'San Francisco area', or any 5-digit number/city name mentioned in context of location. If city name is provided, it will be converted to ZIP code automatically.",
             "distance": "Maximum distance in miles from the ZIP code. Default to '20' for 'nearby' queries without explicit distance. Extract from queries like 'within 50 miles', '30 mile radius', '100 miles of', etc."
           },
           "example": { "zip": "94040", "distance": "20" }
         },
  "filters": {
    "breed": {
      "field": "animals.breedPrimaryId",
      "description": "Restrict search results to cats of a specific breed. Match by breed name OR by personality/behavior sayings in personalitySayings. When a trait/saying matches MORE THAN ONE breed, return breed as an ARRAY of ALL matching breeds (e.g. 'dog-like' matches Ragdoll, Maine Coon, Bobtail, Norwegian Forest, Ocicat → breed: ["Ragdoll", "Maine Coon", "Bobtail", "Norwegian Forest", "Ocicat"]). When only one breed matches, return a string.",
      "options": [],
      "keywords": {
        "positive": ["Abyssinian","American Curl","American Shorthair","American Wirehair","Applehead Siamese","Balinese","Bengal","Birman","Bobtail","Bombay","British Shorthair","Burmese","Burmilla","Calico","Canadian Hairless","Chartreux","Chausie","Chinchilla","Cornish Rex","Cymric","Devon Rex","Dilute Calico","Dilute Tortoiseshell","Domestic Long-hair","Domestic Medium-hair","Domestic Short-hair","Egyptian Mau","Exotic Shorthair","Extra-Toes Cat","Havana","Himalayan","Japanese Bobtail","Javanese","Korat","LaPerm","Maine Coon","Manx","Munchkin","Nebelung","Norwegian Forest","Ocicat","Oriental","Persian","Pixie-Bob","Ragamuffin","Ragdoll","Russian Blue","Savannah","Scottish Fold","Selkirk Rex","Siamese","Siberian","Silver","Singapura","Snowshoe","Somali","Sphynx","Tabby","Toyger","Tonkinese","Torbie","Tortoiseshell","Turkish Angora","Turkish Van","Tuxedo"],
        "negative": ["any breed", "all breeds"]
      },
      "personalitySayings": {
        "Abyssinian": ["active", "curious", "social", "dog-like affection", "not lap cat", "ticked coat"],
        "American Curl": ["playful", "affectionate", "curled ears", "seeks attention", "family cat"],
        "American Shorthair": ["adaptable", "steady", "easygoing", "working cat", "good with kids"],
        "American Wirehair": ["gentle", "playful", "quiet", "wiry coat", "rare breed"],
        "Applehead Siamese": ["playful", "affectionate", "round head", "vocal", "applehead"],
        "Balinese": ["playful", "affectionate", "vocal", "long coat", "intelligent"],
        "Bengal": ["active", "confident", "wild look", "spotted", "leopard-like"],
        "Birman": ["affectionate", "gentle", "sacred cat", "white gloves", "blue eyes"],
        "Bobtail": ["playful", "dog-like", "short tail", "adaptable", "bold"],
        "Bombay": ["social", "affectionate", "panther look", "black coat", "lap cat"],
        "British Shorthair": ["calm", "placid", "British Blue", "stocky", "slow to mature"],
        "Burmese": ["social", "playful", "vocal", "muscular", "people-oriented"],
        "Burmilla": ["sweet", "medium build", "silver coat", "makeup lining"],
        "Calico": ["three colors", "white orange black", "playful", "affectionate"],
        "Canadian Hairless": ["hairless", "Sphynx-like", "playful", "warm to touch"],
        "Chartreux": ["quiet", "smiling cat", "blue-grey", "bond with one person", "hunter"],
        "Chausie": ["lively", "outgoing", "athletic", "jungle cat look", "large ears"],
        "Chinchilla": ["fluffy", "silver coat", "gentle", "round eyes", "Persian type"],
        "Cornish Rex": ["Greyhound of cats", "curly coat", "playful", "warm environment", "slender"],
        "Cymric": ["tailless", "longhair Manx", "sturdy", "double coat", "breeches"],
        "Devon Rex": ["pixie look", "monkey in a cat suit", "large ears", "wavy coat", "playful", "social"],
        "Dilute Calico": ["soft colors", "pastel calico", "playful", "affectionate"],
        "Dilute Tortoiseshell": ["muted tortie", "dilute colors", "playful", "affectionate"],
        "Domestic Long-hair": ["longhair", "fluffy", "mixed breed", "varied personality"],
        "Domestic Medium-hair": ["medium coat", "mixed breed", "playful", "affectionate"],
        "Domestic Short-hair": ["shorthair", "mixed breed", "adaptable", "varied"],
        "Egyptian Mau": ["spotted", "fastest cat", "scarab marking", "green eyes", "natural spots"],
        "Exotic Shorthair": ["Persian face", "short coat", "gentle", "round face", "quiet"],
        "Extra-Toes Cat": ["polydactyl", "extra toes", "playful", "Hemingway cat"],
        "Havana": ["Havana Brown", "warm brown", "friendly", "moderate activity", "rare"],
        "Himalayan": ["Persian type", "pointed", "blue eyes", "calm", "longhair"],
        "Japanese Bobtail": ["bobtail", "rabbit tail", "lucky cat", "calico", "folklore"],
        "Javanese": ["silky coat", "intelligent", "affectionate", "point colors", "Balinese relative"],
        "Korat": ["good luck cat", "silver-blue", "affectionate", "vocal", "heart-shaped face"],
        "LaPerm": ["curly coat", "rex", "affectionate", "active", "outgoing", "hypoallergenic"],
        "Maine Coon": ["gentle giant", "dog-like", "large", "social", "fluffy", "hunting"],
        "Manx": ["tailless", "no tail", "hunter", "sociable", "active", "round head"],
        "Munchkin": ["short legs", "dwarf", "playful", "outgoing", "small stature"],
        "Nebelung": ["longhair Russian Blue", "blue-grey", "mild", "reserved", "rare"],
        "Norwegian Forest": ["dog-like", "sociable", "playful", "long coat", "forest cat"],
        "Ocicat": ["spotted", "dog-like", "trainable", "fetch", "leash", "no wild DNA"],
        "Oriental": ["intelligent", "playful", "social", "slender", "vocal", "bond with owner"],
        "Persian": ["calm", "lap cat", "long coat", "flat face", "doll face", "quiet"],
        "Pixie-Bob": ["bobcat look", "short tail", "chirp", "intelligent", "social", "polydactyl"],
        "Ragamuffin": ["large", "affectionate", "docile", "sweet expression", "soft coat"],
        "Ragdoll": ["go limp when picked up", "goes limp when held", "docile", "placid", "puppy cat", "dog-like", "follows you room to room", "floppy"],
        "Russian Blue": ["quiet", "reserved", "green eyes", "blue-grey", "shy with strangers"],
        "Savannah": ["tall", "spotted", "serval look", "intelligent", "active", "large ears"],
        "Scottish Fold": ["folded ears", "owl face", "sweet", "calm", "round"],
        "Selkirk Rex": ["curly coat", "placid", "affectionate", "cuddly", "robust"],
        "Siamese": ["Meezer", "vocal", "talkative", "extrovert", "bond with one person", "affectionate", "intelligent", "demanding attention"],
        "Siberian": ["affectionate", "playful", "hypoallergenic", "forest cat", "fluffy"],
        "Silver": ["silver coat", "adaptable", "American Shorthair type", "friendly"],
        "Singapura": ["smallest breed", "large eyes", "playful", "affectionate", "tiny"],
        "Snowshoe": ["white paws", "pointed", "blue eyes", "Siamese mix", "rare"],
        "Somali": ["fox-like", "longhair Abyssinian", "energetic", "social", "ticked coat"],
        "Sphynx": ["hairless", "no fur", "playful", "outgoing", "warm to touch", "wrinkled"],
        "Tabby": ["striped", "M mark", "classic pattern", "varied personality"],
        "Toyger": ["tiger stripes", "gentle", "adaptable", "mini tiger", "friendly"],
        "Tonkinese": ["lively", "Siamese Burmese mix", "aquamarine eyes", "playful", "vocal"],
        "Torbie": ["tortie and tabby", "adaptable", "varied coat", "friendly"],
        "Tortoiseshell": ["tortie", "black orange", "fiery", "varied personality", "female"],
        "Turkish Angora": ["intelligent", "playful", "protective", "bond strongly", "white", "plumed tail"],
        "Turkish Van": ["Van pattern", "white body", "swimming", "active", "intelligent", "color on head and tail"],
        "Tuxedo": ["black and white", "formal look", "adaptable", "varied personality"]
      }
    },
    "sizeGroup": {
      "field": "animals.sizeGroup",
      "description": "Cat's general body size category.",
      "options": ["Small", "Medium", "Large", "X-Large", "Any"],
      "keywords": {
        "positive": ["tiny", "small", "medium", "big", "large"],
        "negative": ["not small", "not big", "no preference"]
      }
    },
    "ageGroup": {
      "field": "animals.ageGroup",
      "description": "Cat's age group.",
      "options": ["Baby", "Young", "Adult", "Senior", "Any"],
      "keywords": {
        "positive": ["kitten", "young", "adult", "senior"],
        "negative": ["not kitten", "not senior"]
      }
    },
    "sex": {
      "field": "animals.sex",
      "description": "Cat's biological sex.",
      "options": ["Male", "Female", "Any"],
      "keywords": {
        "positive": ["male", "boy cat", "female", "girl cat"],
        "negative": ["no gender preference"]
      }
    },
    "coatLength": {
      "field": "animals.coatLength",
      "description": "Length of the cat's fur.",
      "options": ["Short", "Medium", "Long", "Any"],
      "keywords": {
        "positive": ["short-haired", "long-haired", "fluffy", "smooth coat"],
        "negative": ["not long-haired", "no coat preference"]
      }
    },
    "energyLevel": {
      "field": "animals.energyLevel",
      "description": "Overall activity or energy level.",
      "options": ["Low", "Medium", "High", "Any"],
      "keywords": {
        "positive": ["calm", "moderate", "active", "energetic"],
        "negative": ["hyper", "lazy", "sluggish", "no preference"]
      }
    },
    "activityLevel": {
      "field": "animals.activityLevel",
      "description": "How active the cat tends to be daily.",
      "options": ["None", "Low", "Medium", "High", "Any"],
      "keywords": {
        "positive": ["active", "energetic", "busy", "alert"],
        "negative": ["inactive", "sedentary", "relaxed"]
      }
    },
    "newPeopleReaction": {
      "field": "animals.newPeopleReaction",
      "description": "How the cat reacts to strangers or new people.",
      "options": ["Cautious", "Friendly", "Any"],
      "keywords": {
        "positive": ["friendly", "sociable", "trusting", "greets people", "greets strangers", "greets guests", "welcomes people", "good with new people", "friendly with strangers", "meets people easily", "comes up to visitors", "good with visitors", "welcomes guests", "comes to say hi", "says hi to visitors", "greets at the door", "welcomes guests at the door"],
        "negative": ["shy", "timid", "hides from strangers", "wary of strangers", "avoids new people"]
      }
    },
    "isHousetrained": {
      "field": "animals.isHousetrained",
      "description": "Whether the cat reliably uses a litter box.",
      "options": ["Yes", "No", "Any"],
      "keywords": {
        "positive": ["litter trained", "house trained", "clean"],
        "negative": ["not trained", "accidents", "not litter trained"]
      }
    },
    "isDogsOk": {
      "field": "animals.isDogsOk",
      "description": "Whether the cat gets along with dogs.",
      "options": ["Yes", "No", "Any"],
      "keywords": {
        "positive": ["good with dogs", "dog friendly"],
        "negative": ["dislikes dogs", "not dog friendly"]
      }
    },
    "isCatsOk": {
      "field": "animals.isCatsOk",
      "description": "Whether the cat gets along with other cats.",
      "options": ["Yes", "No", "Any"],
      "keywords": {
        "positive": ["good with cats", "cat friendly"],
        "negative": ["territorial", "not cat friendly"]
      }
    },
    "isKidsOk": {
      "field": "animals.isKidsOk",
      "description": "Whether the cat is suitable for homes with children.",
      "options": ["Yes", "No", "Any"],
      "keywords": {
        "positive": ["good with kids", "family friendly"],
        "negative": ["not good with kids", "no children"]
      }
    },
    "indoorOutdoor": {
      "field": "animals.indoorOutdoor",
      "description": "Indicates whether the cat should stay indoors, outdoors, or both.",
      "options": ["Indoor", "Both", "Outdoor", "Any"],
      "keywords": {
        "positive": ["indoor", "house cat", "outdoor cat"],
        "negative": ["no preference"]
      }
    },
    "apartmentOk": {
      "field": "animals.isYardRequired",
      "description": "Whether the cat is suitable for apartment or small-space living (no yard required). Yes = apartment OK; the cat does not need a yard.",
      "options": ["Yes", "No", "Any"],
      "keywords": {
        "positive": ["apartment", "apartment living", "apartment ok", "no yard", "no garden", "condo", "small space", "lives in apartment", "good for apartments", "suitable for apartment"],
        "negative": ["needs yard", "needs garden", "outdoor space required"]
      }
    },
    "colorDetails": {
      "field": "animals.colorDetails",
      "description": "Primary or secondary color pattern of the cat's coat.",
      "options": ["Black","Black and White","Blue","Gray","Brown","Cream","Ivory","Silver","Red","Spotted","Tan","Fawn","Tortoiseshell","White","Any"],
      "keywords": {
        "positive": ["black cat","gray cat","white cat"],
        "negative": ["no color preference"]
      }
    },
    "eyeColor": {
      "field": "animals.eyeColor",
      "description": "Eye color of the cat.",
      "options": ["Black","Blue","Brown","Green","Gold","Gray","Hazel","Mixed","Yellow","Any"],
      "keywords": {
        "positive": ["blue-eyed","green eyes","golden eyes"],
        "negative": ["no preference"]
      }
    },
    "tailType": {
      "field": "animals.tailType",
      "description": "Shape or condition of the cat's tail.",
      "options": ["Bare","Bob","Curled","Docked","Kinked","Long","Short","Any"],
      "keywords": {
        "positive": ["bobtail","long tail","short tail"],
        "negative": ["no preference"]
      }
    },
    "groomingNeeds": {
      "field": "animals.groomingNeeds",
      "description": "How much grooming care the cat requires.",
      "options": ["Not Required","Low","Medium","High", "Any"],
      "keywords": {
        "positive": ["low maintenance","easy grooming","needs brushing"],
        "negative": ["no grooming preference"]
      }
    },
    "sheddingLevel": {
      "field": "animals.sheddingLevel",
      "description": "Typical amount of fur shedding.",
      "options": ["None","Some","High","Any"],
      "keywords": {
        "positive": ["low shedding","hairless","sheds a lot"],
        "negative": ["no shedding preference"]
      }
    },
    "isAltered": {
      "field": "animals.altered",
      "description": "Whether the cat has been spayed or neutered.",
      "options": ["Yes","No","Any"],
      "keywords": {
        "positive": ["spayed","neutered","fixed"],
        "negative": ["intact","not altered"]
      }
    },
    "isMicrochipped": {
      "field": "animals.isMicrochipped",
      "description": "Whether the cat has an identification microchip.",
      "options": ["Yes","No","Any"],
      "keywords": {
        "positive": ["microchipped","has chip"],
        "negative": ["no chip","not microchipped"]
      }
    },
    "isSpecialNeeds": {
      "field": "animals.isSpecialNeeds",
      "description": "Indicates whether the cat has physical or behavioral special needs.",
      "options": ["Yes","No","Any"],
      "keywords": {
        "positive": ["special needs","disability","handicapped"],
        "negative": ["no special needs"]
      }
    },
    "isCurrentVaccinations": {
      "field": "animals.isCurrentVaccinations",
      "description": "Whether the cat is up to date on required vaccinations.",
      "options": ["Yes","No","Any"],
      "keywords": {
        "positive": ["vaccinated","up to date on shots"],
        "negative": ["not vaccinated"]
      }
    },
    "updatedDate": {
      "field": "animals.updatedDate",
      "description": "Filter cats by when they were last updated/added. When user says 'new', 'new cats', 'recently added', 'just posted', default to 'Week' (updated within last 7 days).",
      "options": ["Day","Week","Month","Year","Any"],
      "keywords": {
        "positive": ["new","new cats","new listings","recently added","just posted","fresh","recent"],
        "negative": ["all","any","no preference"]
      }
    },
    "affectionate": {
      "field": "animals.descriptionText",
      "description": "Whether the cat is described in its profile as loving, cuddly, or people-oriented.",
      "options": ["Yes"],
      "keywords": {
        "positive": ["affectionate","loving","cuddly","snuggly","friendly","devoted","social","socialable","socializable","socialize","socialized","socializing","likes cuddles","likes pets","sweet with people","affectionate but independent","affectionate on their own terms"],
        "negative": ["independent","aloof","not cuddly","distant","detached","wants space"]
      }
    },
    "independentAloof": {
      "field": "animals.descriptionText",
      "description": "Whether the cat is described as independent, aloof, or preferring to keep to itself.",
      "options": ["Yes"],
      "keywords": {
        "positive": ["independent","aloof","standoffish","distant","unfriendly","unapproachable","uncommunicative","self-sufficient","does own thing","prefers space","likes space","not clingy","not needy","on their own terms","not in my face","not constantly in my face"],
        "negative": ["social","clingy","needy","lap cat","velcro","always on you","in your face"]
      }
    },
    "calmness": {
      "field": "animals.descriptionText",
      "description": "Whether the cat is described as calm, quiet, or relaxed in temperament.",
      "options": ["Yes","No","Any"],
      "keywords": {
        "positive": ["calm","quiet","laid back","relaxed","mellow","easygoing"],
        "negative": ["active","energetic","high energy","hyper","rambunctious","rowdy","wild"]
      }
    },
    "gentleness": {
      "field": "animals.descriptionText",
      "description": "Whether the cat is described as gentle, soft, or sweet-natured.",
      "options": ["Yes","No","Any"],
      "keywords": {
        "positive": ["gentle","gentleness","soft","sweet","mild","kind","no attitude","without attitude","not sassy","not spicy","sweet personality","easygoing personality"],
        "negative": ["feisty","spicy","rough","rowdy","boisterous","assertive","intense","scrappy","attitude","sassy","sassy attitude","spicy attitude","dramatic","drama queen","diva","bossy"]
      }
    },
    "lapCat": {
      "field": "animals.descriptionText",
      "description": "Whether the cat is described as a lap cat or as loving to sit on laps.",
      "options": ["Yes","No","Any"],
      "keywords": {
        "positive": ["lap","lap lover","lap cat","lapcat","cuddly","snuggly","loves laps","on your lap","affectionate"],
        "negative": ["independent","aloof","not a lap cat","not cuddly","not affectionate","keeps to self","prefers space","not snuggly","not clingy","not needy","not in my face","not constantly in my face","likes space","affectionate on their own terms","cuddles on their own terms"]
      }
    },
    "playful": {
      "field": "animals.descriptionText",
      "description": "Whether the cat is described as playful, energetic, or enjoying activity and play.",
      "options": ["Yes","Any"],
      "keywords": {
        "positive": ["playful","energetic","lively","active","pounces","toys","zoomies"],
        "negative": ["sedentary","lazy","low energy"]
      }
    },
    "likesToys": {
      "field": "animals.descriptionText",
      "description": "Whether the cat is described as liking or playing with toys.",
      "options": ["Yes","No","Any"],
      "keywords": {
        "positive": ["likes toys","toys","plays with toys","loves toys","playful","enjoys play"],
        "negative": ["not playful","low play","ignores toys","uninterested in toys","laid back","couch potato","sedate","lazy"]
      }
    },
    "outgoing": {
      "field": "animals.descriptionText",
      "description": "Whether the cat is described as outgoing, friendly, or social with people.",
      "options": ["Yes","Any"],
      "keywords": {
        "positive": ["outgoing","friendly","social","socialable","socializable","socialize","socialized","socializing"],
        "negative": ["shy","reserved","withdrawn"]
      }
    },
    "curious": {
      "field": "animals.descriptionText",
      "description": "Whether the cat is described as curious, mischievous, or prone to getting into things.",
      "options": ["Yes","No","Any"],
      "keywords": {
        "positive": ["curious","mischievous","explores","gets into things","trouble","inquisitive","adventurous"],
        "negative": ["laid back","low-key","mellow","reserved","homebody","content to lounge","not curious","uninterested"]
      }
    },
    "adultSexesOk": {
      "field": "animals.adultSexesOk",
      "description": "Whether the cat is suitable for homes with only men, only women, or all adults.",
      "options": ["All","Men Only","Women Only","Any"],
      "keywords": {
        "positive": ["men only","women only","all adults","prefers men","prefers women"],
        "negative": ["no preference"]
      }
    },
    "evenTempered": {
      "field": "animals.evenTempered",
      "description": "Whether the cat is described as even-tempered, calm, or steady in temperament.",
      "options": ["Yes","Any"],
      "keywords": {
        "positive": ["even-tempered","even tempered","calm","steady","mellow","easygoing"],
        "negative": ["moody","reactive","high strung"]
      }
    },
    "needsCompanionAnimal": {
      "field": "animals.NeedsCompanionAnimal",
      "description": "Whether the cat must be adopted WITH another cat (bonded/companion pair). Yes = cat has to come with another cat; they are companions.",
      "options": ["Yes","Any"],
      "keywords": {
        "positive": ["companion cat","companion cats","needs companion","wants companion","wants company","needs a friend","must be adopted with another cat","must come with another cat","bonded pair","bonded cats","adopt with another cat","needs to be adopted with another cat","companion required","adopted together","adopt together"],
        "negative": ["independent","prefers to be alone"]
      }
    },
    "timidShy": {
      "field": "animals.descriptionText",
      "description": "Whether the cat is described as timid, shy, or cautious with people.",
      "options": ["Yes","No","Any"],
      "keywords": {
        "positive": ["shy","timid","fearful","reserved","skittish","nervous","hesitant"],
        "negative": ["outgoing","confident","social","friendly","bold","brave","fearless","gregarious"]
      }
    },
    "personalityEnergyLevel": { "field": "energyLevel", "description": "Energy Level slider (1-5). 0 or omit = Any.", "options": [0,1,2,3,4,5] },
    "personalityPlayfulness": { "field": "playfulness", "description": "Playfulness slider (1-5). 0 or omit = Any.", "options": [0,1,2,3,4,5] },
    "personalityAffectionate": { "field": "affectionate", "description": "Affection Level slider (1-5). 0 or omit = Any.", "options": [0,1,2,3,4,5] },
    "personalityIndependence": { "field": "independence", "description": "Independence slider (1-5). 0 or omit = Any.", "options": [0,1,2,3,4,5] },
    "personalitySociability": { "field": "sociability", "description": "Sociability slider (1-5). 0 or omit = Any.", "options": [0,1,2,3,4,5] },
    "personalityVocalization": { "field": "vocalLevel", "description": "Vocality/Vocalization slider (1-5). 0 or omit = Any.", "options": [0,1,2,3,4,5] },
    "personalityAdaptability": { "field": "adaptability", "description": "Adaptability slider (1-5). 0 or omit = Any.", "options": [0,1,2,3,4,5] },
    "personalityIntelligence": { "field": "intelligence", "description": "Intelligence slider (1-5). 0 or omit = Any.", "options": [0,1,2,3,4,5] },
    "personalityConfidence": { "field": "confidence", "description": "Confidence slider (1-5). 0 or omit = Any.", "options": [0,1,2,3,4,5] },
    "personalitySensitivity": { "field": "sensitivity", "description": "Sensitivity slider (1-5). 0 or omit = Any.", "options": [0,1,2,3,4,5] }
  }
}
''';

    const systemPrompt = '''
You are a cat adoption search assistant. Your job is to carefully understand the user's natural language query and extract all relevant search filters and location information.

IMPORTANT: Pay close attention to what the user is asking for. Understand the intent behind their words, not just keywords.

Use this schema structure:
$schemaDefinition

Return JSON in this exact format (omit "catType" if user does not ask for a personality type by name; omit "sortBy" if user does not ask to sort):
{
  "location": {
    "zip": "94040",
    "distance": "20"
  },
  "catType": "Velcro Cat",
  "sortBy": "distance",
  "filters": {
    "breed": "Persian",
    "sizeGroup": "Medium",
    "ageGroup": "Adult",
    "sex": "Female",
    "coatLength": "Long",
    "affectionate": "Yes",
    "playful": "Yes",
    "energyLevel": "Medium",
    "confidence": 4,
    "sensitivity": 3,
    "needsCompanionAnimal": "Yes",
    "apartmentOk": "Yes",
    "isDogsOk": "Yes",
    "isKidsOk": "Yes",
    "colorDetails": "White",
    "isHousetrained": "Yes"
  }
}

CAT TYPE (personality type by name):
- When the user asks for a cat by personality type NAME, set "catType" at the top level to that exact name. Use ONLY one of these exact names (case-sensitive): Professional Napper, Lap Legend, Zen Companion, Old Soul, Quiet Shadow, Zoomie Rocket, Parkour Cat, Toy Addict, Chaos Sprite, Forever Kitten, Velcro Cat, Cuddle Ambassador, Welcome Committee, Therapy Cat, Heart Healer, Solo Artist, Dignified Observer, Window Philosopher, Private Thinker, Gentle Hermit, Drama Monarch, Opinionated Roommate, Soap Opera Star, Mood Ring Cat, Attention Magnet, Routine Master, Puzzle Pro, Social Learner, Explorer Brain, Little Professor.
- Examples: "I want a Velcro Cat" → "catType": "Velcro Cat". "Show me Zoomie Rocket types" → "catType": "Zoomie Rocket". "Professional Napper near me" → "catType": "Professional Napper" and include location.
- Omit "catType" if the user does not mention one of these personality type names.
- Do NOT infer a catType from generic traits like "curious", "intelligent", "playful", "affectionate", or combinations like "curious and very intelligent". Those should stay in filters unless the user explicitly names a catType.

SORT BY (optional top-level "sortBy"):
- When the user asks to sort or order results, set "sortBy" at the top level to either "distance" or "date".
- "distance": User says "sort by distance", "nearest", "closest", "by distance", "closest first", "nearest first", "order by distance".
- "date": User says "sort by date", "most recent", "newest first", "by time", "recently added", "latest first", "order by date", "newest", "most recent first".
- Omit "sortBy" if the user does not mention how to sort.

IMPORTANT - Handling OR conditions:
- When the user uses "or", "either", "either/or", or lists multiple options separated by "or" (e.g., "black or white", "small or medium", "Persian or Siamese"), return an ARRAY of values for ALL filters that support multiple selections
- ALL filters that support OR conditions (return arrays for these when user says "or" or "either"):
  * breed (e.g., ["Persian", "Siamese"])
  * sizeGroup (e.g., ["Small", "Medium"]) 
  * ageGroup (e.g., ["Baby", "Young"])
  * coatLength (e.g., ["Short", "Long"])
  * newPeopleReaction (e.g., ["Friendly", "Cautious"])
  * activityLevel (e.g., ["Low", "Medium", "High"])
  * energyLevel (e.g., ["Low", "High"])
  * exerciseNeeds (e.g., ["Low", "Medium"])
  * vocalLevel (e.g., ["Quiet", "A Little", "Some", "Talkative", "Lots"])
  * colorDetails (e.g., ["Black", "White", "Gray"])
  * eyeColor (e.g., ["Blue", "Green", "Gold"])
  * tailType (e.g., ["Long", "Short", "Bob"])
    * groomingNeeds (e.g., ["Low", "Medium", "High"])
    * sheddingLevel (e.g., ["None", "Some", "High"])
    * obedienceTraining (e.g., ["Needs", "Basic", "Well"])
    * earType (e.g., ["Erect", "Droopy", "Cropped"])
- Examples:
  * "black or white cat" → {"colorDetails": ["Black", "White"]}
  * "small or medium cat" → {"sizeGroup": ["Small", "Medium"]}
  * "baby or young cat" → {"ageGroup": ["Baby", "Young"]}
  * "Persian or Maine Coon" → {"breed": ["Persian", "Maine Coon"]}
  * "quiet or some vocalization" → {"vocalLevel": ["Quiet", "A Little", "Some"]}
  * "low or medium grooming needs" → {"groomingNeeds": ["Low", "Medium"]}
  * "none or some shedding" → {"sheddingLevel": ["None", "Some"]}
- CRITICAL: When user uses "or" with ANY of the filters listed above, you MUST return an array with ALL the options mentioned
- If user says "black and white" (together as a phrase), that's a pattern name like "Black and White" or "Tuxedo" - use single value "Black and White"
- For single-select filters that don't support OR (like sex), use a single value only

       Rules:
       1. Only include filters that are explicitly mentioned or can be inferred from the query
       2. Use "Any" or omit the field if not specified
       3. For personality (playful, affectionate, calm, curious, etc.): set the matching filter to "Yes" (e.g. playful: "Yes"). Do NOT map "playful cat" or "affectionate cat" to breed—use personality filters. For breed, match by breed name OR when user explicitly asks for a breed by trait (use personalitySayings). When a trait matches MULTIPLE breeds and user asked for breed, return breed as an ARRAY; when only one breed matches, return a string. Calico is a BREED, not a color—always use breed: "Calico", never colorDetails for "calico"
       4. For location, extract ZIP code, city name, or distance if mentioned. Location can appear as:
          - ZIP codes: "in 90210", "zip code 94040", "near 10001", "cats in ZIP 12345"
          - City names: "cats in Los Angeles", "near New York", "San Francisco area", "around Chicago"
          - Contextual: "90210 area", "near Beverly Hills 90210", "cats around 94040"
          - Any 5-digit number or city name that appears in a location context
       5. DEFAULT DISTANCE: When user says "nearby", "near me", "close", "local", or similar phrases WITHOUT specifying a distance, default to "20" miles
       6. ZIP CODE/CITY EXTRACTION: Always look for 5-digit numbers OR city names in the query that could be locations, especially when combined with location words like "in", "near", "around", "zip", "ZIP code", "area", "city", etc. City names will be automatically converted to ZIP codes.
       7. DEFAULT FOR "NEW": When user says "new", "new cats", "new listings", "recently added", "just posted", or similar phrases referring to recently added cats, set "animals.updatedDate" filter to "Week" (meaning updated within the last 7 days)
       8. Use the exact option values from the schema (case-sensitive)
       9. Return ONLY the JSON object, no other text or explanation
       10. If uncertain about a value, omit it rather than guessing
       11. For OR conditions with list filters, return an array: ["Value1", "Value2"]
       12. For AND conditions or single requirements, return a string: "Value"
       
       PERSONALITY FILTERS (priority when user describes personality):
       - For the non-slider personality dropdowns, use "Yes" when the user wants the trait, "No" when the user asks for the opposite of that trait, and "Any" when they have no preference. Do NOT map these to breed.
      - Phrases about wanting affection WITHOUT clinginess or constant contact such as "affectionate but not constantly in my face", "not clingy", "not needy", "likes cuddles on their own terms" usually mean affectionate: "Yes" and lapCat: "No". If the wording clearly emphasizes wanting space or a self-directed cat, independentAloof: "Yes" can also fit.
      - Generic phrases like "has personality", "full of personality", or "fun personality" do NOT by themselves mean timidShy, curious, or independentAloof.
      - Phrases like "personality but not attitude", "playful but not spicy", "sweet but not sassy", or "some personality without drama" should bias toward gentleness: "Yes" and often playful: "Yes" or outgoing: "Yes". Do NOT interpret these as timidShy: "Yes", curious: "Yes", or independentAloof: "Yes" unless the user clearly asks for those traits.
       - "playful", "playful cat", "loves to play", "energetic cat", "lively" → playful: "Yes"
       - "affectionate", "affectionate cat", "cuddly", "snuggly", "loving", "lap cat" → affectionate: "Yes"
       - "calm", "calm cat", "quiet", "laid back", "relaxed" → calmness: "Yes" (and optionally energyLevel: "Low")
       - "not calm", "high energy", "hyper", "wild" → calmness: "No"
       - "curious", "curious cat", "mischievous", "gets into things" → curious: "Yes"
       - "not curious", "homebody", "low-key", "content to lounge" → curious: "No"
       - "gentle", "gentle cat", "sweet", "soft" → gentleness: "Yes"
       - "not gentle", "feisty", "spicy", "rowdy", "attitude", "sassy", "dramatic" → gentleness: "No"
       - "not sassy", "not spicy", "without attitude", "personality but not attitude" → gentleness: "Yes"
       - "outgoing", "friendly cat", "social cat" → outgoing: "Yes" (or newPeopleReaction: "Friendly" for stranger reaction)
      - "greets people", "greets guests", "good with new people", "friendly with strangers", "good with visitors", "comes to say hi", "greets at the door" → newPeopleReaction: "Friendly"
       - "shy", "timid cat", "reserved" → timidShy: "Yes"
       - "not shy", "confident", "bold", "fearless" → timidShy: "No"
      - For independence-related wording, always use the Independence slider output key (`personalityIndependence`), not a dropdown-style field.
      - "independent", "aloof", "self-sufficient" → personalityIndependence: 2
      - "very independent", "does own thing", "keeps to self", "prefers space" → personalityIndependence: 1
      - "not independent" → personalityIndependence: 1
      - "dependent", "wants company" → personalityIndependence: 4
      - "very dependent", "clingy", "needs company" → personalityIndependence: 5
       - "not a lap cat", "aloof", "prefers space", "independent" → lapCat: "No"
       - "not clingy", "not needy", "not in my face", "not constantly in my face" → lapCat: "No" and usually affectionate: "Yes" only if the query still asks for affection/cuddles
       - "ignores toys", "not playful with toys", "uninterested in toys" → likesToys: "No"
       
       TEN TRAITS (searchPageConfig field names; use these so the animation system highlights the correct filter row):
       Sliders (output key → searchPageConfig field): personalityEnergyLevel → energyLevel; personalityPlayfulness → playfulness; personalityAffectionate → affectionate; personalityIndependence → independence; personalitySociability → sociability; personalityVocalization → vocalLevel; personalityAdaptability → adaptability; personalityIntelligence → intelligence; personalityConfidence → confidence; personalitySensitivity → sensitivity.
       Yes/No/Any dropdowns (output key → searchPageConfig field): calmness → animals.descriptionText (Calmness); gentleness → animals.descriptionText (Gentleness); lapCat → animals.descriptionText (Lap Cat); likesToys → animals.descriptionText (Likes toys); timidShy → animals.descriptionText (Timid / shy); curious → animals.descriptionText (Curious).
       
       TEN TRAITS ON A 1-5 SCALE (personality sliders; analyze word intensity and output integer 1-5; 0 or omit = Any):
       The following 10 traits are personality SLIDERS (field in searchPageConfig in parentheses). Analyze words in the query that relate to each trait, evaluate the INTENSITY of those words, and set the corresponding filter to an integer 1-5. Use 0 or omit if the user does not mention that dimension.
       - Energy Level (field: energyLevel) (personalityEnergyLevel): "very lazy", "couch potato" → 1; "low energy" → 2; "moderate energy" → 3; "active", "high energy" → 4; "extremely active", "zoomies", "nonstop" → 5
       - Playfulness (field: playfulness) (personalityPlayfulness): "not playful", "serious" → 1; "low play" → 2; "moderately playful" → 3; "playful", "loves toys" → 4; "very playful", "toy addict", "always playing" → 5
       - Affection Level (field: affectionate) (personalityAffectionate): "not affectionate", "aloof" → 1; "low affection" → 2; "moderate cuddles" → 3; "affectionate", "cuddly", "lap cat" → 4; "very affectionate", "velcro", "constant cuddles" → 5
      - Independence (field: independence) (personalityIndependence): ALWAYS use the personalityIndependence slider only (never independentAloof). Scale: 1 = very independent / wants space, 5 = very dependent / clingy. "very independent", "does own thing", "keeps to self", "prefers space" → 1; "independent", "aloof", "self-sufficient" → 2; "balanced" → 3; "dependent", "wants company", "somewhat dependent" → 4; "very dependent", "clingy", "needs company", "velcro" → 5. If the user says "independence no", "not independent", or "I do not want an independent cat", map to 5 (very low on independence = very dependent).
       - Sociability (field: sociability) (personalitySociability): "very unsocial", "reclusive" → 1; "unsocial" → 2; "moderate" → 3; "social", "friendly" → 4; "very social", "loves everyone", "party cat" → 5
       - Vocality (field: vocalLevel) (personalityVocalization): ALWAYS set this when the user mentions how much the cat meows or talks. Prefer returning personalityVocalization as the output key so it maps directly to the Vocalization personality slider. "very quiet", "silent", "quiet house", "quiet home", "quiet household", "I have a quiet house", "we have a quiet house", "quiet environment", "need a quiet cat" → 1; "quiet" → 2; "moderate" → 3; "vocal", "talkative", "vocal cat", "talkative cat", "likes to meow", "meows", "communicative" → 4; "very talkative", "very vocal", "chatty", "meows a lot", "loquacious" → 5
       - Confidence (field: confidence) (personalityConfidence): "very shy", "timid", "skittish", "fearful" → 1; "shy", "reserved" → 2; "moderate", "balanced" → 3; "confident", "bold" → 4; "very confident", "fearless", "outgoing" → 5
       - Sensitivity (field: sensitivity) (personalitySensitivity): "very thick-skinned", "unfazed" → 1; "low sensitivity" → 2; "moderate" → 3; "sensitive", "gentle" → 4; "very sensitive", "delicate", "needs gentle handling" → 5
       - Adaptability (field: adaptability) (personalityAdaptability): "not adaptable", "set in ways" → 1; "low adaptability" → 2; "moderate" → 3; "adaptable", "adjusts well" → 4; "very adaptable", "easy transition", "goes with flow" → 5
      - Intelligence (field: intelligence) (personalityIntelligence): "dim", "slow" → 1; "below average" → 2; "average" → 3; "smart", "intelligent", "learns quickly" → 4; "very intelligent", "extremely intelligent", "puzzle solver", "bright", "brilliant", "genius" → 5
       Output these as integers in filters, e.g. "personalityEnergyLevel": 4, "personalityPlayfulness": 5. Omit or use 0 for Any.
       (Calmness/Gentleness/Timid Shy: use calmness, timidShy, gentleness as Yes/No/Any when user describes those traits without intensity; for intensity use the Confidence/Sensitivity sliders above.)
       
       KEYWORD MAPPING EXAMPLES (understand user intent):
       - "kitten", "baby cat", "young cat" → ageGroup: "Baby"
       - "calm", "quiet", "low energy", "laid back", "relaxed" (energy only) → energyLevel: "Low"
       - "active", "high energy" (without personality) → energyLevel: "High"
       - "black cat", "black" → colorDetails: "Black"
       - "white cat", "white" → colorDetails: "White"
       - "gray cat", "grey cat", "gray" → colorDetails: "Gray"
       - "red cat", "orange cat", "red", "orange", "ginger" → colorDetails: "Red"
       - "calico", "calico cat" → breed: "Calico" (Calico is a breed, not a color)
      - "friendly", "sociable", "greets people", "greets guests", "friendly with strangers", "good with visitors", "comes to say hi", "greets at the door" (stranger reaction) → newPeopleReaction: "Friendly"
       - "good with dogs", "dog friendly" → isDogsOk: "Yes"
       - "good with kids", "family friendly" → isKidsOk: "Yes"
       - "companion cat", "bonded pair", "must be adopted with another cat", "must come with another cat", "cat that needs to come with another cat" → needsCompanionAnimal: "Yes" (cat has to be adopted with another cat; they are companions).
       - "apartment", "apartment living", "apartment ok", "no yard", "condo", "small space", "good for apartments", "cat for apartment" → apartmentOk: "Yes" (cat suitable for apartment; does not need a yard).
       - "quiet house", "quiet home", "quiet household", "I have a quiet house", "we have a quiet house", "quiet environment", "need a quiet cat" → personalityVocalization: 1 (very low vocality; user wants a cat that won't be noisy).
       - "vocal", "talkative", "vocal cat", "talkative cat", "I want a vocal cat", "I want a talkative cat", "chatty", "meows a lot", "likes to meow" → personalityVocalization: 4 (or 5 if "very"); set the Vocalization slider. Do NOT only return breed—always include the Vocalization personality slider when user mentions vocal/talkative.
      - "independent", "aloof", "self-sufficient", "prefers space" → personalityIndependence: 1 or 2 depending on intensity; prefer the Independence personality slider, not independentAloof.
      - "not independent", "independence no", "I do not want an independent cat" → personalityIndependence: 5 (very dependent).
      - "dependent", "clingy", "needs company" → personalityIndependence: 4 or 5 depending on intensity.
      - "intelligent", "smart", "learns quickly" → personalityIntelligence: 4; "very intelligent", "extremely intelligent", "brilliant", "genius" → personalityIntelligence: 5.
      - "affectionate but not constantly in my face", "cuddly but not clingy", "likes affection on their own terms" → affectionate: "Yes", lapCat: "No"
      - "a cat with personality but not attitude", "playful but not spicy", "sweet but not sassy" → gentleness: "Yes" and often playful: "Yes"; do not set timidShy, curious, or independentAloof unless separately requested.
       
       FAMOUS CAT CHARACTERS / "cat like X": When the user asks for a cat like a famous character, map to that character's defining traits (breed, color, energy). Examples:
       - "Garfield", "cat like Garfield", "I want a cat like Garfield" → low energy, red/orange coat, Exotic Shorthair breed: {"filters": {"breed": "Exotic Shorthair", "colorDetails": "Red", "personalityEnergyLevel": 2}} or energyLevel: "Low".
       
       BREED BY PERSONALITY/SAYINGS (use only when user asks for a BREED by trait, not for "I want a playful cat"):
       - Use breed from personalitySayings when: user names a breed, or asks "what breed", "which breed", "playful breed", "breed that is X". For "I want a playful cat" or "show me affectionate cats", use personality filters (playful: "Yes", affectionate: "Yes"), NOT breed.
       - When a trait matches ONLY ONE breed: return breed as a string (e.g. "go limp when held" → breed: "Ragdoll", "gentle giant" → breed: "Maine Coon", "Meezer" → breed: "Siamese", "hairless" → breed: "Sphynx", "curled ears" → breed: "American Curl", "folded ears" → breed: "Scottish Fold", "short legs" → breed: "Munchkin", "good luck cat" → breed: "Korat"). IMPORTANT: If user says "vocal" or "talkative" or "talkative cat" as a personality preference (e.g. "I want a vocal cat"), set personalityVocalization: 4 or 5 in filters; do not only return breed. "Meezer" by name → breed: "Siamese"; "I want a talkative cat" → filters must include personalityVocalization: 4 or 5.
       - When a trait matches MULTIPLE breeds and user is asking for breed: return breed as an ARRAY. Example: "dog-like cat" (breed question) → breed: ["Ragdoll", "Maine Coon", "Bobtail", "Norwegian Forest", "Ocicat"].
       
       EXAMPLE QUERIES:
       - "I want a playful cat" → {"filters": {"playful": "Yes"}}
       - "show me affectionate cats" → {"filters": {"affectionate": "Yes"}}
       - "playful and cuddly cat" → {"filters": {"playful": "Yes", "affectionate": "Yes"}}
       - "I want a calm black kitten" → {"filters": {"ageGroup": "Baby", "calmness": "Yes", "colorDetails": "Black"}}
       - "show me cats that are not shy" → {"filters": {"timidShy": "No"}}
       - "I want a cat that is not a lap cat" → {"filters": {"lapCat": "No"}}
       - "show me cats that ignore toys" → {"filters": {"likesToys": "No"}}
       - "I want a cat that is not curious" → {"filters": {"curious": "No"}}
       - "show me friendly white cats" → {"filters": {"newPeopleReaction": "Friendly", "colorDetails": "White"}}
       - "active Persian cats near me" → {"location": {"distance": "20"}, "filters": {"breed": "Persian", "energyLevel": "High"}}
       - "calico cats", "I want a calico" → {"filters": {"breed": "Calico"}}
       - "cat that goes limp when you hold it", "I want a ragdoll type", "docile floppy cat" → {"filters": {"breed": "Ragdoll"}}
       - "gentle giant", "big fluffy cat" (only Maine Coon) → {"filters": {"breed": "Maine Coon"}}
       - "Meezer" (breed name) → {"filters": {"breed": "Siamese"}}. "I want a vocal cat", "talkative cat", "I want a talkative cat" (personality) → {"filters": {"personalityVocalization": 4}}
       - "dog-like cat", "cat that acts like a dog" (matches multiple breeds) → {"filters": {"breed": ["Ragdoll", "Maine Coon", "Bobtail", "Norwegian Forest", "Ocicat"]}}
       - "I want a cat like Garfield", "cat like Garfield", "like Garfield" → {"filters": {"breed": "Exotic Shorthair", "colorDetails": "Red", "personalityEnergyLevel": 2}}
       - "companion cat", "bonded pair", "cat that has to come with another cat" → {"filters": {"needsCompanionAnimal": "Yes"}}
       - "apartment cat", "cat for apartment", "I live in an apartment", "no yard" → {"filters": {"apartmentOk": "Yes"}}
       - "I have a quiet house", "quiet home", "we need a quiet cat", "quiet household" → {"filters": {"personalityVocalization": 1}}
       - "I want a vocal cat", "talkative cat", "vocal", "talkative", "show me talkative cats" → {"filters": {"personalityVocalization": 4}}
      - "I want an independent cat" → {"filters": {"personalityIndependence": 2}}
      - "I want a very independent cat that likes space" → {"filters": {"personalityIndependence": 1}}
      - "independence no" → {"filters": {"personalityIndependence": 5}}
      - "I do not want an independent cat" → {"filters": {"personalityIndependence": 5}}
      - "I want a clingy cat that needs company" → {"filters": {"personalityIndependence": 5}}
      - "I want a curious and very intelligent cat" → {"filters": {"curious": "Yes", "personalityIntelligence": 5}}
      - "affectionate but not constantly in my face" → {"filters": {"affectionate": "Yes", "lapCat": "No"}}
      - "a cat with personality but not attitude" → {"filters": {"gentleness": "Yes", "playful": "Yes"}}
      - "I want a quiet cat that still greets people" → {"filters": {"personalityVocalization": 1, "newPeopleReaction": "Friendly"}}
      - "quiet cat that comes to say hi to visitors" → {"filters": {"personalityVocalization": 1, "newPeopleReaction": "Friendly"}}
''';

    try {
      final prompt =
          '$systemPrompt\n\nUser query: $query\n\nReturn ONLY valid JSON:';
      final content = [Content.text(prompt)];

      // Edge case: Timeout handling
      final response = await _model.generateContent(content).timeout(_timeout,
          onTimeout: () {
        throw TimeoutException(
            'AI request timed out after ${_timeout.inSeconds} seconds');
      });

      String responseText = response.text ?? '{}';
      print('🤖 Raw AI response: $responseText');

      // Edge case: Empty response
      if (responseText.trim().isEmpty) {
        print('⚠️ AI returned empty response');
        return _emptyResponse();
      }

      // Edge case: Extract JSON from response (handle markdown code blocks)
      responseText = _extractJSON(responseText);
      print('🤖 Extracted JSON: $responseText');

      // Edge case: Validate JSON structure
      final jsonData = jsonDecode(responseText) as Map<String, dynamic>;
      print('🤖 Parsed JSON (Gemini): $jsonData');
      return jsonData;
    } on TimeoutException catch (e) {
      print('AI request timeout: $e');
      return _emptyResponse();
    } on FormatException catch (e) {
      print('JSON parsing error: $e');
      return _emptyResponse();
    } on Exception catch (e) {
      print('Error parsing search query: $e');

      // If model error, try next model in fallback list
      final errorMsg = e.toString();
      
      // CRITICAL: If API key is leaked/invalid, stop immediately - no point retrying
      if (errorMsg.contains('leaked') || errorMsg.contains('API key was reported')) {
        print('');
        print('🚨 CRITICAL: API KEY ISSUE DETECTED');
        print('Your API key was reported as leaked or invalid.');
        print('⚠️ You MUST regenerate your API key before the AI search will work.');
        print('📝 Steps to fix:');
        print('   1. Go to: https://aistudio.google.com/app/apikey');
        print('   2. Delete the old API key');
        print('   3. Create a new API key');
        print('   4. Update the key in config.dart');
        print('');
        return _emptyResponse();
      }
      
      if (errorMsg.contains('not found') ||
          errorMsg.contains('not supported') ||
          errorMsg.contains('permission denied') ||
          errorMsg.contains('API key')) {
        print('');
        print('⚠️ MODEL ERROR DETECTED');
        print('Current model: ${_modelCandidates[_currentModelIndex]}');
        
        // Try next model in fallback list
        if (_currentModelIndex < _modelCandidates.length - 1) {
          final nextModelIndex = _currentModelIndex + 1;
          final nextModelName = _modelCandidates[nextModelIndex];
          print('🔄 Attempting fallback to: $nextModelName');
          
          try {
            final apiKey = AppConfig.geminiApiKey;
            _model = GenerativeModel(
              model: nextModelName,
              apiKey: apiKey,
            );
            _currentModelIndex = nextModelIndex;
            print('✅ Switched to model: $nextModelName');
            print('🔄 Retrying query with new model...');
            
            // Retry the query with the new model (prevent infinite recursion)
            if (retryCount < _modelCandidates.length - 1) {
              return await _parseSearchQueryViaGemini(query, retryCount: retryCount + 1);
            } else {
              print('⚠️ Max retries reached, returning empty response');
              return _emptyResponse();
            }
          } catch (retryError) {
            print('❌ Fallback model also failed: $retryError');
            if (nextModelIndex == _modelCandidates.length - 1) {
              print('❌ All model candidates exhausted.');
              print('Possible solutions:');
              print('1. Check your API key has access to Gemini models');
              print('2. Try regenerating your API key from: https://aistudio.google.com/app/apikey');
              print('3. Ensure Generative Language API is enabled in Google Cloud Console');
            }
          }
        } else {
          print('❌ All model candidates failed.');
          print('Possible solutions:');
          print('1. Check your API key has access to Gemini models');
          print('2. Try regenerating your API key from: https://aistudio.google.com/app/apikey');
          print('3. Ensure Generative Language API is enabled in Google Cloud Console');
        }
        print('');
      }

      return _emptyResponse();
    }
  }

  /// Extract JSON from various response formats
  String _extractJSON(String responseText) {
    // Remove markdown code blocks
    responseText = responseText.replaceAll(RegExp(r'```json\s*'), '');
    responseText = responseText.replaceAll(RegExp(r'```\s*'), '');
    responseText = responseText.trim();

    // Try to find JSON object
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(responseText);
    if (jsonMatch != null) {
      return jsonMatch.group(0)!;
    }

    // If no JSON found, try to parse as-is
    return responseText;
  }

  /// Normalize and validate response structure
  Future<Map<String, dynamic>> _normalizeResponse(
      Map<String, dynamic> data) async {
    final normalized = <String, dynamic>{
      'location': <String, dynamic>{},
      'filters': <String, dynamic>{},
    };

    // Pass through catType (personality type by name) if present
    if (data.containsKey('catType') &&
        data['catType'] != null &&
        data['catType'].toString().trim().isNotEmpty) {
      normalized['catType'] = data['catType'].toString().trim();
    }

    // Normalize location (use _toMap to handle Map<dynamic,dynamic> from JSON/Cloud)
    final locationRaw = data['location'];
    if (locationRaw != null && locationRaw is Map) {
      final location = _deepMapStringDynamic(locationRaw as Map) ?? <String, dynamic>{};
      if (location.containsKey('zip')) {
        final zip = location['zip'].toString().trim();

        // Check if it's a valid ZIP code format (5 digits)
        if (_isValidZipCode(zip)) {
          normalized['location']!['zip'] = zip;
        } else {
          // If not a ZIP code format, it might be a city name - try to look it up
          print(
              '🔍 ZIP field contains non-ZIP value: $zip, attempting city lookup...');
          final cityZip = await getZipCodeFromCity(zip);
          if (cityZip != null) {
            normalized['location']!['zip'] = cityZip;
            print('✅ Converted city "$zip" to ZIP code: $cityZip');
          } else {
            print('❌ Could not find ZIP code for city: $zip');
          }
        }
      }
      if (location.containsKey('distance')) {
        final distance = _parseDistance(location['distance']);
        if (distance != null) {
          normalized['location']!['distance'] = distance.toString();
        }
      }
    }

    // Normalize filters (use _deepMapStringDynamic to handle Map<dynamic,dynamic> from JSON/Cloud)
    final filtersRaw = data['filters'];
    if (filtersRaw != null && filtersRaw is Map) {
      final filters = _deepMapStringDynamic(filtersRaw as Map) ?? <String, dynamic>{};
      filters.forEach((key, value) {
        if (value == null) return;

        // catType in filters: lift to top-level and do not add to filters
        if (key == 'catType') {
          if (value.toString().trim().isNotEmpty) {
            normalized['catType'] = value.toString().trim();
          }
          return;
        }

        // Preserve arrays as-is (for OR conditions)
        if (value is List) {
          print('🤖 Preserving array for $key: $value');
          normalized['filters']![key] = value;
          return;
        }

        // Handle single values
        if (value.toString().trim().isNotEmpty) {
          final normalizedValue = value.toString().trim();
          // Edge case: Skip "Any", null, or empty values
          if (normalizedValue.toLowerCase() != 'any' &&
              normalizedValue.toLowerCase() != 'null' &&
              normalizedValue.isNotEmpty) {
            normalized['filters']![key] = normalizedValue;
          }
        }
      });
    }

    return normalized;
  }

  /// Validate ZIP code format
  bool _isValidZipCode(String zip) {
    // US ZIP code validation (5 digits or 5+4 format)
    final zipRegex = RegExp(r'^\d{5}(-\d{4})?$');
    return zipRegex.hasMatch(zip);
  }

  /// Parse and validate distance value
  String? _parseDistance(dynamic distance) {
    if (distance == null) return null;

    final distanceStr = distance.toString().trim();

    // Extract number from string (e.g., "20 miles" -> "20")
    final numberMatch = RegExp(r'\d+').firstMatch(distanceStr);
    if (numberMatch != null) {
      final numValue = int.tryParse(numberMatch.group(0)!);
      if (numValue != null && numValue > 0 && numValue <= 1000) {
        return numValue.toString();
      }
    }

    return null;
  }

  /// Return empty response structure
  Map<String, dynamic> _emptyResponse() {
    return {
      'location': <String, dynamic>{},
      'filters': <String, dynamic>{},
    };
  }

  /// Look up ZIP code from a city name (e.g., "Los Angeles", "New York", "San Francisco")
  /// Returns the first valid ZIP code found, or null if not found
  Future<String?> getZipCodeFromCity(String cityName) async {
    try {
      print('🔍 Looking up ZIP code for city: $cityName');

      // Add "USA" or "US" to improve geocoding accuracy
      String searchQuery = cityName.trim();
      if (!searchQuery.toLowerCase().contains('usa') &&
          !searchQuery.toLowerCase().contains('united states') &&
          !searchQuery.toLowerCase().contains(', us')) {
        searchQuery = '$cityName, USA';
      }

      // Use geocoding to convert city name to coordinates, then get placemark with ZIP
      List<Location> locations = await locationFromAddress(searchQuery).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('⚠️ Geocoding timeout for: $cityName');
          return <Location>[];
        },
      );

      if (locations.isEmpty) {
        print('❌ No locations found for: $cityName');
        return null;
      }

      // Get placemark from coordinates to extract ZIP code
      List<Placemark> placemarks = await placemarkFromCoordinates(
        locations.first.latitude,
        locations.first.longitude,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('⚠️ Placemark lookup timeout for: $cityName');
          return <Placemark>[];
        },
      );

      if (placemarks.isEmpty) {
        print('❌ No placemarks found for: $cityName');
        return null;
      }

      final zipCode = placemarks.first.postalCode;
      if (zipCode != null && zipCode.isNotEmpty) {
        print('✅ Found ZIP code for $cityName: $zipCode');
        return zipCode;
      }

      print('❌ No ZIP code in placemark for: $cityName');
      return null;
    } catch (e) {
      print('❌ Error looking up ZIP code for $cityName: $e');
      return null;
    }
  }
}
