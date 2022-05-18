import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:easy_firebase_auth/easy_firebase_auth.dart';
import '/screens/fit.dart';
import '/screens/adoptGrid.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(FelineFinderApp());
}

class FelineFinderApp extends StatelessWidget {
  const FelineFinderApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {

    final ThemeData theme = ThemeData();

    return MaterialApp(
      title: 'Feline Finder',
      theme: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: Colors.grey,
          secondary: Colors.black,
        ),
      ),
      home: const MyHomePage(title: 'Feline Finder'),
    );
  }
}


class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  @override
  Widget build(BuildContext context) {
    return AuthProvider(
      autoSignInAnonymously: true,
      splashScreenDurationMillis: 500,
      child: MaterialApp(
        home: AuthManagerWidget(
        splashScreen: SplashScreen(),
        notLoggedScreen: NotLoggedScreen(),
        loggedScreen: const LoggedScreen(title: "Feline Finder"),
        actionsAfterLogIn: (method, user) async {
          // Initialize user data here
        },
        actionsBeforeLogOut: (user) async {
          // Stop listeners, remove notification tokens...
        },
      ),
    )
  );
}
}

class LoggedScreen extends StatefulWidget {
  const LoggedScreen({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<LoggedScreen> createState() => _LoggedScreen();
}

class _LoggedScreen extends State<LoggedScreen> {
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
  items: <BottomNavigationBarItem>[
    const BottomNavigationBarItem(
      backgroundColor: Colors.grey,
      icon: Icon(Icons.search),
      label: 'Fit',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.list),
      label: 'Breeds',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.card_membership),
      label: 'Adopt',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.favorite),
      label: 'Favorites',
    ),
  ],
),
);
  }
}

class NotLoggedScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // You can set your custom strings
    // you can add the privacy of your app with markdown with the necessary links
    AuthStrings authStrings = AuthStrings.spanish(
        privacyMarkdown:
            "Al continuar aceptas la [política de privacidad](https://myPrivacyUrl.com) "
            "y las [condiciones de servicio](https://myTermsUrl.com).");

    return LoginScreen(
      authStrings: authStrings,
      backgroundColor: Colors.purple,
      expandedWidget: Center(
        child: Container(
          height: 200,
          width: 300,
          color: Colors.red,
        ),
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          "SPLASH SCREEN",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
