import 'package:flutter/material.dart';
import '/screens/fit.dart';
import '/screens/adoptGrid.dart';
import '/screens/breedList.dart';
import 'dart:async';
import 'package:get/get.dart';

StreamController<int> buttonChangedHighlight =
    StreamController<int>.broadcast();
var buttonChangedHighlightStream = buttonChangedHighlight.stream;

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
    Timer(const Duration(seconds: 3),
        () => Get.to(const HomeScreen(title: 'Feline Finder')));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Feline Finder"),
      ),
      body: pages[_selectedIndex],
      // 4
      bottomNavigationBar: BottomNavigationBar(
        // 5
        selectedItemColor: Theme.of(context).textSelectionTheme.selectionColor,
        // 10
        currentIndex: _selectedIndex,
        // 11
        onTap: _onItemTapped,
        // 6
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            backgroundColor: Colors.grey,
            icon: Icon(Icons.search),
            label: 'Fit',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Breeds',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.card_membership),
            label: 'Adopt',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
        ],
      ),
    );
  }
}
