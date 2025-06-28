import 'package:flutter/material.dart';
import 'themed_game_page.dart';

// Tema seçimi sayfası

class ThemedModePage extends StatefulWidget {
  final VoidCallback toggleTheme;

  const ThemedModePage({Key? key, required this.toggleTheme}) : super(key: key);

  @override
  State<ThemedModePage> createState() => _ThemedModePageState();
}

class _ThemedModePageState extends State<ThemedModePage> {
  final List<Map<String, dynamic>> themes = [
    {
      'id': 'food',
      'name': 'Yiyecek & İçecek',
      'emoji': '🍎',
      'description': 'Lezzetli kelimeler',
      'color': const Color(0xFFE67E22),
    },
    {
      'id': 'animals',
      'name': 'Hayvanlar',
      'emoji': '🐱',
      'description': 'Sevimli dostlarımız',
      'color': const Color(0xFF27AE60),
    },
    {
      'id': 'cities',
      'name': 'Şehirler',
      'emoji': '🏙️',
      'description': 'Dünya kentleri',
      'color': const Color(0xFF3498DB),
    },
    {
      'id': 'sports',
      'name': 'Spor',
      'emoji': '⚽',
      'description': 'Sporla ilgili terimler',
      'color': const Color(0xFFE74C3C),
    },
    {
      'id': 'music',
      'name': 'Müzik',
      'emoji': '🎵',
      'description': 'Müzikal kelimeler',
      'color': const Color(0xFF9B59B6),
    },
    {
      'id': 'random',
      'name': 'Rastgele Tema',
      'emoji': '🔀',
      'description': 'Sürpriz kategoriler',
      'color': const Color(0xFF34495E),
    },
  ];

  void _navigateToThemedGame(String themeId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ThemedGamePage(
          toggleTheme: widget.toggleTheme,
          themeId: themeId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[800],
      appBar: AppBar(
        backgroundColor: Colors.grey[850],
        title: Row(
          children: [
            Icon(Icons.category, color: Colors.grey[400]),
            const SizedBox(width: 8),
            const Text(
              'Tema Seçin',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: themes.length,
          itemBuilder: (context, index) {
            final theme = themes[index];
            return GestureDetector(
              onTap: () => _navigateToThemedGame(theme['id']),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.grey[700]!,
                      Colors.grey[600]!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey[900]!.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        theme['emoji'],
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            theme['name'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            theme['description'],
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
} 