import 'dart:async';

import "package:firebase_auth/firebase_auth.dart";
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_map_dynamic_key/google_map_dynamic_key.dart';
import 'package:flutter_network_connectivity/flutter_network_connectivity.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/search_ai_service.dart';
import 'services/key_store_service.dart';
import 'services/cat_type_filter_mapping.dart';
import 'services/personality_fit_scorer.dart';
import 'theme.dart';
import 'network_utils.dart';
import 'screens/globals.dart' as globals;
import 'config.dart';
// Import webview platform implementations to ensure they're registered

import '/screens/adoptGrid.dart';
import '/screens/breedList.dart';
import '/screens/fit.dart';
import '/screens/personality_fit.dart';
import '/screens/favoritesList.dart';
import '/screens/shelters_near_you_screen.dart';
import '/widgets/gold/gold_circle_icon_button.dart';

FirebaseAuth? auth;
// final gsi.GoogleSignIn googleSignIn = gsi.GoogleSignIn();

final RouteObserver<ModalRoute> routeObserver = RouteObserver<ModalRoute>();

/// If non-null, startup failed critically; show blocking screen and do not let user continue.
/// User must correct the situation and tap Retry (or close the app).
String? startupFailureMessage;

/// Retries the startup steps that can fail due to network. Returns true if retry succeeded.
Future<bool> retryStartup() async {
  startupFailureMessage = null;

  try {
    final connectivity = FlutterNetworkConnectivity(
      isContinousLookUp: false,
      lookUpDuration: const Duration(seconds: 5),
    );
    final hasNetwork = await connectivity.isInternetConnectionAvailable();
    if (hasNetwork != true) {
      startupFailureMessage =
          'No internet connection. Please check your network and try again.';
      return false;
    }
  } catch (e) {
    startupFailureMessage =
        'No internet connection. Please check your network and try again.';
    return false;
  }

  if (auth == null) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      auth = FirebaseAuth.instance;
    } catch (e) {
      print('Firebase initialization retry failed: $e');
      startupFailureMessage =
          'The app could not connect. Please check your internet connection and try again.';
      return false;
    }
  }

  await _initializeAuth();
  if (startupFailureMessage != null) return false;

  if (auth != null) {
    try {
      await KeyStoreService.instance.load();
      if (KeyStoreService.instance.loadFailedWithNetworkError) {
        startupFailureMessage =
            'The app could not load required data. Please check your internet connection and try again.';
        return false;
      }
      final mapsKey = KeyStoreService.instance.getKey('GOOGLE_MAPS_API_KEY');
      if (mapsKey.isNotEmpty) {
        try {
          await GoogleMapDynamicKey().setGoogleApiKey(mapsKey);
        } catch (e) {
          print('Google Maps API key set failed: $e');
        }
      }
    } catch (e) {
      print('KeyStore retry failed: $e');
      if (isNetworkError(e)) {
        startupFailureMessage =
            'The app could not load required data. Please check your internet connection and try again.';
        return false;
      }
    }
  }

  return true;
}

class _ManualZipResult {
  final String zip;
  final bool skip;
  const _ManualZipResult(this.zip, {required this.skip});
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  // Block only on Firebase so the first frame can paint quickly (splash visible).
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    auth = FirebaseAuth.instance;
  } catch (e) {
    print('Firebase initialization failed: $e');
    auth = null;
  }

  // Lazy-load the rest of startup after first frame so splash appears immediately.
  final completer = Completer<void>();
  runApp(MyApp(initFuture: completer.future));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initializeAppRest().then((_) {
      if (!completer.isCompleted) completer.complete();
    }).catchError((e, st) {
      if (!completer.isCompleted) completer.complete();
    });
  });
}

/// Runs post-Firebase startup work in the background; splash stays visible until this completes.
Future<void> _initializeAppRest() async {
  // Explicit connectivity check: if device has no network (e.g. airplane mode),
  // show the failure screen immediately.
  try {
    final connectivity = FlutterNetworkConnectivity(
      isContinousLookUp: false,
      lookUpDuration: const Duration(seconds: 5),
    );
    final hasNetwork = await connectivity.isInternetConnectionAvailable();
    if (hasNetwork != true) {
      startupFailureMessage =
          'No internet connection. Please check your network and try again.';
      return;
    }
  } catch (e) {
    startupFailureMessage =
        'No internet connection. Please check your network and try again.';
    return;
  }

  if (auth == null) {
    startupFailureMessage ??=
        'The app could not connect. Please check your internet connection and try again.';
    return;
  }

  await _initializeAuth();
  if (startupFailureMessage != null) return;

  if (auth != null) {
    try {
      await KeyStoreService.instance.seedFromDefinesIfEnabled();
      await KeyStoreService.instance.load();
      if (KeyStoreService.instance.loadFailedWithNetworkError) {
        startupFailureMessage ??=
            'The app could not load required data. Please check your internet connection and try again.';
        return;
      }
      final mapsKey = KeyStoreService.instance.getKey('GOOGLE_MAPS_API_KEY');
      if (mapsKey.isNotEmpty) {
        try {
          await GoogleMapDynamicKey().setGoogleApiKey(mapsKey);
        } catch (e) {
          print('Google Maps API key set failed: $e');
        }
      }
    } catch (e) {
      print('KeyStore initialization failed: $e');
      if (isNetworkError(e)) {
        startupFailureMessage ??=
            'The app could not load required data. Please check your internet connection and try again.';
        return;
      }
    }
  }

  try {
    final searchAIService = SearchAIService();
    searchAIService.initialize();
  } catch (e) {
    print('AI service initialization failed: $e');
  }

  try {
    await Hive.openBox('cat_fit_scores');
  } catch (e) {
    print('Hive cat_fit_scores box open failed: $e');
  }

  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('searchAnimationShownThisSession', false);
  await prefs.setString('appStartTime', DateTime.now().toIso8601String());

  await globals.FelineFinderServer.instance.loadZipCodeFromPrefs();

  await globals.FelineFinderServer.instance.loadPersonalityFitSlidersFromPrefs();
  // Run personality fit from saved sliders and store scores so Personality Fit screen shows updated cat type cards.
  try {
    final server = globals.FelineFinderServer.instance;
    final scores = PersonalityFitScorer.computeScores(server);
    server.setLastPersonalityFitScores(scores);
  } catch (e) {
    print('Personality fit at startup failed: $e');
  }
}

Future<void> _initializeAuth() async {
  if (auth == null) {
    print("Firebase Auth not available");
    return;
  }

  // Check for persistent anonymous user ID
  final prefs = await SharedPreferences.getInstance();
  var storedAnonymousUID = prefs.getString('anonymous_user_uid');

  // Clear any fallback UIDs on startup
  if (storedAnonymousUID != null &&
      storedAnonymousUID.startsWith('fallback-')) {
    print('⚠️ Found invalid fallback UID in storage, clearing it');
    await prefs.remove('anonymous_user_uid');
    storedAnonymousUID = null;
  }

  final user = auth!.currentUser;

  // If we have a stored UID but no current user, try to restore
  if (user == null) {
    if (storedAnonymousUID != null && storedAnonymousUID.isNotEmpty) {
      print("Found stored anonymous UID: $storedAnonymousUID");
      // Firebase anonymous auth should persist, but if it doesn't, create new
      // The stored UID will be used for data operations
      await _signinAnon();
    } else {
      // First time user - sign in anonymously and store the UID
      await _signinAnon();
      final newUser = auth!.currentUser;
      if (newUser != null) {
        await prefs.setString('anonymous_user_uid', newUser.uid);
        print("Stored new anonymous UID: ${newUser.uid}");
      }
    }
  } else {
    // User exists - ensure UID is stored for persistence
    if (storedAnonymousUID != user.uid) {
      await prefs.setString('anonymous_user_uid', user.uid);
      print("Updated stored anonymous UID: ${user.uid}");
    }
  }
}

Future<void> _signinAnon() async {
  if (auth == null) {
    print("Firebase Auth not available, skipping anonymous sign-in");
    return;
  }
  try {
    await auth!.signInAnonymously();
    print("Signed in with temporary account.");
  }   on FirebaseAuthException catch (e) {
    if (isNetworkError(e)) {
      startupFailureMessage ??=
          'The app could not sign in. Please check your internet connection and try again.';
    }
    switch (e.code) {
      case "operation-not-allowed":
        print("Anonymous auth hasn't been enabled for this project.");
        break;
      case "keychain-error":
        print("⚠️ iOS Keychain error - this is often a simulator issue.");
        print("   The app will continue but authentication may not persist.");
        print("   On a real device, check keychain access permissions.");
        // Continue anyway - the app can still work with fallback UID
        break;
      default:
        print("Firebase Auth error: ${e.code} - ${e.message}");
        print("Stack trace: ${e.stackTrace}");
    }
  } catch (e, stackTrace) {
    if (isNetworkError(e)) {
      startupFailureMessage ??=
          'The app could not sign in. Please check your internet connection and try again.';
    }
    print("Unexpected error during anonymous sign-in: $e");
    print("Error type: ${e.runtimeType}");
    print("Stack trace: $stackTrace");
  }
}

/// Full-screen blocking message when startup failed. Message stays until user corrects the situation and Retry succeeds.
class _StartupFailureScreen extends StatefulWidget {
  final String message;
  final VoidCallback onRetrySuccess;

  const _StartupFailureScreen({
    required this.message,
    required this.onRetrySuccess,
  });

  @override
  State<_StartupFailureScreen> createState() => _StartupFailureScreenState();
}

class _StartupFailureScreenState extends State<_StartupFailureScreen> {
  bool _retrying = false;

  Future<void> _onRetry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    final success = await retryStartup();
    if (!mounted) return;
    setState(() => _retrying = false);
    if (success) {
      widget.onRetrySuccess();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Still no connection. Check your network and try again.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey[900],
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, size: 64, color: Colors.orange[300]),
              const SizedBox(height: 24),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Please correct the situation and tap Retry. The message will not go away until the app can start successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),
              FilledButton.icon(
                onPressed: _retrying ? null : _onRetry,
                icon: _retrying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh),
                label: Text(_retrying ? 'Retrying…' : 'Retry'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _retrying ? null : () => SystemNavigator.pop(),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Close app'),
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows splash image full-screen until [initFuture] completes, then [child] or startup failure screen.
class _SplashUntilReady extends StatefulWidget {
  final Future<void> initFuture;
  final Widget child;

  const _SplashUntilReady({required this.initFuture, required this.child});

  @override
  State<_SplashUntilReady> createState() => _SplashUntilReadyState();
}

class _SplashUntilReadyState extends State<_SplashUntilReady> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    widget.initFuture.then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Material(
        color: Colors.black,
        child: SizedBox.expand(
          child: Image.asset(
            'assets/splash/splash.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.expand(),
          ),
        ),
      );
    }
    if (startupFailureMessage != null) {
      return _StartupFailureScreen(
        message: startupFailureMessage!,
        onRetrySuccess: () => setState(() {}),
      );
    }
    return widget.child;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key, this.initFuture}) : super(key: key);

  final Future<void>? initFuture;

  @override
  Widget build(BuildContext context) {
    final home = initFuture != null
        ? _SplashUntilReady(initFuture: initFuture!, child: const HomeScreen(title: 'Feline Finder'))
        : const HomeScreen(title: 'Feline Finder');

    return GetMaterialApp(
      title: 'Feline Finder',
      showPerformanceOverlay: false,
      theme: ThemeData(
        fontFamily: 'Poppins',
        primarySwatch: Colors.blue,
        primaryColor: const Color(0xFF2196F3),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 8,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF2196F3),
          unselectedItemColor: Colors.grey[400],
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        useMaterial3: true,
      ),
      navigatorObservers: [routeObserver],
      home: home,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<HomeScreen> createState() => _HomeScreen();
}

bool favoritesSelected = false;

class _HomeScreen extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late GlobalObjectKey<AdoptGridState> AdoptionGridKey;
  late GlobalObjectKey<FitState> FitScreenKey = GlobalObjectKey<FitState>(this);
  late GlobalObjectKey<PersonalityFitState> PersonalityFitScreenKey = GlobalObjectKey<PersonalityFitState>(this);
  late GlobalKey SheltersScreenKey;
  late GlobalKey FavoritesListScreenKey;
  late AnimationController _sparkleController;
  late Animation<double> _sparkleAnimation;

  void _setFavoriteButton(bool fav) {
    setState(() => favoritesSelected = fav);
  }

  @override
  void initState() {
    super.initState();
    AdoptionGridKey = GlobalObjectKey<AdoptGridState>(this);
    SheltersScreenKey = GlobalKey();
    FavoritesListScreenKey = GlobalKey();
    // Initialize sparkle animation
    _sparkleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _sparkleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _sparkleController,
      curve: Curves.easeOut,
    ));
    // Ask for zip code at app start if not already loaded (same storage as adoption screen)
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureZipCode());

    // When SearchScreen is opened from Shelters and user taps Find Cats, switch to Adopt tab and apply result
    globals.onApplySearchAndSwitchToAdopt = (dynamic result) {
      if (result == null) return;
      setState(() => _selectedIndex = 1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AdoptionGridKey.currentState?.applySearchResult(result);
      });
    };
    // When user taps Shelters on the search screen, pop search and switch to Shelters tab
    globals.onNavigateToSheltersTab = (BuildContext ctx) {
      if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
      globals.sheltersOpenedFromSearch = true;
      setState(() => _selectedIndex = 4);
    };
    // When user taps "Select" on a shelter (from search flow), switch to Adopt, then push Search from this context so we receive the Find Cats result and apply it to the adoption list
    globals.onSelectShelterAndOpenSearch = (String orgId, String orgName) {
      setState(() => _selectedIndex = 1);
      final state = this;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!state.mounted) return;
        final adoptState = AdoptionGridKey.currentState;
        if (adoptState == null) return;
        final route = adoptState.routeForSearchWithShelter(orgId, orgName);
        final result = await Navigator.push(state.context, route);
        print("=== HomeScreen: received result from Search pop: ${result != null ? result.runtimeType : 'null'} ===");
        // Use same adoptState that built the route so we don't depend on currentState after await
        if (result != null && state.mounted && adoptState.mounted) {
          adoptState.applySearchResult(result);
        } else if (result == null) {
          print("=== HomeScreen: result was null, search not applied ===");
        }
      });
    };
    // When user long-presses zip on adoption list to clear it, also reset Fit onboarding so help shows again
    globals.onClearFitOnboarding = () async {
      await FitScreenKey.currentState?.resetOnboarding();
      await PersonalityFitScreenKey.currentState?.resetOnboarding();
    };
  }

  /// 1) Ask for location permission (reason: find cats near you). 2) If denied, ask for zip via dialog with validation; allow retry or skip.
  Future<void> _ensureZipCode() async {
    if (!mounted) return;
    final server = globals.FelineFinderServer.instance;
    if (server.zip.isNotEmpty && server.zip != "?") return;

    // Step 1: Ask user if we can use location to find cats near them
    final useLocation = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Find cats near you'),
        content: const Text(
          'Feline Finder would like to use your location so we can find cats near you for adoption.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    if (useLocation == true && mounted) {
      final zipFromLocation = await _getZipFromLocation();
      if (zipFromLocation.isNotEmpty && zipFromLocation.length == 5) {
        try {
          final isValid = await server.isZipCodeValid(zipFromLocation);
          if (isValid == true) {
            await server.setZipCode(zipFromLocation);
            return;
          }
        } catch (_) {}
      }
    }

    // Step 2: No location or denied — ask for zip in dialog; validate like adopt screen; allow retry or skip
    while (mounted) {
      final controller = TextEditingController();
      final result = await showDialog<_ManualZipResult>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Enter your ZIP code'),
          content: TextField(
            autofocus: true,
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'ZIP code (5 digits)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            maxLength: 5,
            onSubmitted: (_) => Navigator.of(context).pop(_ManualZipResult(controller.text.trim(), skip: false)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(const _ManualZipResult('', skip: true)),
              child: const Text('Skip'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(_ManualZipResult(controller.text.trim(), skip: false)),
              child: const Text('Submit'),
            ),
          ],
        ),
      );
      // Defer dispose so the dialog's TextField is fully unmounted first (avoids "used after disposed" when setState rebuilds elsewhere)
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());

      if (result == null || result.skip) return;

      final zipTrimmed = result.zip.trim();
      if (zipTrimmed.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ZIP code cannot be blank.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        continue;
      }
      if (zipTrimmed.length != 5) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ZIP code must be exactly 5 digits.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        continue;
      }

      try {
        final isValid = await server.isZipCodeValid(zipTrimmed);
        if (isValid == true) {
          await server.setZipCode(zipTrimmed);
          return;
        }
        if (isValid == false && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ZIP code "$zipTrimmed" is not valid. Try again or tap Skip.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not validate ZIP. Check connection and try again or Skip.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  /// Get ZIP from device location (uses system permission; iOS shows reason from Info.plist).
  Future<String> _getZipFromLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return '';

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        return '';
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty && placemarks.first.postalCode != null && placemarks.first.postalCode!.isNotEmpty) {
        return placemarks.first.postalCode!;
      }
    } catch (e) {
      print('Error getting zip from location: $e');
    }
    return '';
  }

  @override
  void dispose() {
    _sparkleController.dispose();
    super.dispose();
  }

  List<Widget> get pages => <Widget>[
    PersonalityFit(key: PersonalityFitScreenKey), // Index 0 - Fit (brain/personality)
    AdoptGrid(key: AdoptionGridKey, setFav: _setFavoriteButton), // Index 1 - Adopt
    BreedList(title: "Breed List"), // Index 2 - Breeds
    const FavoritesListScreen(), // Index 3 - Saved
    SheltersNearYouScreen(key: SheltersScreenKey), // Index 4 - Shelters Near You
  ];

// 9
  void _onItemTapped(int index) {
    if (index == 1 && _selectedIndex == 0) {
      _onLeavingFitForAdopt();
      return;
    }
    // When user taps 🐈 (Adopt) tab, dismiss fit help so "tap 🐈 to see your matches" is completed
    if (index == 1) {
      PersonalityFitScreenKey.currentState?.dismissHelpAndSave();
      FitScreenKey.currentState?.dismissHelpAndSave();
    }
    // "Select" only when opened from search screen (onNavigateToSheltersTab sets true). Any tab tap clears it so button shows "View Cats".
    globals.sheltersOpenedFromSearch = false;
    setState(() {
      _selectedIndex = index;
    });
    // Keep zip in sync: load from prefs when switching tabs and refresh the screen that displays it
    final server = globals.FelineFinderServer.instance;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await server.loadZipCodeFromPrefs();
      if (!mounted) return;
      if (index == 0) {
        PersonalityFitScreenKey.currentState?.snapshotTopCatTypeForWhenUserEntered();
      } else if (index == 1) {
        AdoptionGridKey.currentState?.refreshZipFromCanonical();
        AdoptionGridKey.currentState?.requeryIfSelectedTypeChanged();
      } else if (index == 3) {
        (FavoritesListScreenKey.currentState as dynamic)?.refreshFavorites();
      } else if (index == 4) {
        (SheltersScreenKey.currentState as dynamic)?.syncZipFromCanonical();
      }
    });
  }

  /// Called when user taps Adopt tab from Fit. Type for adoption list is set from Fit (last-changed type).
  Future<void> _onLeavingFitForAdopt() async {
    globals.sheltersOpenedFromSearch = false;
    PersonalityFitScreenKey.currentState?.dismissHelpAndSave();
    FitScreenKey.currentState?.dismissHelpAndSave();
    final top = CatTypeFilterMapping.getTopPersonalityCatType(globals.FelineFinderServer.instance);
    if (top != null) {
      await AdoptionGridKey.currentState?.setChosenCatTypeFromFit(top.name);
    }
    setState(() => _selectedIndex = 1);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await AdoptionGridKey.currentState?.refreshZipFromCanonical();
      AdoptionGridKey.currentState?.requeryIfSelectedTypeChanged();
    });
  }

  List<Widget>? getTrailingButtons(selectedIndex) {
    if (selectedIndex == 0) {
      // Fit (PersonalityFit) - share button
      return <Widget>[
        GoldCircleIconButton(
          icon: Icons.share,
          onTap: () {
            PersonalityFitScreenKey.currentState?.sharePersonalityFitScreen();
          },
        ),
        const SizedBox(width: 15),
      ];
    } else if (selectedIndex == 1) {
      // Adopt - sort then search
      return <Widget>[
        GoldCircleIconButton(
          icon: Icons.sort,
          onTap: () {
            AdoptionGridKey.currentState?.showSortSheet();
          },
        ),
        const SizedBox(width: 15),
        GoldCircleIconButton(
          icon: Icons.search,
          onTap: () {
            AdoptionGridKey.currentState!.search();
          },
        ),
        const SizedBox(width: 15),
      ];
    }
    return null;
  }

  Widget? getLeadingButtons(selectedIndex) {
    /*
    if (selectedIndex == 2) {
      return GestureDetector(
          onTap: () {
            var _favoritesSelected = (favoritesSelected) ? false : true;
            AdoptionGridKey.currentState!.setFavorites(_favoritesSelected);
            setState(() {
              favoritesSelected = _favoritesSelected;
            });
          },
          child: Icon(
            Icons.favorite,
            color: (favoritesSelected) ? Colors.red : Colors.grey,
            size: 40,
          ));
    }
    */
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.purpleGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar with gradient
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Feline Finder",
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.fontSizeXXL,
                        fontWeight: FontWeight.bold,
                        color: (_selectedIndex == 0) ? AppTheme.goldBase : Colors.white,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 2),
                            blurRadius: 4,
                            color: Colors.black26,
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: getTrailingButtons(_selectedIndex) ?? [],
                    ),
                  ],
                ),
              ),
              // Main content
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.purpleGradient,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(AppTheme.cardBorderRadius),
                      topRight: Radius.circular(AppTheme.cardBorderRadius),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 20,
                        offset: Offset(0, -5),
                      ),
                    ],
                  ),
                    child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: pages,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.purpleGradient,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: BottomNavigationBar(
            unselectedItemColor: Colors.white.withOpacity(0.7),
            showUnselectedLabels: true,
            showSelectedLabels: true,
            selectedItemColor: AppTheme.goldBase,
            backgroundColor: Colors.transparent, // Gradient applied via Container
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            items: <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                backgroundColor: Colors.white,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _selectedIndex == 0
                        ? AppTheme.deepPurple.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTheme.buttonBorderRadius),
                  ),
                  child: _selectedIndex == 0
                      ? Text(
                          '🧠',
                          style: TextStyle(
                            fontSize: 24,
                            color: AppTheme.goldBase,
                          ),
                        )
                      : ColorFiltered(
                          colorFilter: ColorFilter.matrix([
                            0.2126, 0.7152, 0.0722, 0, 0, // Red channel
                            0.2126, 0.7152, 0.0722, 0, 0, // Green channel
                            0.2126, 0.7152, 0.0722, 0, 0, // Blue channel
                            0, 0, 0, 1, 0, // Alpha channel
                          ]),
                          child: Text(
                            '🧠',
                            style: TextStyle(
                              fontSize: 24,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                ),
                label: 'Fit',
              ),
              BottomNavigationBarItem(
                backgroundColor: Colors.white,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _selectedIndex == 1
                        ? AppTheme.deepPurple.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTheme.buttonBorderRadius),
                  ),
                  child: _selectedIndex == 1
                      ? Text(
                          '🐈',
                          style: TextStyle(
                            fontSize: 24,
                            color: AppTheme.goldBase,
                          ),
                        )
                      : ColorFiltered(
                          colorFilter: ColorFilter.matrix([
                            0.2126, 0.7152, 0.0722, 0, 0, // Red channel
                            0.2126, 0.7152, 0.0722, 0, 0, // Green channel
                            0.2126, 0.7152, 0.0722, 0, 0, // Blue channel
                            0, 0, 0, 1, 0, // Alpha channel
                          ]),
                          child: Text(
                            '🐈',
                            style: TextStyle(
                              fontSize: 24,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                ),
                label: 'Adopt',
              ),
              BottomNavigationBarItem(
                backgroundColor: Colors.white,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _selectedIndex == 2
                        ? AppTheme.deepPurple.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTheme.buttonBorderRadius),
                  ),
                  child: _selectedIndex == 2
                      ? Text(
                          '🐱',
                          style: TextStyle(
                            fontSize: 24,
                            color: AppTheme.goldBase,
                          ),
                        )
                      : ColorFiltered(
                          colorFilter: ColorFilter.matrix([
                            0.2126, 0.7152, 0.0722, 0, 0, // Red channel
                            0.2126, 0.7152, 0.0722, 0, 0, // Green channel
                            0.2126, 0.7152, 0.0722, 0, 0, // Blue channel
                            0, 0, 0, 1, 0, // Alpha channel
                          ]),
                          child: Text(
                            '🐱',
                            style: TextStyle(
                              fontSize: 24,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                ),
                label: "Breeds",
              ),
              BottomNavigationBarItem(
                backgroundColor: Colors.white,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _selectedIndex == 3
                        ? AppTheme.deepPurple.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTheme.buttonBorderRadius),
                  ),
                  child: _selectedIndex == 3
                      ? Text(
                          '🏷️',
                          style: TextStyle(
                            fontSize: 24,
                            color: AppTheme.goldBase,
                          ),
                        )
                      : ColorFiltered(
                          colorFilter: ColorFilter.matrix([
                            0.2126, 0.7152, 0.0722, 0, 0, // Red channel
                            0.2126, 0.7152, 0.0722, 0, 0, // Green channel
                            0.2126, 0.7152, 0.0722, 0, 0, // Blue channel
                            0, 0, 0, 1, 0, // Alpha channel
                          ]),
                          child: Text(
                            '🏷️',
                            style: TextStyle(
                              fontSize: 24,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                ),
                label: 'Saved',
              ),
              BottomNavigationBarItem(
                backgroundColor: Colors.white,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _selectedIndex == 4
                        ? AppTheme.deepPurple.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTheme.buttonBorderRadius),
                  ),
                  child: _selectedIndex == 4
                      ? Icon(
                          Icons.location_on,
                          size: 24,
                          color: AppTheme.goldBase,
                        )
                      : Icon(
                          Icons.location_on,
                          size: 24,
                          color: AppTheme.textSecondary,
                        ),
                ),
                label: 'Shelters',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
