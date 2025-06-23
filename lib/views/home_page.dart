// lib/views/home_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../services/firebase_service.dart';
import '../services/avatar_service.dart';


import 'duel_page.dart';
import 'leaderboard_page.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'dart:ui';

class HomePage extends StatefulWidget {
  final VoidCallback? toggleTheme;

  const HomePage({Key? key, this.toggleTheme}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  Map<String, dynamic>? userStats;
  bool isLoading = true;
  int activeDuelPlayers = 0;
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late AnimationController _bounceController;
  late Animation<double> _animation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _bounceAnimation;
  late AnimationController _dailyChallengePulseController;
  late Animation<double> _dailyChallengePulseAnimation;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userStatsSubscription;
  StreamSubscription<int>? _duelPlayersSubscription;
  final List<WordleParticle> _particles = [];
  final _random = math.Random();
  late AnimationController _sheenController;
  late Animation<double> _sheenAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadData();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 40),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );
    
    _dailyChallengePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _dailyChallengePulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _dailyChallengePulseController,
        curve: Curves.easeInOut,
      ),
    );
    _dailyChallengePulseController.repeat(reverse: true);

    _sheenController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _sheenAnimation = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(
        parent: _sheenController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _bounceController.dispose();
    _dailyChallengePulseController.dispose();
    _sheenController.dispose();
    _userStatsSubscription?.cancel();
    _duelPlayersSubscription?.cancel();
    super.dispose();
  }

  void _updateParticles() {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    if (size.isEmpty) return;

    if (_particles.isEmpty) {
      _particles.addAll(List.generate(12, (_) => WordleParticle(_random, size)));
    }

    for (int i = 0; i < _particles.length; i++) {
      _particles[i].update(size);
      for (int j = i + 1; j < _particles.length; j++) {
        _particles[i].resolveCollision(_particles[j]);
      }
    }
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      await FirebaseService.initializeUserDataIfNeeded(user.uid);

      // Real-time veri dinlemeyi başlat
      _startListeningToUserStats(user.uid);
      _startListeningToDuelPlayers();

    } catch (e) {
      print('Veri yükleme hatası: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _startListeningToUserStats(String uid) {
    _userStatsSubscription?.cancel();
    
    _userStatsSubscription = FirebaseFirestore.instance
        .collection('user_stats')
        .doc(uid)
        .snapshots()
        .listen((DocumentSnapshot<Map<String, dynamic>> snapshot) {
      if (mounted) {
        if (snapshot.exists) {
        setState(() {
            userStats = snapshot.data();
          isLoading = false;
        });
          
          // İlk yükleme sonrası animasyonu başlat
          if (_bounceController.status != AnimationStatus.forward) {
            _bounceController.forward(from: 0.0);
          }
        } else {
          setState(() {
            isLoading = false;
          });
        }
      }
    }, onError: (error) {
      print('Real-time veri dinleme hatası: $error');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    });
  }

  void _startListeningToDuelPlayers() {
    _duelPlayersSubscription?.cancel();
    
    _duelPlayersSubscription = FirebaseService.getActiveDuelPlayersCount().listen(
      (count) {
        if (mounted) {
          setState(() {
            activeDuelPlayers = count;
          });
        }
      },
      onError: (error) {
        print('Aktif düello oyuncuları dinleme hatası: $error');
      },
    );
  }

  Future<void> _refreshData() async {
    // Real-time sistemde manuel refresh'e gerek yok
    // Ama kullanıcı deneyimi için kısa loading gösterelim
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showFeatureComingSoon(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.info_outline, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          content: const Text(
            'Bu özellik henüz hazır değil.\nYakında sizlerle buluşacak! 🚀',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF666666),
              height: 1.5,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4285F4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Anladım',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showUserProfile(BuildContext context) {
    Navigator.pushNamed(context, '/profile');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (isLoading) {
      return Scaffold(
        body: Container(
          decoration: _buildBackgroundDecoration(),
          child: Stack(
            children: [
              _buildBackgroundPattern(),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Veriler Yükleniyor...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      body: Container(
        decoration: _buildBackgroundDecoration(),
        child: Stack(
          children: [
            _buildBackgroundPattern(),
            _buildSummerWaves(),
            Positioned(
              top: 40,
              right: 20,
              child: Icon(
                Icons.wb_sunny,
                color: Colors.yellow.withOpacity(0.3),
                size: 80,
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                child: Column(
                  children: [
                    _buildModernHeader(user),
                    const SizedBox(height: 20),
                    Expanded(
                      child: Center(
                        child: _buildGameMenu(context),
                      ),
                    ),
                    _buildStreakInfo(),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernHeader(User? user) {
    final level = userStats?['level'] ?? 1;
    final tokens = userStats?['tokens'] ?? 100;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showUserProfile(context),
            child: Hero(
              tag: 'user_avatar',
            child: FutureBuilder<String?>(
              future: FirebaseService.getUserAvatar(user?.uid ?? ''),
              builder: (context, snapshot) {
                final userAvatar = snapshot.data ?? AvatarService.generateAvatar(user?.uid ?? '');
                return CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF4285F4).withOpacity(0.8),
                  backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                  child: user?.photoURL == null
                      ? Text(
                          userAvatar,
                          style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                        )
                      : null,
                );
              },
            ),
          ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  user?.displayName?.split(' ').first ?? 'Oyuncu',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Seviye $level',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),

          _buildStatChip(Icons.monetization_on, tokens.toString(), Colors.amber),
          const SizedBox(width: 8),
          _buildHeaderButton(Icons.brightness_6_outlined, widget.toggleTheme ?? () {}),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  BoxDecoration _buildBackgroundDecoration() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF232526),
          Color(0xFF414345),
        ],
      ),
    );
  }

  Widget _buildBackgroundPattern() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        _updateParticles();
        return CustomPaint(
          painter: GamePatternPainter(_particles),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildGameMenu(BuildContext context) {
    final menuItems = [
      {
        'title': 'GÜNLÜK MEYDAN OKUMA',
        'subtitle': 'Her gün yeni bir kelime!',
        'icon': Icons.calendar_today_outlined,
        'pattern': _buildThemedPattern(const Color(0xFF2ecc71), 'daily'),
        'color': const Color(0xFF2ecc71),
        'onTap': () => Navigator.pushNamed(context, '/wordle_daily'),
        'isPrimary': false,
      },
      {
        'title': 'DÜELLO',
        'subtitle': activeDuelPlayers > 0 ? '$activeDuelPlayers oyuncu aktif!' : 'Arkadaşlarınla kapış!',
        'icon': Icons.sports_esports,
        'pattern': _buildThemedPattern(const Color(0xFFe74c3c), 'duel'),
        'color': const Color(0xFFe74c3c),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DuelPage())),
        'isPrimary': true,
      },
      {
        'title': 'LİDER TABLOSU',
        'subtitle': 'En iyiler arasına gir!',
        'icon': Icons.emoji_events,
        'pattern': _buildThemedPattern(const Color(0xFF9b59b6), 'leaderboard'),
        'color': const Color(0xFF9b59b6),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaderboardPage())),
        'isPrimary': false,
      },
      {
        'title': 'İSTATİSTİKLER',
        'subtitle': 'Başarılarını takip et.',
        'icon': Icons.analytics,
        'pattern': _buildThemedPattern(const Color(0xFF3498db), 'stats'),
        'color': const Color(0xFF3498db),
        'onTap': () => _showFeatureComingSoon(context, 'İstatistikler'),
        'isPrimary': false,
      },
    ];

    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        return GridView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.8,
          ),
          itemCount: menuItems.length,
          itemBuilder: (context, index) {
            final item = menuItems[index];

            final button = _buildMenuButton(
              context,
              title: item['title'] as String,
              subtitle: item['subtitle'] as String,
              icon: item['icon'] as IconData,
              pattern: item['pattern'] as Widget,
              color: item['color'] as Color,
              onTap: item['onTap'] as VoidCallback,
            );

            final animatedButton = Transform.scale(
              scale: _bounceAnimation.value.clamp(0.0, 1.0),
              child: Opacity(
                opacity: _bounceAnimation.value.clamp(0.0, 1.0),
                child: button,
              ),
            );

            if (item['isPrimary'] as bool) {
              return ScaleTransition(
                scale: _pulseAnimation,
                child: animatedButton,
              );
            }

            return animatedButton;
          },
        );
      },
    );
  }

  Widget _buildThemedPattern(Color color, String mode) {
    return ClipRect(
      child: CustomPaint(
        painter: _PatternPainter(color: color, mode: mode),
        size: Size.infinite,
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget pattern,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: AspectRatio(
        aspectRatio: 0.8,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Arka Plan & Bevel efekti
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Color.lerp(color, Colors.black, 0.5),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 8,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    colors: [
                      Color.lerp(color, Colors.white, 0.1)!,
                      color,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  children: [
                    // Görsel "Diorama" alanı
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(child: pattern),
                            Container(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
                                  radius: 1.2,
                                ),
                              ),
                            ),
                            Icon(icon, color: Colors.white, size: 50),
                          ],
                        ),
                      ),
                    ),
                    // Bilgi alanı
                    SizedBox(
                      height: 65,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Yaz teması rozeti
            Positioned(
              top: 12,
              right: 12,
              child: Transform.rotate(
                angle: math.pi / 12,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 5,
                      )
                    ],
                  ),
                  child: Icon(
                    Icons.icecream,
                    color: color,
                    size: 16,
                  ),
                ),
              ),
            ),
            // Parlaklık efekti
            AnimatedBuilder(
              animation: _sheenAnimation,
              builder: (context, child) {
                return Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Transform.translate(
                      offset: Offset(
                        MediaQuery.of(context).size.width * 0.7 * _sheenAnimation.value,
                        0,
                      ),
                      child: Transform.rotate(
                        angle: -math.pi / 12,
                        child: Container(
                          width: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.0),
                                Colors.white.withOpacity(0.3),
                                Colors.white.withOpacity(0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakInfo() {
    final currentStreak = userStats?['currentStreak'] ?? 0;
    final bestStreak = userStats?['bestStreak'] ?? 0;

    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - _bounceAnimation.value.clamp(0.0, 1.0))),
          child: Opacity(
            opacity: _bounceAnimation.value.clamp(0.0, 1.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.25)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_fire_department, color: const Color(0xFFFF6B35).withOpacity(0.9), size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Seri: $currentStreak',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(width: 20),
                  Text('|', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16)),
                  const SizedBox(width: 20),
                  Icon(Icons.star, color: const Color(0xFFFFC700).withOpacity(0.9), size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'En İyi: $bestStreak',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummerWaves() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: 100,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return CustomPaint(
            painter: _WavePainter(animationValue: _animationController.value),
          );
        },
      ),
    );
  }
}

// Oyun temalı pattern çizen custom painter
class GamePatternPainter extends CustomPainter {
  final List<WordleParticle> particles;
  
  GamePatternPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      canvas.save();
      canvas.translate(particle.position.dx, particle.position.dy);
      canvas.rotate(particle.rotation);
      canvas.scale(particle.scale);

      const double boxSize = 40.0;
      const double spacing = 8.0;
      final double totalWidth = (boxSize * particle.word.length) + (spacing * (particle.word.length - 1));

      for (int j = 0; j < particle.word.length; j++) {
    final paint = Paint()
          ..color = particle.colors[j]
      ..style = PaintingStyle.fill;

        final rect = Rect.fromLTWH(
          (-totalWidth / 2) + (j * (boxSize + spacing)),
          -boxSize / 2,
          boxSize,
          boxSize,
        );
        
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(8)),
          paint,
        );
        
        final textStyle = const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        );
        final textSpan = TextSpan(
          text: particle.word[j],
          style: textStyle,
        );
        final textPainter = TextPainter(
          text: textSpan,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            rect.center.dx - textPainter.width / 2,
            rect.center.dy - textPainter.height / 2,
          ),
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(GamePatternPainter oldDelegate) {
    return true;
  }
}

class WordleParticle {
  static const List<String> _words = ['SİHİR', 'MAHALLE', 'DÜŞÜNCE', 'GEZEGEN', 'ÖZGÜRLÜK', 'ÖĞRENCİ'];
  static const List<Color> _wordleColors = [
    Color(0xFF6AAA64), // Green
    Color(0xFFC9B458), // Yellow
    Color(0xFF787C7E), // Grey
  ];

  String word;
  Offset position;
  Offset velocity;
  double rotation;
  double rotationSpeed;
  double scale;
  List<Color> colors;

  WordleParticle(math.Random random, Size size)
      : word = _words[random.nextInt(_words.length)],
        position = Offset(
          random.nextDouble() * (size.width - 100) + 50,
          random.nextDouble() * (size.height - 100) + 50,
        ),
        velocity = Offset.zero,
        rotation = random.nextDouble() * math.pi * 2,
        rotationSpeed = (random.nextDouble() - 0.5) * 0.01,
        scale = random.nextDouble() * 0.2 + 0.3,
        colors = [] {
    final initialVelocity = Offset(random.nextDouble() - 0.5, random.nextDouble() - 0.5);
    velocity = initialVelocity.distance == 0
        ? const Offset(0.2, 0.2)
        : initialVelocity / initialVelocity.distance * 0.5;

    colors = List.generate(
      word.length,
      (_) => _wordleColors[random.nextInt(_wordleColors.length)].withOpacity(random.nextDouble() * 0.4 + 0.3),
    );
  }

  double get radius => (40.0 * scale * word.length) / 2;

  void update(Size size) {
    position += velocity;
    rotation += rotationSpeed;

    if (position.dx - radius < 0 && velocity.dx < 0) {
      velocity = Offset(-velocity.dx, velocity.dy);
      position = Offset(radius, position.dy);
    } else if (position.dx + radius > size.width && velocity.dx > 0) {
      velocity = Offset(-velocity.dx, velocity.dy);
      position = Offset(size.width - radius, position.dy);
    }

    if (position.dy - radius < 0 && velocity.dy < 0) {
      velocity = Offset(velocity.dx, -velocity.dy);
      position = Offset(position.dx, radius);
    } else if (position.dy + radius > size.height && velocity.dy > 0) {
      velocity = Offset(velocity.dx, -velocity.dy);
      position = Offset(position.dx, size.height - radius);
    }
  }

  void resolveCollision(WordleParticle other) {
    final delta = position - other.position;
    final dist = delta.distance;

    final minDistance = radius + other.radius;

    if (dist < minDistance && dist > 0) {
      // 1. Overlap resolution
      final normal = delta / dist;
      final overlap = 0.5 * (minDistance - dist);
      position += normal * overlap;
      other.position -= normal * overlap;

      // 2. Collision response (elastic collision)
      final relativeVelocity = velocity - other.velocity;
      final velAlongNormal = relativeVelocity.dx * normal.dx + relativeVelocity.dy * normal.dy;

      if (velAlongNormal > 0) return;

      const restitution = 0.8; // Bounciness
      double j = -(1 + restitution) * velAlongNormal;
      j /= 2; // assuming equal mass m1=m2=1, so 1/m1 + 1/m2 = 2

      final impulse = normal * j;
      velocity += impulse;
      other.velocity -= impulse;
    }
  }
}

class _WavePainter extends CustomPainter {
  final double animationValue;

  _WavePainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final wave1 = Paint()..color = const Color(0xFF3498db).withOpacity(0.3);
    final wave2 = Paint()..color = const Color(0xFF2980b9).withOpacity(0.3);

    _drawWave(canvas, size, wave1, animationValue, 0);
    _drawWave(canvas, size, wave2, animationValue, 0.5);
  }

  void _drawWave(Canvas canvas, Size size, Paint paint, double animationValue, double phaseOffset) {
    final path = Path();
    path.moveTo(0, size.height);

    for (double x = 0; x <= size.width; x++) {
      final angle = 2 * math.pi * (x / size.width) + (2 * math.pi * animationValue) + (math.pi * phaseOffset);
      final y = size.height * 0.7 + math.sin(angle) * 15;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) => true;
}

class _PatternPainter extends CustomPainter {
  final Color color;
  final String mode;

  _PatternPainter({required this.color, required this.mode});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    switch (mode) {
      case 'daily': // Sun Rays
        final center = Offset(size.width / 2, size.height / 2);
        for (int i = 0; i < 12; i++) {
          final angle = (i / 12) * 2 * math.pi;
          final start = center;
          final end = center + Offset.fromDirection(angle, 100);
          canvas.drawLine(start, end, paint);
        }
        break;
      case 'duel': // Heat Haze
        final hazePaint = Paint()..color = Colors.redAccent.withOpacity(0.15);
        for (double i = 0; i < size.height; i += 10) {
          final path = Path();
          path.moveTo(0, i);
          for (double j = 0; j < size.width; j += 10) {
            path.lineTo(j, i + math.sin(j / 20) * 5);
          }
          canvas.drawPath(path, hazePaint..style=PaintingStyle.stroke..strokeWidth=1);
        }
        break;
      case 'leaderboard': // Bubbles / Sparkles
        final bubblePaint = Paint()..color = Colors.yellow.withOpacity(0.3);
        for (int i = 0; i < 15; i++) {
          final center = Offset(
            math.Random(i).nextDouble() * size.width,
            math.Random(i * 2).nextDouble() * size.height,
          );
          final radius = math.Random(i * 3).nextDouble() * 5 + 2;
          canvas.drawCircle(center, radius, bubblePaint);
        }
        break;
      case 'stats': // Wave Chart
        final path = Path();
        path.moveTo(0, size.height * 0.8);
        for (double i = 0; i < size.width; i += 5) {
          final y = size.height * 0.6 - math.sin(i / 20) * size.height * 0.2;
          path.lineTo(i, y);
        }
        canvas.drawPath(path, paint..style=PaintingStyle.stroke..strokeWidth=2);
        break;
    }
  }

  @override
  bool shouldRepaint(_PatternPainter oldDelegate) => false;
}