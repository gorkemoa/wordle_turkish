// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'viewmodels/wordle_viewmodel.dart';
import 'viewmodels/duel_viewmodel.dart';
import 'views/home_page.dart';
import 'views/wordle_page.dart';
import 'views/duel_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase'i initialize et
  await Firebase.initializeApp();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WordleViewModel()),
        ChangeNotifierProvider(create: (_) => DuelViewModel()),
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
  home: HomePage(toggleTheme: _toggleTheme),
  routes: {
    '/wordle': (context) => WordlePage(toggleTheme: _toggleTheme),
    '/duel': (context) => const DuelPage(),
  },
  themeMode: _themeMode,
);
  }
}