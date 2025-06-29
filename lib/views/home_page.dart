// lib/views/home_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:math';
import '../services/firebase_service.dart';
import '../services/haptic_service.dart';

import 'duel_page.dart';
import 'leaderboard_page.dart';
import 'token_shop_page.dart';
import 'free_game_page.dart';
import 'challenge_game_page.dart';
import 'time_rush_page.dart';
import 'themed_game_page.dart';
import 'themed_mode_page.dart';
import '../viewmodels/wordle_viewmodel.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'duel_waiting_room.dart';

// Ana sayfa

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

  late AnimationController _fadeController;
  late AnimationController _particleController;
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late AnimationController _letterController;
  
  late Animation<double> _fadeAnimation;
  late Animation<double> _particleAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _letterAnimation;
  
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userStatsSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userProfileSubscription;
  StreamSubscription<int>? _activeUsersSubscription;

  final List<FloatingParticle> _particles = [];
  final Random _random = Random();

  // Responsive boyutlar için getter'lar
  late double _screenWidth;
  late double _screenHeight;
  late double _horizontalPadding;
  late double _verticalPadding;
  late double _titleLetterSize;
  late double _gameModeCardHeight;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeParticles();
    _loadData();
    HapticService.loadHapticSettings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calculateResponsiveSizes();
  }

  void _calculateResponsiveSizes() {
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;
    
    // Responsive değerler hesapla
    _horizontalPadding = _screenWidth * 0.06; // Ekran genişliğinin %6'sı
    _verticalPadding = _screenHeight * 0.025; // Ekran yüksekliğinin %2.5'i
    _titleLetterSize = _screenWidth * 0.1; // Ekran genişliğinin %10'u
    _gameModeCardHeight = _screenHeight * 0.12; // Ekran yüksekliğinin %12'si
  }

  // Responsive font boyutu hesaplama
  double _getResponsiveFontSize(double baseSize) {
    return baseSize * (_screenWidth / 375); // iPhone 6/7/8 baz alınarak
  }

  // Responsive padding hesaplama
  EdgeInsets _getResponsivePadding({
    double horizontal = 16.0,
    double vertical = 12.0,
  }) {
    return EdgeInsets.symmetric(
      horizontal: horizontal * (_screenWidth / 375),
      vertical: vertical * (_screenHeight / 667),
    );
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutQuart,
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _particleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_particleController);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _letterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _letterAnimation = CurvedAnimation(
      parent: _letterController,
      curve: Curves.elasticOut,
    );
  }

  void _initializeParticles() {
    for (int i = 0; i < 25; i++) {
      _particles.add(FloatingParticle(_random));
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _particleController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    _letterController.dispose();
    _userStatsSubscription?.cancel();
    _userProfileSubscription?.cancel();
    _activeUsersSubscription?.cancel();
    FirebaseService.setUserOffline();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    try {
      await FirebaseService.initializeUserDataIfNeeded(user.uid);
      _startListeningToUserStats(user.uid);
      _startListeningToUserProfile(user.uid);
      _startListeningToActiveUsers();
      await FirebaseService.setUserOnline();
    } catch (e) {
      debugPrint('Veri yükleme hatası: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _startListeningToUserStats(String uid) {
    _userStatsSubscription = FirebaseFirestore.instance
        .collection('user_stats')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        if (snapshot.exists) {
          setState(() {
            userStats = snapshot.data();
            if(isLoading) {
              isLoading = false;
              _fadeController.forward();
              _letterController.forward();
            }
          });
        } else {
           if(mounted) setState(() => isLoading = false);
        }
      }
    }, onError: (error) {
      debugPrint('Real-time veri dinleme hatası: $error');
      if(mounted) setState(() => isLoading = false);
    });
  }

  void _startListeningToUserProfile(String uid) {
    _userProfileSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
      if (mounted && snapshot.exists) {
        final profileData = snapshot.data();
        if (profileData != null && userStats != null) {
          setState(() {
            userStats!['displayName'] = profileData['displayName'];
          });
        }
      }
    }, onError: (error) {
      debugPrint('Kullanıcı profili dinleme hatası: $error');
    });
  }

  void _startListeningToActiveUsers() {
    _activeUsersSubscription = FirebaseService.getActiveUsersCount().listen((count) {
      if (mounted) setState(() => activeUsers = count);
    }, onError: (error) {
      debugPrint('Aktif kullanıcıları dinleme hatası: $error');
    });
  }

  void _showUserProfile() => Navigator.pushNamed(context, '/profile');
  void _navigateToTokenShop() => Navigator.push(context, MaterialPageRoute(builder: (context) => const TokenShopPage()));
  void _navigateToLeaderboard() => Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaderboardPage()));
  void _navigateToFreeWordle() => Navigator.push(context, MaterialPageRoute(builder: (context) => FreeGamePage(toggleTheme: widget.toggleTheme ?? () {})));
  void _navigateToTimeRush() => Navigator.push(context, MaterialPageRoute(builder: (context) => TimeRushGamePage(toggleTheme: widget.toggleTheme ?? () {})));
  void _navigateToThemed() => Navigator.push(context, MaterialPageRoute(builder: (context) => ThemedModePage(toggleTheme: widget.toggleTheme ?? () {})));
  void _navigateToChallenge() async {
    final viewModel = Provider.of<WordleViewModel>(context, listen: false);
    await viewModel.refreshTokens(); // Jeton sayısını güncelle
    
    if (!viewModel.canPlayChallengeMode) {
      _showChallengeModeLockedDialog(viewModel.hoursUntilNextChallengeMode);
      return;
    }
    
    _showChallengeModeWarningDialog();
  }

  void _startDuel() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final tokens = await FirebaseService.getUserTokens(user.uid);
      if (tokens < 2) {
        _showDuelTokenDialog(context, tokens);
        return;
      }
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DuelWaitingRoom(),
      ),
    );
  }

  void _showDuelTokenDialog(BuildContext context, int currentTokens) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_screenWidth * 0.05),
            side: BorderSide(color: Colors.red.shade400, width: 2),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(_screenWidth * 0.02),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade400, Colors.red.shade600],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber, color: Colors.white),
              ),
              SizedBox(width: _screenWidth * 0.03),
              Text(
                'Yetersiz Jeton', 
                style: TextStyle(
                  color: Colors.white, 
                  fontSize: _getResponsiveFontSize(18), 
                  fontWeight: FontWeight.bold
                )
              ),
            ],
          ),
          content: Container(
            padding: EdgeInsets.all(_screenWidth * 0.04),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2A2A2A),
                  const Color(0xFF1A1A1D),
                ],
              ),
              borderRadius: BorderRadius.circular(_screenWidth * 0.03),
            ),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'Düello için 2 jetona ihtiyacın var.\nMevcut jetonun: $currentTokens 🪙',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9), 
                    fontSize: _getResponsiveFontSize(16)
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: _screenHeight * 0.02),
              Container(
                padding: EdgeInsets.all(_screenWidth * 0.03),
                decoration: BoxDecoration(
                    color: const Color(0xFF538D4E).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(_screenWidth * 0.02),
                    border: Border.all(color: const Color(0xFF538D4E), width: 1),
                  ),
                  child: const Text(
                    '💡 Kazanan 4 jeton alır!',
                    style: TextStyle(color: Color(0xFF538D4E), fontWeight: FontWeight.bold),
                  ),
                    ),
                  ],
                ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: _screenWidth * 0.05, 
                  vertical: _screenHeight * 0.015
                ),
              ),
              child: Text(
                'İptal', 
                style: TextStyle(
                  color: Colors.grey, 
                  fontSize: _getResponsiveFontSize(16)
                )
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToTokenShop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF538D4E),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: _screenWidth * 0.06, 
                  vertical: _screenHeight * 0.015
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_screenWidth * 0.03)
                ),
              ),
              child: Text(
                'Jeton Al', 
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(16), 
                  fontWeight: FontWeight.bold
                )
              ),
            ),
          ],
        );
      },
    );
  }

  void _showChallengeModeLockedDialog(int hoursLeft) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_screenWidth * 0.05),
            side: BorderSide(color: Colors.red.shade400, width: 2),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(_screenWidth * 0.02),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade400, Colors.red.shade600],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_clock, color: Colors.white),
              ),
              SizedBox(width: _screenWidth * 0.03),
              Text(
                'Zorlu Mod Kilitli', 
                style: TextStyle(
                  color: Colors.white, 
                  fontSize: _getResponsiveFontSize(18), 
                  fontWeight: FontWeight.bold
                )
              ),
            ],
          ),
          content: Container(
            padding: EdgeInsets.all(_screenWidth * 0.04),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2A2A2A),
                  const Color(0xFF1A1A1D),
                ],
              ),
              borderRadius: BorderRadius.circular(_screenWidth * 0.03),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Zorlu Mod sadece 24 saatte bir oynanabilir!\n\nKalan süre: $hoursLeft saat',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9), 
                    fontSize: _getResponsiveFontSize(16)
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: _screenHeight * 0.02),
                Container(
                  padding: EdgeInsets.all(_screenWidth * 0.03),
                  decoration: BoxDecoration(
                    color: Colors.red.shade400.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(_screenWidth * 0.02),
                    border: Border.all(color: Colors.red.shade400, width: 1),
                  ),
                  child: const Text(
                    '⚡ Bu özel mod için sabırla bekle!',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: _screenWidth * 0.06, 
                  vertical: _screenHeight * 0.015
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_screenWidth * 0.03)
                ),
              ),
              child: Text(
                'Tamam', 
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(16), 
                  fontWeight: FontWeight.bold
                )
              ),
            ),
          ],
        );
      },
    );
  }

  void _showChallengeModeWarningDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Dışarı tıklayarak kapatamasın
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_screenWidth * 0.05),
            side: BorderSide(color: Colors.orange.shade400, width: 3),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(_screenWidth * 0.02),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade400, Colors.red.shade600],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber, 
                  color: Colors.white, 
                  size: _getResponsiveFontSize(24)
                ),
              ),
              SizedBox(width: _screenWidth * 0.03),
              Expanded(
                child: Text(
                  'ZORLU MOD UYARISI', 
                  style: TextStyle(
                    color: Colors.white, 
                    fontSize: _getResponsiveFontSize(18), 
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  )
                ),
              ),
            ],
          ),
          content: Container(
            padding: EdgeInsets.all(_screenWidth * 0.05),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2A2A2A),
                  const Color(0xFF1A1A1D),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(_screenWidth * 0.03),
              border: Border.all(color: Colors.orange.shade400.withOpacity(0.3), width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(_screenWidth * 0.04),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(_screenWidth * 0.03),
                    border: Border.all(color: Colors.red.shade400, width: 1),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '⚠️ DİKKAT ⚠️',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: _getResponsiveFontSize(20),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(height: _screenHeight * 0.015),
                      Text(
                        '• Zamanlayıcı yok - sınırsız süre\n• İpucu yok - tamamen kendi başına\n• Oyundan çıkarsan hakkını kaybedersin\n• 24 saatte sadece 1 kez oynayabilirsin\n• Kelime uzunluğu her seviyede artar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: _getResponsiveFontSize(16),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: _screenHeight * 0.02),
                Container(
                  padding: EdgeInsets.all(_screenWidth * 0.03),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade800, Colors.green.shade600],
                    ),
                    borderRadius: BorderRadius.circular(_screenWidth * 0.02),
                  ),
                  child: Text(
                    '🏆 Ödül: Her seviyede daha fazla jeton!\n(2-4-6-8-10 jeton)',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: _getResponsiveFontSize(14),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: _screenWidth * 0.05, 
                  vertical: _screenHeight * 0.015
                ),
              ),
              child: Text(
                'İptal', 
                style: TextStyle(
                  color: Colors.grey, 
                  fontSize: _getResponsiveFontSize(16)
                )
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (context) => ChallengeGamePage(
                      toggleTheme: widget.toggleTheme ?? () {}
                    )
                  )
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: _screenWidth * 0.06, 
                  vertical: _screenHeight * 0.015
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_screenWidth * 0.03)
                ),
              ),
              child: Text(
                'BAŞLA', 
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(16), 
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                )
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  padding: EdgeInsets.all(_screenWidth * 0.08),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF538D4E),
                        const Color(0xFF6AAA64),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF538D4E).withOpacity(0.5),
                        blurRadius: _screenWidth * 0.05,
                        spreadRadius: _screenWidth * 0.01,
                      ),
                    ],
                  ),
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: _screenWidth * 0.01,
                  ),
                ),
              ),
              SizedBox(height: _screenHeight * 0.04),
              Text(
                'HARFLE Yükleniyor...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _getResponsiveFontSize(20),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // Animated Background Grid
          AnimatedBuilder(
            animation: _particleAnimation,
            builder: (context, child) {
              return CustomPaint(
                painter: _EnhancedGridPainter(_particleAnimation.value),
                size: Size.infinite,
              );
            },
          ),
          // Floating Particles
          AnimatedBuilder(
            animation: _particleAnimation,
            builder: (context, child) {
              return CustomPaint(
                painter: _ParticlePainter(_particles, _particleAnimation.value),
                size: Size.infinite,
              );
            },
          ),
          // Main Content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: _horizontalPadding,
                  vertical: _verticalPadding,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPlayerCard(FirebaseAuth.instance.currentUser),
                    _buildAnimatedGameTitle(),
                    _buildFreeChallenge(),
                    _buildGameModeGrid(),
                    _buildBottomPanel(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(User? user) {
    final level = userStats?['level'] ?? 1;
    final displayName = isLoading 
        ? (user?.displayName ?? 'Yükleniyor...')
        : (userStats?['displayName'] ?? user?.displayName ?? 'Oyuncu');

    return GestureDetector(
      onTap: () {
        HapticService.triggerLightHaptic();
        _showUserProfile();
      },
      child: Container(
        padding: _getResponsivePadding(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF2A2A2D),
              const Color(0xFF1A1A1D),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(_screenWidth * 0.04),
          border: Border.all(color: const Color(0xFF538D4E), width: 1.5),
        ),
        child: Row(
          children: [
            Hero(
              tag: 'user_avatar',
              child: Container(
                padding: EdgeInsets.all(_screenWidth * 0.008),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF538D4E),
                      const Color(0xFF6AAA64),
                    ],
                  ),
                ),
                child: FutureBuilder<String?>(
                  future: FirebaseService.getUserAvatar(user?.uid ?? ''),
                  builder: (context, snapshot) {
                    return CircleAvatar(
                      radius: _screenWidth * 0.06,
                      backgroundColor: const Color(0xFF3A3A3C),
                      backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                      child: snapshot.data == null && user?.photoURL == null
                          ? Icon(
                              Icons.person, 
                              color: Colors.white, 
                              size: _screenWidth * 0.06,
                            )
                          : (user?.photoURL == null 
                              ? Text(
                                  snapshot.data!, 
                                  style: TextStyle(fontSize: _getResponsiveFontSize(20))
                                ) 
                              : null),
                    );
                  },
                ),
              ),
            ),
            SizedBox(width: _screenWidth * 0.04),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(18),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Seviye $level',
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(14),
                      color: const Color(0xFF538D4E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
              stream: user != null ? FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots() : null,
              builder: (context, snapshot) {
                final tokens = (snapshot.data?.data() ?? {})['tokens'] ?? 0;
                return GestureDetector(
                  onTap: () {
                    HapticService.triggerMediumHaptic();
                    _navigateToTokenShop();
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: _screenWidth * 0.04,
                      vertical: _screenHeight * 0.01,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber.shade400,
                          Colors.orange.shade600,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(_screenWidth * 0.05),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.monetization_on, 
                          color: Colors.white, 
                          size: _getResponsiveFontSize(18),
                        ),
                        SizedBox(width: _screenWidth * 0.015),
                        Text(
                          tokens.toString(),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: _getResponsiveFontSize(16),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            SizedBox(width: _screenWidth * 0.03),
            _buildHapticToggleButton(),
            SizedBox(width: _screenWidth * 0.02),
            GestureDetector(
              onTap: () {
                HapticService.triggerLightHaptic();
                _showUserProfile();
              },
              child: Container(
                padding: EdgeInsets.all(_screenWidth * 0.03),
                decoration: BoxDecoration(
                  color: const Color(0xFF9B59B6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                  size: _getResponsiveFontSize(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHapticToggleButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: HapticService.hapticEnabledNotifier,
      builder: (context, isEnabled, child) {
        return GestureDetector(
          onTap: () {
            HapticService.triggerLightHaptic();
            HapticService.toggleHapticSetting();
          },
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: isEnabled ? 1.0 + (_pulseAnimation.value - 1.0) * 0.1 : 1.0,
                child: Container(
                  padding: EdgeInsets.all(_screenWidth * 0.03),
                  decoration: BoxDecoration(
                    color: isEnabled ? const Color(0xFF538D4E) : Colors.grey.shade700,
                    shape: BoxShape.circle,
                    boxShadow: isEnabled ? [
                      BoxShadow(
                        color: const Color(0xFF538D4E).withOpacity(0.5),
                        blurRadius: _screenWidth * 0.025,
                        spreadRadius: _screenWidth * 0.005,
                      ),
                    ] : null,
                  ),
                  child: Icon(
                    isEnabled ? Icons.vibration : Icons.phonelink_erase_rounded,
                    color: Colors.white,
                    size: _getResponsiveFontSize(20),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAnimatedGameTitle() {
    const word = 'HARFLE';
    final colors = [
      const Color(0xFF538D4E),
      const Color(0xFFC9B458),
      const Color(0xFF787C7E),
      const Color(0xFF538D4E),
      const Color(0xFFC9B458),
      const Color(0xFF787C7E),
    ];

    return AnimatedBuilder(
      animation: _letterAnimation,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(word.length, (index) {
            final delay = index * 0.1;
            final animationValue = (_letterAnimation.value - delay).clamp(0.0, 1.0);
            
            return Transform.scale(
              scale: animationValue,
              child: Transform.rotate(
                angle: (1 - animationValue) * 0.5,
                child: Container(
                  width: _titleLetterSize,
                  height: _titleLetterSize,
                  margin: EdgeInsets.symmetric(horizontal: _screenWidth * 0.015),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colors[index],
                        colors[index].withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(_screenWidth * 0.02),
                    boxShadow: [
                      BoxShadow(
                        color: colors[index].withOpacity(0.5),
                        blurRadius: _screenWidth * 0.025,
                        offset: Offset(0, _screenHeight * 0.005),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    word[index],
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(28),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildFreeChallenge() {
    return GestureDetector(
      onTap: () {
        HapticService.triggerMediumHaptic();
        _navigateToFreeWordle();
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          vertical: _screenHeight * 0.025,
          horizontal: _screenWidth * 0.04,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF538D4E),
              const Color(0xFF6AAA64),
            ],
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(_screenWidth * 0.04),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF538D4E).withOpacity(0.4),
              blurRadius: _screenWidth * 0.02,
              offset: Offset(0, _screenHeight * 0.005),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(_screenWidth * 0.02),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wb_sunny, 
                color: Colors.white, 
                size: _getResponsiveFontSize(24),
              ),
            ),
            SizedBox(width: _screenWidth * 0.03),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SERBEST OYUN',
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(18),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: _screenHeight * 0.005),
                  Text(
                    'Sınırsız oyna, pratik yap',
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(14),
                      color: Colors.white.withOpacity(0.9),
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
              
  Widget _buildGameModeGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildGameModeCard(
                title: 'ZAMANA KARŞI',
                subtitle: '60 saniye, maks puan',
                icon: Icons.timer_outlined,
                color: const Color(0xFFE74C3C),
                onTap: _navigateToTimeRush,
              ),
            ),
            SizedBox(width: _screenWidth * 0.04),
            Expanded(
              child: _buildGameModeCard(
                title: 'TEMA MODU',
                subtitle: 'Kategoriye özel kelimeler',
                icon: Icons.category_outlined,
                color: const Color(0xFF8E44AD),
                onTap: _navigateToThemed,
              ),
            ),
          ],
        ),
        SizedBox(height: _screenHeight * 0.015),
        Row(
          children: [
            Expanded(
              child: _buildGameModeCard(
                title: 'DÜELLO',
                subtitle: '$activeUsers oyuncu aktif',
                icon: Icons.people_alt_outlined,
                color: const Color(0xFFC9B458),
                onTap: _startDuel,
                notification: activeUsers > 5,
              ),
            ),
            SizedBox(width: _screenWidth * 0.04),
            Expanded(
              child: _buildGameModeCard(
                title: 'LİDER TABLOSU',
                subtitle: 'Sıralamanı gör',
                icon: Icons.leaderboard_outlined,
                color: const Color(0xFF3498DB),
                onTap: _navigateToLeaderboard,
              ),
            ),
          ],
        ),
        SizedBox(height: _screenHeight * 0.015),
        Row(
          children: [
            Expanded(
              child: Consumer<WordleViewModel>(
                builder: (context, viewModel, child) {
                  final canPlay = viewModel.canPlayChallengeMode;
                  final hoursLeft = viewModel.hoursUntilNextChallengeMode;
                  
                  return _buildChallengeCard(
                    canPlay: canPlay,
                    hoursLeft: hoursLeft,
                    onTap: _navigateToChallenge,
                  );
                },
              ),
            ),
            SizedBox(width: _screenWidth * 0.04),
            Expanded(
              child: _buildGameModeCard(
                title: 'JETON MAĞAZASI',
                subtitle: 'Jeton satın al',
                icon: Icons.store_outlined,
                color: Colors.orange.shade600,
                onTap: _navigateToTokenShop,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGameModeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool notification = false,
  }) {
    return GestureDetector(
      onTap: () {
        HapticService.triggerMediumHaptic();
        onTap();
      },
      child: Container(
        height: _gameModeCardHeight,
        padding: _getResponsivePadding(),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF2A2A2D),
              const Color(0xFF1A1A1D),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(_screenWidth * 0.04),
          border: Border.all(color: color.withOpacity(0.5), width: 1),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(_screenWidth * 0.005),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(_screenWidth * 0.02),
                  ),
                  child: Icon(
                    icon, 
                    color: color, 
                    size: _getResponsiveFontSize(26),
                  ),
                ),
                SizedBox(height: _screenHeight * 0.01), 
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: _getResponsiveFontSize(12),
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: _screenHeight * 0.002),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: _getResponsiveFontSize(9),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                )
              ],
            ),
            if (notification)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: _screenWidth * 0.02,
                  height: _screenWidth * 0.02,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    final currentStreak = userStats?['currentStreak'] ?? 0;
    final bestStreak = userStats?['bestStreak'] ?? 0;
    final gamesPlayed = userStats?['gamesPlayed'] ?? 0;
    final winRate = gamesPlayed > 0 ? ((userStats?['gamesWon'] ?? 0) / gamesPlayed * 100).round() : 0;

    return Row(
      children: [
        // Sol: İstatistikler
        Expanded(
          flex: 2,
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: _screenHeight * 0.015,
              horizontal: _screenWidth * 0.02,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2A2A2D),
                  const Color(0xFF1A1A1D),
                ],
              ),
              borderRadius: BorderRadius.circular(_screenWidth * 0.04),
              border: Border.all(color: Colors.grey.shade800),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniStatItem(Icons.local_fire_department_outlined, Colors.orange, '$currentStreak', 'Seri'),
                _buildMiniStatItem(Icons.star_outline_rounded, Colors.yellow, '$bestStreak', 'En İyi'),
                _buildMiniStatItem(Icons.online_prediction, Colors.greenAccent, '$activeUsers', 'Aktif'),
              ],
            ),
          ),
        ),
        SizedBox(width: _screenWidth * 0.03),
        // Sağ: Başarılar
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: _screenHeight * 0.015,
              horizontal: _screenWidth * 0.02,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2A2A2D),
                  const Color(0xFF1A1A1D),
                ],
              ),
              borderRadius: BorderRadius.circular(_screenWidth * 0.04),
              border: Border.all(color: Colors.grey.shade800),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMiniAchievement(Icons.military_tech, Colors.amber, (userStats?['gamesWon'] ?? 0) >= 10),
                _buildMiniAchievement(Icons.flash_on, Colors.orange, (userStats?['currentStreak'] ?? 0) >= 5),
                _buildMiniAchievement(Icons.trending_up, Colors.green, (userStats?['level'] ?? 1) >= 5),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStatItem(IconData icon, Color color, String value, String label) {
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: _getResponsiveFontSize(18)),
          SizedBox(height: _screenHeight * 0.003),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: _getResponsiveFontSize(12),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: _getResponsiveFontSize(9),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMiniAchievement(IconData icon, Color color, bool isUnlocked) {
    return Flexible(
      child: Container(
        width: _screenWidth * 0.08,
        height: _screenWidth * 0.08,
        decoration: BoxDecoration(
          color: isUnlocked ? color : Colors.grey.shade700,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: _getResponsiveFontSize(16),
        ),
      ),
    );
  }

  Widget _buildChallengeCard({
    required bool canPlay,
    required int hoursLeft,
    required VoidCallback onTap,
  }) {
    if (canPlay) {
      // Erişilebilir durum - özel tasarım
      return GestureDetector(
        onTap: () {
          HapticService.triggerMediumHaptic();
          onTap();
        },
        child: Container(
          padding: _getResponsivePadding(),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.red.shade900,
                Colors.orange.shade800,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(_screenWidth * 0.04),
            border: Border.all(color: Colors.orange.shade400, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.red.shade400.withOpacity(0.4),
                blurRadius: _screenWidth * 0.03,
                spreadRadius: _screenWidth * 0.0025,
                offset: Offset(0, _screenHeight * 0.005),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.whatshot,
                    color: Colors.white,
                    size: _getResponsiveFontSize(24),
                  ),
                  SizedBox(width: _screenWidth * 0.01),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ZORLU',
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(13),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'MOD',
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(13),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.1
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
              
                ],
              ),
              SizedBox(height: _screenHeight * 0.01),
              Text(
                '4-8 harf',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: _getResponsiveFontSize(11),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: _screenHeight * 0.01),
              Text(
                'MÜSAİT!',
                style: TextStyle(
                  color: const Color.fromRGBO(230, 224, 233, 1.0),
                  fontWeight: FontWeight.bold,
                  fontSize: _getResponsiveFontSize(13),
                  letterSpacing: 1.0,
                  height: 1.4,
                  leadingDistribution: TextLeadingDistribution.even,
                  decoration: TextDecoration.none,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    } else {
      // Kilitli durum
      return GestureDetector(
        onTap: () {
          HapticService.triggerErrorHaptic();
          onTap();
        },
        child: Container(
          padding: _getResponsivePadding(),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.grey.shade800,
                Colors.grey.shade700,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(_screenWidth * 0.04),
            border: Border.all(color: Colors.grey.shade600, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: _screenWidth * 0.02,
                spreadRadius: _screenWidth * 0.0025,
                offset: Offset(0, _screenHeight * 0.005),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_clock,
                    color: Colors.grey.shade400,
                    size: _getResponsiveFontSize(24),
                  ),
                  SizedBox(width: _screenWidth * 0.02),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ZORLU',
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(13),
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade500,
                            height: 1.1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'MOD',
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(13),
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade500,
                            height: 1.1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: _screenWidth * 0.02,
                      vertical: _screenHeight * 0.005,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(_screenWidth * 0.03),
                    ),
                    child: Text(
                      'KİLİTLİ',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: _getResponsiveFontSize(9),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: _screenHeight * 0.01),
              Text(
                '24 saatte bir oynanabilir',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: _getResponsiveFontSize(11),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: _screenHeight * 0.01),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: _screenWidth * 0.025,
                      vertical: _screenHeight * 0.008,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade700,
                      borderRadius: BorderRadius.circular(_screenWidth * 0.05),
                    ),
                    child: Text(
                      '${hoursLeft}s kaldı',
                      style: TextStyle(
                        color: Colors.grey.shade300,
                        fontWeight: FontWeight.bold,
                        fontSize: _getResponsiveFontSize(11),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.schedule,
                    color: Colors.grey.shade400,
                    size: _getResponsiveFontSize(20),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
  }
}

class FloatingParticle {
  Offset position;
  Offset velocity;
  double size;
  Color color;
  double opacity;

  FloatingParticle(Random random)
      : position = Offset(random.nextDouble() * 400, random.nextDouble() * 800),
        velocity = Offset(
          (random.nextDouble() - 0.5) * 0.5,
          -random.nextDouble() * 0.8 - 0.2,
        ),
        size = random.nextDouble() * 3 + 1,
        color = [
          const Color(0xFF538D4E),
          const Color(0xFFC9B458),
          const Color(0xFF787C7E),
        ][random.nextInt(3)],
        opacity = random.nextDouble() * 0.6 + 0.2;
}

class _EnhancedGridPainter extends CustomPainter {
  final double animationValue;

  _EnhancedGridPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade800.withOpacity(0.3 + animationValue * 0.2)
      ..strokeWidth = 1;

    for (double i = 0; i < size.width; i += 60) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 60) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ParticlePainter extends CustomPainter {
  final List<FloatingParticle> particles;
  final double animationValue;

  _ParticlePainter(this.particles, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
         for (final particle in particles) {
       particle.position += particle.velocity;
       
       if (particle.position.dy < -10) {
         particle.position = Offset(
           math.Random().nextDouble() * size.width,
           size.height + 10,
         );
       }
       if (particle.position.dx < -10 || particle.position.dx > size.width + 10) {
         particle.velocity = Offset(-particle.velocity.dx, particle.velocity.dy);
       }

      final paint = Paint()
        ..color = particle.color.withOpacity(particle.opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(particle.position, particle.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}