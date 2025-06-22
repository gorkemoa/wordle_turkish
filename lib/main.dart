// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Splash screen'i preserve et
  FlutterNativeSplash.preserve(widgetsBinding: WidgetsBinding.instance);
  
  try {
    // Firebase'i initialize et
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase başarıyla initialize edildi');
  } catch (e) {
    print('Firebase initialize hatası: $e');
  }
  
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

  @override
  void initState() {
    super.initState();
    // Splash screen'i kaldır
    _removeSplashScreen();
  }

  void _removeSplashScreen() {
    // Kısa bir gecikme sonrası splash screen'i kaldır
    Future.delayed(const Duration(milliseconds: 1500), () {
      FlutterNativeSplash.remove();
    });
  }

  void _toggleTheme() {
    setState(() {
      if (_themeMode == ThemeMode.dark) {
        _themeMode = ThemeMode.light;
      } else {
        _themeMode = ThemeMode.dark;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
          // Bağlantı durumu kontrol et
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
          
          // Kullanıcı giriş yapmış mı kontrol et
          if (snapshot.hasData && snapshot.data != null) {
            // Kullanıcı giriş yapmış - Ana sayfaya yönlendir
            return HomePage(toggleTheme: _toggleTheme);
          } else {
            // Kullanıcı giriş yapmamış - Login sayfasına yönlendir
            return const LoginPage();
          }
        },
      ),
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => HomePage(toggleTheme: _toggleTheme),
        '/wordle_daily': (context) => WordlePage(toggleTheme: _toggleTheme, gameMode: GameMode.daily),
        '/wordle_challenge': (context) => WordlePage(toggleTheme: _toggleTheme, gameMode: GameMode.challenge),
        '/duel_full': (context) => const DuelPage(),
        '/leaderboard': (context) => const LeaderboardPage(),
        '/profile': (context) => const ProfilePage(),
      },
      themeMode: _themeMode,
    );
  }
}