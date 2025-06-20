// lib/views/home_page.dart

import 'package:flutter/material.dart';
import 'wordle_page.dart';

class HomePage extends StatelessWidget {
  final VoidCallback toggleTheme;

  const HomePage({Key? key, required this.toggleTheme}) : super(key: key);

  void _showFeatureComingSoon(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            '$title Hakkında',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
              'Bu özellik henüz geliştirilmemiştir. Yakında eklenecek!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Tamam'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToWordle(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WordlePage(toggleTheme: toggleTheme),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Arkaplan
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Color(0xFF1A237E),
                  Color(0xFF0D47A1),
                  Color(0xFF1565C0),
                ],
                center: Alignment.center,
                radius: 1.5,
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Başlık ve Tanım
                  const Text(
                    'Kelime Bul',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(
                          blurRadius: 10.0,
                          color: Colors.black54,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Becerilerini test et ve eğlen!',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  // Oyun Modları
                  _buildFeatureCard(
                    context,
                    'Tekli Oyna',
                    'Kelime çözme becerilerini test et!',
                    Colors.blueAccent,
                    () => _navigateToWordle(context),
                  ),
                  const SizedBox(height: 20),
                  _buildFeatureCard(
                    context,
                    'Duello Modu',
                    'Arkadaşlarınla online rekabet et!',
                    Colors.redAccent,
                    () => Navigator.pushNamed(context, '/duel'),
                  ),
                  const SizedBox(height: 20),
                  _buildFeatureCard(
                    context,
                    'Zamana Karşı Yarış (Yakında)',
                    'Hızını ve zekanı test et!',
                    Colors.orangeAccent,
                    () => _showFeatureComingSoon(context, 'Zamana Karşı Yarış'),
                  ),
                  const SizedBox(height: 20),
                  _buildFeatureCard(
                    context,
                    'Tema Modu (Yakında)',
                    'Belirli bir tema seç ve oyna!',
                    Colors.greenAccent,
                    () => _showFeatureComingSoon(context, 'Tema Modu'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, String title, String description,
      Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.8),
                color.withOpacity(0.6),
                color.withOpacity(0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.play_arrow_rounded,
                size: 25,
                color: Colors.white,
              ),
              const SizedBox(width: 1),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}