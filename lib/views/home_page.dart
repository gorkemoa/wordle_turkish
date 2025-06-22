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

class HomePage extends StatefulWidget {
  final VoidCallback? toggleTheme;

  const HomePage({Key? key, this.toggleTheme}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  Map<String, dynamic>? userStats;
  bool isLoading = true;
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late AnimationController _bounceController;
  late Animation<double> _animation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _bounceAnimation;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userStatsSubscription;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadData();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _animationController.repeat();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _bounceController.dispose();
    _userStatsSubscription?.cancel();
    super.dispose();
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
          if (_bounceController.status == AnimationStatus.dismissed) {
            _bounceController.forward();
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
            SafeArea(
              child: RefreshIndicator(
                onRefresh: _refreshData,
                color: Colors.white,
                backgroundColor: const Color(0xFF4285F4),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Modern Header
                        _buildModernHeader(user),
                        
                        const SizedBox(height: 20),
                        
                        // Hoş geldin bölümü
                        AnimatedBuilder(
                          animation: _bounceAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _bounceAnimation.value.clamp(0.0, 1.0),
                              child: _buildWelcomeSection(user),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // İstatistikler
                        _buildAnimatedStatsSection(),
                        
                        const SizedBox(height: 24),
                        
                        // Oyun Modları
                        _buildGameModesSection(context),
                        
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernHeader(User? user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                boxShadow: [
                  BoxShadow(
            color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
            offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
          // Animasyonlu Logo
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 50,
                  height: 50,
                    decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.9),
                        Colors.white.withOpacity(0.7),
                      ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.psychology,
                    color: Color(0xFF4285F4),
                      size: 28,
                    ),
                ),
              );
            },
                  ),
                  const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                      'Kelime Bul',
                      style: TextStyle(
                    fontSize: 22,
                        fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Zihninizi Geliştirin',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
                    ),
                  ),
                  
                  // Bildirim butonu
          _buildHeaderButton(
                          Icons.notifications_outlined,
            () => _showFeatureComingSoon(context, 'Bildirimler'),
          ),
          
          const SizedBox(width: 8),
                  
                  // Profil butonu
                  GestureDetector(
                    onTap: () => _showUserProfile(context),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.9),
                    Colors.white.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                      ),
                      child: FutureBuilder<String?>(
                        future: FirebaseService.getUserAvatar(user?.uid ?? ''),
                        builder: (context, snapshot) {
                          final userAvatar = snapshot.data ?? AvatarService.generateAvatar(user?.uid ?? '');
                          
                          return CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFF4285F4),
                            backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                            child: user?.photoURL == null
                                ? Text(
                                    userAvatar,
                                    style: const TextStyle(fontSize: 16),
                                  )
                                : null,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildHeaderButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
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
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF667eea),
          Color(0xFF764ba2),
          Color(0xFF6B73FF),
          Color(0xFF000DFF),
        ],
        stops: [0.0, 0.3, 0.7, 1.0],
      ),
    );
  }

  Widget _buildBackgroundPattern() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: GamePatternPainter(_animation.value),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildWelcomeSection(User? user) {
    final currentStreak = userStats?['currentStreak'] ?? 0;
    final bestStreak = userStats?['bestStreak'] ?? 0;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.2),
            Colors.white.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
            ),
            child: FutureBuilder<String?>(
              future: FirebaseService.getUserAvatar(user?.uid ?? ''),
              builder: (context, snapshot) {
                final userAvatar = snapshot.data ?? AvatarService.generateAvatar(user?.uid ?? '');
                
                return CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.transparent,
                  backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                  child: user?.photoURL == null
                      ? Text(
                          userAvatar,
                          style: const TextStyle(fontSize: 32),
                        )
                      : null,
                );
              },
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Merhaba, ${user?.displayName ?? 'Oyuncu'}!',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Icon(
                            currentStreak > 0 ? Icons.local_fire_department : Icons.psychology,
                            color: currentStreak > 0 ? const Color(0xFFFF6B35) : Colors.white70,
                            size: 20,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$currentStreak kazanma serisi',
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'En iyi: $bestStreak',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedStatsSection() {
    final level = userStats?['level'] ?? 1;
    final tokens = userStats?['tokens'] ?? 100;
    final points = userStats?['points'] ?? 150;
    final gamesPlayed = userStats?['gamesPlayed'] ?? 0;
    
    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - _bounceAnimation.value.clamp(0.0, 1.0))),
          child: Opacity(
            opacity: _bounceAnimation.value.clamp(0.0, 1.0),
            child: Row(
      children: [
        Expanded(
                  child: _buildAnimatedStatCard('🏆', 'Seviye', level.toString(), const Color(0xFFFF9500)),
        ),
        const SizedBox(width: 12),
        Expanded(
                  child: _buildAnimatedStatCard('🪙', 'Jeton', tokens.toString(), const Color(0xFF4285F4)),
        ),
        const SizedBox(width: 12),
        Expanded(
                  child: _buildAnimatedStatCard('⭐', 'Puan', points.toString(), const Color(0xFF34A853)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAnimatedStatCard('🎮', 'Oyun', gamesPlayed.toString(), const Color(0xFF9C27B0)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedStatCard(String emoji, String label, String value, Color accentColor) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.98 + (0.02 * _pulseAnimation.value),
          child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.1),
            blurRadius: 10,
                  offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
                  style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
                    color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
            ),
      ),
        );
      },
    );
  }

  Widget _buildGameModesSection(BuildContext context) {
    final gamesPlayed = userStats?['gamesPlayed'] ?? 0;
    final gamesWon = userStats?['gamesWon'] ?? 0;
    final winRate = gamesPlayed > 0 ? (gamesWon / gamesPlayed * 100).toInt() : 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Oyun Modları',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.0,
            children: [
            _buildAnimatedGameModeCard(
                'Günlük Oyun',
                'Her zaman 5 harfli kelimeler',
                const Color(0xFF34A853),
                Icons.today,
                () => Navigator.pushNamed(context, '/wordle_daily'),
              ),
            _buildAnimatedGameModeCard(
                'Zorlu Mod',
                '4-8 harf kademeli zorluk',
                const Color(0xFFFF6B35),
                Icons.fitness_center,
                () => Navigator.pushNamed(context, '/wordle_challenge'),
              ),
            _buildAnimatedGameModeCard(
                'Duello Modu',
                'Kazanma oranın: %$winRate',
                const Color(0xFF4285F4),
                Icons.sports_esports,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DuelPage()),
                ),
              ),
            _buildAnimatedGameModeCard(
                'Başarı Tablosu',
                'Sıralamadaki yerin',
                const Color(0xFFE91E63),
                Icons.leaderboard,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LeaderboardPage()),
                ),
              ),
            _buildAnimatedGameModeCard(
                'İstatistikler',
                'Oyun performansın',
                const Color(0xFF9C27B0),
                Icons.analytics,
                () => _showFeatureComingSoon(context, 'İstatistikler'),
              ),
            ],
        ),
      ],
    );
  }

  Widget _buildAnimatedGameModeCard(
    String title,
    String description,
    Color color,
    IconData icon,
    VoidCallback onTap,
  ) {
    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _bounceAnimation.value.clamp(0.0, 1.0),
          child: GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
                padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 55,
                            height: 55,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                              borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                              size: 28,
                ),
                          ),
                        );
                      },
              ),
              
                    const SizedBox(height: 16),
              
              Text(
                title,
                style: const TextStyle(
                        fontSize: 15,
                  fontWeight: FontWeight.bold,
                        color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              
                    const SizedBox(height: 6),
              
              Text(
                description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                        height: 1.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
                ),
          ),
        ),
      ),
        );
      },
    );
  }
}

// Oyun temalı pattern çizen custom painter
class GamePatternPainter extends CustomPainter {
  final double animationValue;
  
  GamePatternPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Kelime bloklarını temsil eden kareler çiz
    final blockSize = 25.0;
    final spacing = 35.0;
    
    for (double x = -spacing; x < size.width + spacing; x += spacing) {
      for (double y = -spacing; y < size.height + spacing; y += spacing) {
        final offsetX = x + (animationValue * 10);
        final offsetY = y + (animationValue * 5);
        
        // Ana kareler
        final rect = Rect.fromLTWH(
          offsetX,
          offsetY,
          blockSize,
          blockSize,
        );
        
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          paint,
        );
        
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          strokePaint,
        );
        
        // Küçük noktalar (harfleri temsil eder)
        if ((x + y) % 70 == 0) {
          final dotPaint = Paint()
            ..color = Colors.white.withOpacity(0.06)
            ..style = PaintingStyle.fill;
            
          canvas.drawCircle(
            Offset(offsetX + blockSize / 2, offsetY + blockSize / 2),
            3.0,
            dotPaint,
          );
        }
      }
    }

    // Rotating circles
    final circlePaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int i = 0; i < 3; i++) {
      final radius = 100.0 + (i * 50);
      final angle = animationValue * 2 * math.pi + (i * math.pi / 3);
      final centerX = size.width / 2 + math.cos(angle) * 50;
      final centerY = size.height / 2 + math.sin(angle) * 30;
      
      canvas.drawCircle(
        Offset(centerX, centerY),
        radius,
        circlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(GamePatternPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}