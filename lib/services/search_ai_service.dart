import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:geocoding/geocoding.dart';
import '../config.dart';

class SearchAIService {
  static final SearchAIService _instance = SearchAIService._internal();
  factory SearchAIService() => _instance;
  SearchAIService._internal();

  static Duration get _timeout => const Duration(seconds: 10);
  late GenerativeModel _model;
  bool _initialized = false;
  int _currentModelIndex = 0;
  static const List<String> _modelCandidates = [
    'gemini-2.0-flash-exp', // Preferred: was working well for query understanding
    'gemini-2.0-flash',     // Fallback 1: stable version of 2.0
    'gemini-2.5-flash',     // Fallback 2: newer stable version (recommended)
    'gemini-1.5-pro',       // Fallback 3: more capable but slower
    'gemini-1.5-flash',     // Fallback 4: faster but less capable
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
        print('   String.fromEnvironment("GEMINI_API_KEY"): "${keyFromDefine.isEmpty ? "empty" : (keyFromDefine.length > 15 ? keyFromDefine.substring(0, 15) + "..." : keyFromDefine)}"');
        print('   Platform.environment["GEMINI_API_KEY"]: "${keyFromEnv == null ? "null" : (keyFromEnv.isEmpty ? "empty" : (keyFromEnv.length > 15 ? keyFromEnv.substring(0, 15) + "..." : keyFromEnv))}"');
        print('   Final apiKey from AppConfig: "${apiKey.isEmpty ? "empty" : (apiKey.length > 15 ? apiKey.substring(0, 15) + "..." : apiKey)}"');
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

  /// List available models for debugging
  Future<void> _listAvailableModels(String apiKey) async {
    try {
      print('\n🔍 Checking available Gemini models...');
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey');
      final response = await http.get(url).timeout(const Duration(seconds: 5));

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
    } catch (e) {
      print('⚠️ Error listing models: $e');
      print(
          '   This might indicate the Generative Language API is not enabled.');
    }
  }

  /// Parse natural language search with comprehensive error handling
  Future<Map<String, dynamic>> parseSearchQuery(String query, {int retryCount = 0}) async {
    // Edge case: Empty or whitespace-only query
    if (query.trim().isEmpty) {
      return _emptyResponse();
    }

    // Edge case: Query too long (prevent excessive API calls)
    if (query.length > 500) {
      query = query.substring(0, 500);
    }

    if (!_initialized) {
      throw Exception(
          'SearchAIService not initialized. Call initialize() first.');
    }

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
      "description": "Restrict search results to cats of a specific breed.",
      "options": [],
      "keywords": {
        "positive": ["breed", "ragdoll", "siamese", "persian", "maine coon"],
        "negative": ["any breed", "all breeds"]
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
    "affectionate": {
      "field": "animals.affectionate",
      "description": "How loving or people-oriented the cat is.",
      "options": ["Yes", "No", "Any"],
      "keywords": {
        "positive": ["affectionate", "cuddly", "snuggly", "lap cat", "friendly"],
        "negative": ["independent", "aloof", "not cuddly", "distant"]
      }
    },
    "playful": {
      "field": "animals.playful",
      "description": "How much the cat enjoys playing and interaction.",
      "options": ["Yes", "No", "Any"],
      "keywords": {
        "positive": ["playful", "active", "energetic", "likes toys"],
        "negative": ["lazy", "not playful", "calm"]
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
    "exerciseNeeds": {
      "field": "animals.exerciseNeeds",
      "description": "Amount of exercise or playtime typically required.",
      "options": ["Not Required", "Low", "Medium", "High", "Any"],
      "keywords": {
        "positive": ["needs play", "needs activity", "active cat"],
        "negative": ["low energy", "not active", "couch cat"]
      }
    },
    "vocalLevel": {
      "field": "animals.vocalLevel",
      "description": "How vocal or talkative the cat is.",
      "options": ["Quiet", "Some", "Lots", "Any"],
      "keywords": {
        "positive": ["quiet", "silent", "soft meow"],
        "negative": ["talkative", "loud", "chatty"]
      }
    },
    "newPeopleReaction": {
      "field": "animals.newPeopleReaction",
      "description": "How the cat reacts to strangers or new people.",
      "options": ["Cautious", "Friendly", "Protective", "Aggressive", "Any"],
      "keywords": {
        "positive": ["friendly", "sociable", "trusting"],
        "negative": ["shy", "timid", "hides from strangers"]
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
    "ownerExperience": {
      "field": "animals.ownerExperience",
      "description": "How experienced an owner should be with cats or breeds.",
      "options": ["None", "Species", "Breed", "Any"],
      "keywords": {
        "positive": ["experienced", "knows cats", "familiar with breed"],
        "negative": ["first-time owner", "new to cats"]
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
    "colorDetails": {
      "field": "animals.colorDetails",
      "description": "Primary or secondary color pattern of the cat's coat.",
      "options": ["Black","Black and White","Tuxedo","Blue","Gray","Brown","Brown Tabby","Calico","Cream","Ivory","Silver Tabby","Red Tabby","Spotted","Tan","Fawn","Tortoiseshell","White","Any"],
      "keywords": {
        "positive": ["black cat","gray cat","white cat","tuxedo","tabby"],
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
    "hypoallergenic": {
      "field": "animals.hypoallergenic",
      "description": "Indicates if the cat produces fewer allergens.",
      "options": ["Yes","No","Any"],
      "keywords": {
        "positive": ["hypoallergenic","good for allergies","allergy friendly"],
        "negative": ["not hypoallergenic","allergenic"]
      }
    },
    "hasAllergies": {
      "field": "animals.hasAllergies",
      "description": "Indicates if the cat has known allergies.",
      "options": ["Yes","No","Any"],
      "keywords": {
        "positive": ["cat has allergies","food allergy","special care"],
        "negative": ["no allergies"]
      }
    },
    "hearingImpaired": {
      "field": "animals.hearingImpaired",
      "description": "Indicates if the cat is partially or fully deaf.",
      "options": ["Yes","No","Any"],
      "keywords": {
        "positive": ["deaf","hearing loss"],
        "negative": ["normal hearing"]
      }
    },
    "ongoingMedical": {
      "field": "animals.ongoingMedical",
      "description": "Whether the cat requires ongoing medical treatment.",
      "options": ["Yes","No","Any"],
      "keywords": {
        "positive": ["medical needs","requires medication","special care"],
        "negative": ["healthy","no medical needs"]
      }
    },
    "specialDiet": {
      "field": "animals.specialDiet",
      "description": "Whether the cat requires a specific diet.",
      "options": ["Yes","No","Any"],
      "keywords": {
        "positive": ["special diet","prescription food","dietary restriction"],
        "negative": ["normal diet","no special diet"]
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
    "isDeclawed": {
      "field": "animals.declawed",
      "description": "Whether the cat has been declawed.",
      "options": ["Yes","No","Any"],
      "keywords": {
        "positive": ["declawed"],
        "negative": ["clawed","has claws"]
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
    "isBreedMixed": {
      "field": "animals.breedMixed",
      "description": "Whether the cat is a mix of multiple breeds.",
      "options": ["Yes","No","Any"],
      "keywords": {
        "positive": ["mixed breed","domestic mix"],
        "negative": ["purebred"]
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
    "obedienceTraining": {
      "field": "animals.obedienceTraining",
      "description": "Level of obedience training the cat has received.",
      "options": ["Needs","Basic","Well","Any"],
      "keywords": {
        "positive": ["needs training","basic training","well trained","trained"],
        "negative": ["no training preference"]
      }
    },
    "earType": {
      "field": "animals.earType",
      "description": "Shape or condition of the cat's ears.",
      "options": ["Cropped","Droopy","Erect","Long","Missing","Notched","Rose","Semi-erect","Tipped","Natural/Uncropped","Any"],
      "keywords": {
        "positive": ["cropped ears","droopy ears","erect ears","folded ears","straight ears"],
        "negative": ["no ear preference"]
      }
    }
  }
}
''';

    const systemPrompt = '''
You are a cat adoption search assistant. Your job is to carefully understand the user's natural language query and extract all relevant search filters and location information.

IMPORTANT: Pay close attention to what the user is asking for. Understand the intent behind their words, not just keywords.

Use this schema structure:
$schemaDefinition

Return JSON in this exact format:
{
  "location": {
    "zip": "94040",
    "distance": "20"
  },
  "filters": {
    "breed": "Persian",
    "sizeGroup": "Medium",
    "ageGroup": "Adult",
    "sex": "Female",
    "coatLength": "Long",
    "affectionate": "Yes",
    "playful": "Yes",
    "energyLevel": "Medium",
    "isDogsOk": "Yes",
    "isKidsOk": "Yes",
    "colorDetails": "White",
    "isHousetrained": "Yes"
  }
}

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
  * vocalLevel (e.g., ["Quiet", "Some", "Lots"])
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
  * "quiet or some vocalization" → {"vocalLevel": ["Quiet", "Some"]}
  * "low or medium grooming needs" → {"groomingNeeds": ["Low", "Medium"]}
  * "none or some shedding" → {"sheddingLevel": ["None", "Some"]}
- CRITICAL: When user uses "or" with ANY of the filters listed above, you MUST return an array with ALL the options mentioned
- If user says "black and white" (together as a phrase), that's a pattern name like "Black and White" or "Tuxedo" - use single value "Black and White"
- For single-select filters that don't support OR (like sex), use a single value only

       Rules:
       1. Only include filters that are explicitly mentioned or can be inferred from the query
       2. Use "Any" or omit the field if not specified
       3. For breed, match breed names exactly (e.g., "Persian", "Siamese", "Maine Coon")
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
       
       KEYWORD MAPPING EXAMPLES (understand user intent):
       - "kitten", "baby cat", "young cat" → ageGroup: "Baby"
       - "calm", "quiet", "low energy", "laid back", "relaxed" → energyLevel: "Low"
       - "active", "energetic", "high energy", "playful" → energyLevel: "High"
       - "black cat", "black" → colorDetails: "Black"
       - "white cat", "white" → colorDetails: "White"
       - "gray cat", "grey cat", "gray" → colorDetails: "Gray"
       - "affectionate", "cuddly", "snuggly", "lap cat" → affectionate: "Yes"
       - "friendly", "sociable" → newPeopleReaction: "Friendly"
       - "good with dogs", "dog friendly" → isDogsOk: "Yes"
       - "good with kids", "family friendly" → isKidsOk: "Yes"
       
       EXAMPLE QUERIES:
       - "I want a calm black kitten" → {"filters": {"ageGroup": "Baby", "energyLevel": "Low", "colorDetails": "Black"}}
       - "show me friendly white cats" → {"filters": {"newPeopleReaction": "Friendly", "colorDetails": "White"}}
       - "active Persian cats near me" → {"location": {"distance": "20"}, "filters": {"breed": "Persian", "energyLevel": "High"}}
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
      print('🤖 Parsed JSON: $jsonData');

      // Edge case: Normalize and validate response structure
      final normalized = await _normalizeResponse(jsonData);
      print('🤖 Normalized response: $normalized');
      return normalized;
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
              return await parseSearchQuery(query, retryCount: retryCount + 1);
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

    // Normalize location
    if (data.containsKey('location') && data['location'] is Map) {
      final location = data['location'] as Map<String, dynamic>;
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

    // Normalize filters
    if (data.containsKey('filters') && data['filters'] is Map) {
      final filters = data['filters'] as Map<String, dynamic>;
      filters.forEach((key, value) {
        if (value == null) return;

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
