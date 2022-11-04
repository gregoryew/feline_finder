import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/screens/adoptGrid.dart';
import '/screens/breedList.dart';
import '/screens/fit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/youtube-video-row.dart';

void main() async {
  runApp(const SplashPage());
}

class SplashPage extends StatefulWidget {
  const SplashPage({Key? key}) : super(key: key);

  @override
  _SplashPageState createState() => _SplashPageState();
}

final RouteObserver<ModalRoute> routeObserver = RouteObserver<ModalRoute>();

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    () async {
      Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
      final SharedPreferences prefs = await _prefs;
      if (!prefs.containsKey("firstTime")) {
        await prefs.setString("firstTime", "False");
        await Get.to(
            () => YouTubeVideoRow(
                  playlist: null,
                  title: "Welcome To Feline Finder",
                  videoid: "Hqmt7N2bJLk",
                ),
            transition: Transition.circularReveal);
      } else {
        Timer(const Duration(seconds: 3),
            () => Get.off(const HomeScreen(title: 'Feline Finder')));
      }
    }();
    return GetMaterialApp(
      title: 'Feline Finder',
      theme: ThemeData(fontFamily: 'Poppins'),
      navigatorObservers: [routeObserver],
      home: Scaffold(
        body: Container(
          decoration: const BoxDecoration(color: Colors.white),
          child: Center(
            child: Image.asset("assets/Full/Launch.png",
                fit: BoxFit.cover,
                height: double.infinity,
                width: double.infinity,
                alignment: Alignment.center),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<HomeScreen> createState() => _HomeScreen();
}

class _HomeScreen extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool favoritesSelected = false;
  late GlobalObjectKey<AdoptGridState> AdoptionGridKey;

  void _setFavoriteButton(bool fav) {
    setState(() => favoritesSelected = fav);
  }

  static List<Widget> pages = <Widget>[
    Fit(),
    BreedList(title: "Breed List"),
    AdoptGrid(),
    Container(color: Colors.orange)
  ];

// 9
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  List<Widget>? getTrailingButtons(selectedIndex) {
    if (selectedIndex == 2) {
      return <Widget>[
        /*
        GestureDetector(
          onTap: () {
            AdoptionGridKey.currentState!.whileYourAwaySearch();
          },
          child: const ImageIcon(AssetImage("assets/Icons/away.png"), size: 30),
        ),
        */
        const SizedBox(width: 10, height: 30),
        GestureDetector(
          onTap: () {
            AdoptionGridKey.currentState!.search();
          },
          child:
              const ImageIcon(AssetImage("assets/Icons/search.png"), size: 30),
        ),
        const SizedBox(width: 15, height: 30)
      ];
    }
    return null;
  }

  Widget? getLeadingButtons(selectedIndex) {
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
    return null;
  }

  @override
  Widget build(BuildContext context) {
    AdoptionGridKey = GlobalObjectKey<AdoptGridState>(context);
    return Scaffold(
      appBar: AppBar(
          title: const Center(child: Text("Feline Finder")),
          leading: getLeadingButtons(_selectedIndex),
          actions: getTrailingButtons(_selectedIndex)),
      body: (_selectedIndex == 2)
          ? AdoptGrid(key: AdoptionGridKey, setFav: _setFavoriteButton)
          : pages[_selectedIndex],
      // 4
      bottomNavigationBar: BottomNavigationBar(
        // 5
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        showSelectedLabels: true,
        selectedItemColor: Colors.blue,
        // 10
        currentIndex: _selectedIndex,
        // 11
        onTap: _onItemTapped,
        // 6
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            backgroundColor: Colors.white,
            icon: ImageIcon(
                AssetImage(_selectedIndex == 0
                    ? "assets/Icons/fit_selected.png"
                    : "assets/Icons/fit_unselected.png"),
                color: (_selectedIndex == 0 ? Colors.blue : Colors.grey)),
            label: 'Fit',
          ),
          BottomNavigationBarItem(
            backgroundColor: Colors.white,
            icon: ImageIcon(
                AssetImage(_selectedIndex == 1
                    ? "assets/Icons/breeds_selected.png"
                    : "assets/Icons/breeds_unselected.png"),
                color: (_selectedIndex == 1 ? Colors.blue : Colors.grey)),
            label: "Breeds",
          ),
          BottomNavigationBarItem(
            backgroundColor: Colors.white,
            icon: ImageIcon(
                AssetImage(_selectedIndex == 2
                    ? "assets/Icons/adopt_selected.png"
                    : "assets/Icons/adopt_unselected.png"),
                color: (_selectedIndex == 2 ? Colors.blue : Colors.grey)),
            label: 'Adopt',
          ) /*,
          BottomNavigationBarItem(
            backgroundColor: Colors.white,
            icon: ImageIcon(
                AssetImage(_selectedIndex == 3
                    ? "assets/Icons/zoom_selected.png"
                    : "assets/Icons/zoom_unselected.png"),
                color: Colors.blue),
            label: 'Meet',
          ),
          */
        ],
      ),
    );
  }
}
