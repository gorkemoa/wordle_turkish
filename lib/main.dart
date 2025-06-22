// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'viewmodels/wordle_viewmodel.dart';
import 'viewmodels/duel_viewmodel.dart';
import 'viewmodels/leaderboard_viewmodel.dart';
import 'views/home_page.dart';
import 'views/login_page.dart';
import 'views/wordle_page.dart';
import 'views/duel_page.dart';
import 'views/leaderboard_page.dart';
import 'views/profile_page.dart';
import 'widgets/video_splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WordleViewModel()),
        ChangeNotifierProvider(create: (_) => DuelViewModel()),
        ChangeNotifierProvider(create: (_) => LeaderboardViewModel()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  void _initializeApp() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
    });
  }

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return const MaterialApp(
        home: VideoSplashScreen(),
        debugShowCheckedModeBanner: false,
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kelime Bul Türkçe',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFFF8F9FA),
              body: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF4285F4),
                ),
              ),
            );
          }

          if (snapshot.hasData && snapshot.data != null) {
            return HomePage(toggleTheme: _toggleTheme);
          } else {
            return const LoginPage();
          }
        },
      ),
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => HomePage(toggleTheme: _toggleTheme),
        '/wordle_daily': (context) =>
            WordlePage(toggleTheme: _toggleTheme, gameMode: GameMode.daily),
        '/wordle_challenge': (context) =>
            WordlePage(toggleTheme: _toggleTheme, gameMode: GameMode.challenge),
        '/duel_full': (context) => const DuelPage(),
        '/leaderboard': (context) => const LeaderboardPage(),
        '/profile': (context) => const ProfilePage(),
      },
      themeMode: _themeMode,
    );
  }
}