import 'dart:async';

import "package:firebase_auth/firebase_auth.dart";
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'services/search_ai_service.dart';
import 'theme.dart';

import '/screens/adoptGrid.dart';
import '/screens/breedList.dart';
import '/screens/fit.dart';
import '/screens/chatList.dart';
import '/widgets/gold/gold_circle_icon_button.dart';

FirebaseAuth? auth;
// final gsi.GoogleSignIn googleSignIn = gsi.GoogleSignIn();

final RouteObserver<ModalRoute> routeObserver = RouteObserver<ModalRoute>();

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

    // Initialize AI services
    try {
      final searchAIService = SearchAIService();
      searchAIService.initialize();
    } catch (e) {
      print('AI service initialization failed: $e');
      // Continue without AI - search will still work
    }
  } catch (e) {
    print('Firebase initialization failed: $e');
    // Continue without Firebase for now
    auth = null;
  }

  // Initialize authentication
  await _initializeAuth();

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
  late AnimationController _sparkleController;
  late Animation<double> _sparkleAnimation;

  void _setFavoriteButton(bool fav) {
    setState(() => favoritesSelected = fav);
  }

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _sparkleController.dispose();
    super.dispose();
  }

  static List<Widget> pages = <Widget>[
    const AdoptGrid(), // Index 0 - Adopt a cat (first tab)
    const Fit(), // Index 1 - Fit (second tab)
    BreedList(title: "Breed List"), // Index 2 - Breed info (third tab)
    const ConversationListScreen() // Index 3 - Chat (fourth tab)
  ];

// 9
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  List<Widget>? getTrailingButtons(selectedIndex) {
    if (selectedIndex == 0) {
      // Adopt tab is now at index 0
      return <Widget>[
        GoldCircleIconButton(
          icon: Icons.favorite,
          isSelected: favoritesSelected,
          onTap: () {
            favoritesSelected = !favoritesSelected;
            AdoptionGridKey.currentState!.setFavorites(favoritesSelected);
            setState(() {
              // favoritesSelected is a global variable, update it
            });

            // Trigger sparkle animation when favorited
            if (favoritesSelected) {
              _sparkleController.reset();
              _sparkleController.forward();
            }
          },
        ),
        const SizedBox(width: 14),
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
    AdoptionGridKey = GlobalObjectKey<AdoptGridState>(context);
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
                    child: (_selectedIndex == 0) // Adopt tab is now at index 0
                        ? AdoptGrid(
                            key: AdoptionGridKey, setFav: _setFavoriteButton)
                        : pages[_selectedIndex],
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
                  child: ImageIcon(
                    AssetImage(_selectedIndex == 0
                        ? "assets/Icons/adopt_selected.png"
                        : "assets/Icons/adopt_unselected.png"),
                    color: (_selectedIndex == 0
                        ? AppTheme.goldBase
                        : AppTheme.textSecondary),
                    size: 24,
                  ),
                ),
                label: 'Adopt',
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
                  child: ImageIcon(
                    AssetImage(_selectedIndex == 1
                        ? "assets/Icons/fit_selected.png"
                        : "assets/Icons/fit_unselected.png"),
                    color: (_selectedIndex == 1
                        ? AppTheme.goldBase
                        : AppTheme.textSecondary),
                    size: 24,
                  ),
                ),
                label: 'Fit',
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
                  child: ImageIcon(
                    AssetImage(_selectedIndex == 2
                        ? "assets/Icons/breeds_selected.png"
                        : "assets/Icons/breeds_unselected.png"),
                    color: (_selectedIndex == 2
                        ? AppTheme.goldBase
                        : AppTheme.textSecondary),
                    size: 24,
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
                  child: ImageIcon(
                    AssetImage(_selectedIndex == 3
                        ? "assets/Icons/talk_selected.png"
                        : "assets/Icons/talk_unselected.png"),
                    color: (_selectedIndex == 3
                        ? AppTheme.goldBase
                        : AppTheme.textSecondary),
                    size: 24,
                  ),
                ),
                label: 'Chat',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
