import 'package:flutter/material.dart';
import '/screens/fit.dart';
import '/screens/adoptGrid.dart';

void main() async {
  runApp(const FelineFinderApp());
}

final RouteObserver<ModalRoute> routeObserver = RouteObserver<ModalRoute>();

class FelineFinderApp extends StatelessWidget {
  const FelineFinderApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      title: 'Feline Finder',
      theme: ThemeData(fontFamily: 'Poppins'),
      home: const HomeScreen(title: 'Feline Finder'),
      navigatorObservers: [routeObserver]
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
  Container(color: Colors.green),
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
  selectedItemColor:
    Theme.of(context).textSelectionTheme.selectionColor,
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