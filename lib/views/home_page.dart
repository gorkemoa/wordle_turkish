// lib/views/home_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../services/firebase_service.dart';

import 'duel_page.dart';
import 'leaderboard_page.dart';
import 'token_shop_page.dart';
import 'wordle_page.dart';
import 'profile_page.dart';
import '../viewmodels/wordle_viewmodel.dart';
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
  int activeUsers = 0;
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late AnimationController _bounceController;
  late Animation<double> _animation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _bounceAnimation;
  late AnimationController _dailyChallengePulseController;
  late Animation<double> _dailyChallengePulseAnimation;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userStatsSubscription;
  StreamSubscription<int>? _activeUsersSubscription;
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
    _activeUsersSubscription?.cancel();
    FirebaseService.setUserOffline(); // Çıkışta offline işaretle
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
      _startListeningToActiveUsers();
      
      // Kullanıcıyı online olarak işaretle
      FirebaseService.setUserOnline();

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

  void _startListeningToActiveUsers() {
    _activeUsersSubscription?.cancel();
    
    // Stream'i hemen başlat - kullanıcı direkt aktif sayıyı görsün
    _activeUsersSubscription = FirebaseService.getActiveUsersCount().listen(
      (count) {
        print('HomePage - Aktif kullanıcı sayısı: $count');
        if (mounted) {
          setState(() {
            activeUsers = count;
          });
        }
      },
      onError: (error) {
        print('Aktif kullanıcıları dinleme hatası: $error');
      },
    );
    
    // Realtime Database otomatik presence yönetimi kullandığı için heartbeat gerekli değil
  }



  void _showFeatureComingSoon(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.construction, color: Colors.orange.shade400),
              const SizedBox(width: 8),
              Text(
                '$feature Geliyor!',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          content: Text(
            'Bu özellik henüz geliştiriliyor. Çok yakında sizlerle buluşacak!',
            style: TextStyle(color: Colors.grey.shade300, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Tamam',
                style: TextStyle(color: Colors.blue.shade400),
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

  void _navigateToTokenShop() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TokenShopPage(),
      ),
    );
  }

  void _startDuel(BuildContext context) async {
    // Jeton kontrolü
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final tokens = await FirebaseService.getUserTokens(user.uid);
      if (tokens < 2) {
        _showDuelTokenDialog(context, tokens);
        return;
      }
    }
    
    // Jeton yeterli, düello başlat - Her seferinde yeni key ile
    Navigator.push(context, MaterialPageRoute(builder: (context) => DuelPage(key: UniqueKey())));
  }

  void _showDuelTokenDialog(BuildContext context, int currentTokens) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber),
              SizedBox(width: 8),
              Text(
                'Yetersiz Jeton',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Düello oynamak için 2 jetona ihtiyacınız var.',
                style: TextStyle(color: Colors.grey.shade300, fontSize: 14),
              ),
              const SizedBox(height: 10),
              Text(
                'Mevcut jetonunuz: $currentTokens 🪙',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 Düello Sistemi:',
                      style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• Her oyuncu 2 jeton öder\n• Kazanan toplam 4 jeton alır\n• Kaybeden hiçbir şey alamaz',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(context, MaterialPageRoute(builder: (context) => const TokenShopPage()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              child: const Text('Jeton Al'),
            ),
          ],
        );
      },
    );
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
                    const SizedBox(height: 12),
                    // Kompakt jeton alanı
                    _buildCompactTokenArea(user),
                    const SizedBox(height: 12),
                    Expanded(
                        child: _buildGameMenu(context),
                    ),
                    _buildStreakInfo(),
                    const SizedBox(height: 8),
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
                if (snapshot.connectionState == ConnectionState.waiting) {
                  // Loading durumunda basit bir avatar göster
                  return CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFF4285F4).withOpacity(0.8),
                    child: const Icon(Icons.person, color: Colors.white, size: 24),
                  );
                }
                
                final userAvatar = snapshot.data ?? '👤';
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

          Tooltip(
            message: 'Jeton Satın Al\n🪙 Düello oynamak ve özel özellikler için jeton gerekli',
            textStyle: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _navigateToTokenShop();
              },
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
              stream: user != null 
                  ? FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots()
                  : Stream.value(null),
              builder: (context, snapshot) {
                int tokens = 0;
                if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                  tokens = (snapshot.data!.data() ?? {})['tokens'] ?? 0;
                }
                  return _buildEnhancedTokenChip(tokens);
              },
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildHeaderButton(Icons.brightness_6_outlined, widget.toggleTheme ?? () {}),
        ],
      ),
    );
  }


  Widget _buildEnhancedTokenChip(int tokens) {
    final isLowTokens = tokens < 5; // 5'ten az jeton varsa dikkat çek
    
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isLowTokens ? _pulseAnimation.value * 1.1 : _pulseAnimation.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isLowTokens 
                  ? [Colors.red.shade300, Colors.red.shade600]
                  : [Colors.amber.shade300, Colors.amber.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: (isLowTokens ? Colors.red : Colors.amber).withOpacity(0.6),
                  blurRadius: isLowTokens ? 12 : 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: isLowTokens ? Colors.red.shade200 : Colors.amber.shade200,
                width: isLowTokens ? 2 : 1.5,
              ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
                // Animasyonlu jeton ikonu
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _animationController.value * 2 * math.pi * (isLowTokens ? 0.2 : 0.1),
                      child: Icon(
                        isLowTokens ? Icons.warning_amber_rounded : Icons.monetization_on,
                        color: Colors.white,
                        size: 18,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),
                // Jeton sayısı
                Text(
                  tokens.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 4),
                // Plus ikonu - daha belirgin
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.add,
                    color: isLowTokens ? Colors.red.shade700 : Colors.amber.shade700,
                    size: 14,
                  ),
                ),
                if (isLowTokens) ...[
          const SizedBox(width: 4),
          Text(
                    '!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactTokenArea(User? user) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
      stream: user != null 
          ? FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots()
          : Stream.value(null),
      builder: (context, snapshot) {
        int tokens = 0;
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          tokens = (snapshot.data!.data() ?? {})['tokens'] ?? 0;
        }
        
        final isLowTokens = tokens < 5;
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.indigo.shade700.withOpacity(0.8),
                Colors.purple.shade700.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Sol: Jeton durumu
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
                        color: isLowTokens ? Colors.red.shade600 : Colors.amber.shade600,
          shape: BoxShape.circle,
        ),
        child: Icon(
                        isLowTokens ? Icons.warning : Icons.monetization_on,
          color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jetonlarınız',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              tokens.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade600,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(
                                Icons.monetization_on,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Sağ: Hızlı satın alma butonları
              Row(
                children: [
                  _buildQuickBuyButton(
                    '10',
                    'Ücretsiz',
                    Colors.green,
                    Icons.play_arrow,
                    () => _navigateToTokenShop(),
                  ),
                  const SizedBox(width: 8),
                  _buildQuickBuyButton(
                    '50',
                    '9.99₺',
                    Colors.blue,
                    Icons.star,
                    () => _showPremiumPurchase('starter'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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


  Widget _buildQuickBuyButton(
    String tokens,
    String price,
    Color color,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 16,
            ),
            const SizedBox(height: 2),
            Text(
              tokens,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              price,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleMenuButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
              color.withOpacity(0.8),
              color.withOpacity(0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
            Icon(
              icon,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
              textAlign: TextAlign.center,
                              ),
            const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 10,
                            ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
    );
  }

  void _showPremiumPurchase(String packageType) {
    Map<String, dynamic> packageInfo = {};
    
    switch (packageType) {
      case 'starter':
        packageInfo = {
          'title': 'Başlangıç Paketi',
          'tokens': 50,
          'price': '₺9.99',
          'description': '50 jeton ile düelloları keşfet!',
          'color': Colors.blue,
        };
        break;
      case 'pro':
        packageInfo = {
          'title': 'Pro Paketi',
          'tokens': 150,
          'price': '₺24.99',
          'description': '150 jeton + %20 bonus! En popüler seçim.',
          'color': Colors.purple,
        };
        break;
    }
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [packageInfo['color'].shade300, packageInfo['color'].shade600],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.diamond, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      packageInfo['title'],
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    Text(
                      packageInfo['description'],
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                    colors: [packageInfo['color'].withOpacity(0.2), packageInfo['color'].withOpacity(0.1)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${packageInfo['tokens']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('🪙', style: TextStyle(fontSize: 20)),
                      ],
                    ),
                    Text(
                      packageInfo['price'],
                      style: TextStyle(
                        color: packageInfo['color'],
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '🚀 Anında teslimat\n💎 Premium kalite\n🔒 Güvenli ödeme\n🎮 Sınırsız düello',
                style: TextStyle(color: Colors.grey.shade300, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showFeatureComingSoon(context, 'Premium Satın Alma');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: packageInfo['color'],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('${packageInfo['price']} - Satın Al'),
            ),
          ],
        );
      },
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
        'title': 'TEK OYUNCU',
        'subtitle': 'Günlük kelime bulmaca',
        'icon': Icons.person,
        'color': const Color(0xFF2ecc71),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (context) => WordlePage(toggleTheme: widget.toggleTheme ?? () {}, gameMode: GameMode.daily))),
      },
      {
        'title': 'DÜELLO',
        'subtitle': activeUsers > 1 ? '$activeUsers kişi aktif!' : 'Arkadaşlarınla kapış!',
        'icon': Icons.sports_esports,
        'color': const Color(0xFFe74c3c),
        'onTap': () => _startDuel(context),
      },
      {
        'title': 'LİDER TABLOSU',
        'subtitle': 'En iyiler arasına gir',
        'icon': Icons.emoji_events,
        'color': const Color(0xFF9b59b6),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaderboardPage())),
      },
      {
        'title': 'PROFİL',
        'subtitle': 'Hesap ayarları',
        'icon': Icons.account_circle,
        'color': const Color(0xFF3498db),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage())),
      },
    ];

    return Container(
      height: 320,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.1,
        ),
        itemCount: menuItems.length,
        itemBuilder: (context, index) {
          final item = menuItems[index];
          return _buildSimpleMenuButton(
            context,
            title: item['title'] as String,
            subtitle: item['subtitle'] as String,
            icon: item['icon'] as IconData,
            color: item['color'] as Color,
            onTap: item['onTap'] as VoidCallback,
          );
        },
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