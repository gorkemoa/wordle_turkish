// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'services/firebase_service.dart';
import 'services/ad_service.dart';
import 'services/haptic_service.dart';
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
  
  // Firebase zaten initialize edilmiş mi kontrol et
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      print('Firebase app zaten mevcut, devam ediliyor...');
    } else {
      print('Firebase initialization hatası: $e');
      rethrow;
    }
  }
  
  // AdMob'u başlat (opsiyonel)
  try {
    await AdService.initialize();
  } catch (e) {
    print('AdMob başlatılamadı, reklam özellikleri devre dışı: $e');
  }
  
  // Titreşim ayarlarını yükle
  await HapticService.loadHapticSettings();
  
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
            // Kullanıcı giriş yaptığında online durumunu ayarla
            FirebaseService.setUserOnline();
            return HomePage(toggleTheme: _toggleTheme);
          } else {
            return const LoginPage();
          }
        },
      ),
      onGenerateRoute: (RouteSettings settings) {
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (context) => const LoginPage());
          case '/home':
            return MaterialPageRoute(builder: (context) => HomePage(toggleTheme: _toggleTheme));
          case '/wordle_free':
            return MaterialPageRoute(
              builder: (context) => WordlePage(toggleTheme: _toggleTheme, gameMode: GameMode.unlimited),
            );
          case '/wordle_challenge':
            return MaterialPageRoute(
              builder: (context) => WordlePage(toggleTheme: _toggleTheme, gameMode: GameMode.challenge),
            );
          case '/wordle':
            // Parametreleri handle et
            final args = settings.arguments as Map<String, dynamic>?;
            final gameMode = args?['gameMode'] as GameMode? ?? GameMode.unlimited;
            
            return MaterialPageRoute(
              builder: (context) => WordlePage(
                toggleTheme: _toggleTheme, 
                gameMode: gameMode,
              ),
            );
          case '/duel_full':
            return MaterialPageRoute(builder: (context) => const DuelPage());
          case '/leaderboard':
            return MaterialPageRoute(builder: (context) => const LeaderboardPage());
          case '/profile':
            return MaterialPageRoute(builder: (context) => const ProfilePage());
          default:
            // Tanınmayan route için varsayılan sayfa
            return MaterialPageRoute(
              builder: (context) => HomePage(toggleTheme: _toggleTheme),
            );
        }
      },
      themeMode: _themeMode,
    );
  }
}