import 'dart:async';

import "package:firebase_auth/firebase_auth.dart";
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'services/search_ai_service.dart';
import 'services/key_store_service.dart';
import 'theme.dart';
import 'screens/globals.dart' as globals;
import 'config.dart';
// Import webview platform implementations to ensure they're registered

import '/screens/adoptGrid.dart';
import '/screens/breedList.dart';
import '/screens/fit.dart';
import '/screens/personality_fit.dart';
import '/screens/favoritesList.dart';
import '/widgets/gold/gold_circle_icon_button.dart';

FirebaseAuth? auth;
// final gsi.GoogleSignIn googleSignIn = gsi.GoogleSignIn();

final RouteObserver<ModalRoute> routeObserver = RouteObserver<ModalRoute>();

class _ManualZipResult {
  final String zip;
  final bool skip;
  const _ManualZipResult(this.zip, {required this.skip});
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Track start time to ensure minimum 3-second display
  final startTime = DateTime.now();

  // Add a small delay to prevent Firestore lock errors
  await Future.delayed(const Duration(milliseconds: 500));

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    auth = FirebaseAuth.instance;
  } catch (e) {
    print('Firebase initialization failed: $e');
    // Continue without Firebase for now
    auth = null;
  }

  // Initialize authentication
  await _initializeAuth();

  // Seed + load API keys from Firestore (in-memory only)
  if (auth != null) {
    try {
      await KeyStoreService.instance.seedFromDefinesIfEnabled();
      await KeyStoreService.instance.load();
    } catch (e) {
      print('KeyStore initialization failed: $e');
      // Continue without remote keys
    }
  }

  // Initialize AI services (Gemini key may come from KeyStore)
  try {
    final searchAIService = SearchAIService();
    searchAIService.initialize();
  } catch (e) {
    print('AI service initialization failed: $e');
    // Continue without AI - search will still work
  }

  // Reset search animation flag for new app session
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('searchAnimationShownThisSession', false);
  await prefs.setString('appStartTime', DateTime.now().toIso8601String());

  // Load zip code at app start (same storage as adoption screen)
  final savedZip = prefs.getString('zipCode');
  if (savedZip != null && savedZip.isNotEmpty && savedZip.length == 5) {
    globals.FelineFinderServer.instance.zip = savedZip;
  }

  // Ensure minimum 3 seconds have passed (launch screen will show during this time)
  final elapsed = DateTime.now().difference(startTime);
  if (elapsed.inSeconds < 3) {
    await Future.delayed(Duration(seconds: 3 - elapsed.inSeconds));
  }

  runApp(const MyApp());
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
  } on FirebaseAuthException catch (e) {
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
    print("Unexpected error during anonymous sign-in: $e");
    print("Error type: ${e.runtimeType}");
    print("Stack trace: $stackTrace");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Feline Finder',
      showPerformanceOverlay: false, // Red number in corner is FPS/ms overlay; keep off in debug
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
      home: const HomeScreen(title: 'Feline Finder'),
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
  late AnimationController _sparkleController;
  late Animation<double> _sparkleAnimation;

  void _setFavoriteButton(bool fav) {
    setState(() => favoritesSelected = fav);
  }

  @override
  void initState() {
    super.initState();
    AdoptionGridKey = GlobalObjectKey<AdoptGridState>(this);
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
            server.zip = zipFromLocation;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('zipCode', zipFromLocation);
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
          server.zip = zipTrimmed;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('zipCode', zipTrimmed);
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
  ];

// 9
  void _onItemTapped(int index) {
    // When user taps 🐈 (Adopt) tab, dismiss fit help so "tap 🐈 to see your matches" is completed
    if (index == 1) {
      PersonalityFitScreenKey.currentState?.dismissHelpAndSave();
      FitScreenKey.currentState?.dismissHelpAndSave();
    }
    setState(() {
      _selectedIndex = index;
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
      // Adopt - search button
      return <Widget>[
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
                    child: pages[_selectedIndex],
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
            ],
          ),
        ),
      ),
    );
  }
}
