import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/duel_viewmodel.dart';
import '../models/duel_game.dart';
import '../services/firebase_service.dart';
import '../services/avatar_service.dart';
import 'dart:async';
import 'duel_page.dart';

// Düello bekleme odası

class DuelWaitingRoom extends StatefulWidget {
  const DuelWaitingRoom({Key? key}) : super(key: key);

  @override
  State<DuelWaitingRoom> createState() => _DuelWaitingRoomState();
}

class _DuelWaitingRoomState extends State<DuelWaitingRoom> 
    with TickerProviderStateMixin {
  
  late AnimationController _rotationController;
  late AnimationController _slideFadeController;
  late AnimationController _collisionController;
  
  late Animation<double> _rotationAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late CurvedAnimation _collisionAnimation;
  
  // Navigation flag - sadece bir kez pop yapmak için
  bool _hasNavigated = false;
  bool _hasStartedGame = false; // Oyun başlatma kontrolü için flag
  bool _hasTimedOut = false; // Timeout kontrolü için flag
  
  // 🕐 BEKLEME ODASINDA GERİ SAYIM İÇİN
  int _waitingCountdown = 30; // 30 saniye bekleme süresi
  Timer? _waitingTimer;

  @override
  void initState() {
    super.initState();
    
    // 🕐 BEKLEME ODASINDA GERİ SAYIM BAŞLAT
    _startWaitingCountdown();
    
    // Slide/Fade animasyonu (giriş efekti için)
    _slideFadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _slideFadeController,
        curve: Curves.easeOutCubic,
      ),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _slideFadeController,
        curve: Curves.easeOutCubic,
      ),
    );
    
    // Çarpışma animasyonu (tek seferlik, elastik)
    _collisionController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _collisionAnimation = CurvedAnimation(
      parent: _collisionController,
      curve: Curves.elasticOut,
    );
    
    // Rotation animasyonu
    _rotationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));
    _rotationController.repeat();

    // Giriş animasyonunu başlat
    _slideFadeController.forward();
    // Gecikmeli çarpışma animasyonunu başlat
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _collisionController.forward(from: 0.0);
      }
    });
    
    // Oyun aramasını başlat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      if (!_hasStartedGame) {
        _hasStartedGame = true;
        _startGame();
      }
    });
    
    // 15 saniye timeout ekle (test için kısaltıldı)
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && !_hasTimedOut) {
        try {
          final viewModel = Provider.of<DuelViewModel>(context, listen: false);
          if (viewModel.gameState == GameState.searching || viewModel.gameState == GameState.initializing) {
            setState(() {
              _hasTimedOut = true;
            });
            debugPrint('⏰ DuelWaitingRoom - 30 saniye timeout oldu');
          }
        } catch (e) {
          debugPrint('❌ DuelWaitingRoom - Timeout check error: $e');
        }
      }
    });
  }

  // 🕐 BEKLEME ODASINDA GERİ SAYIM BAŞLAT
  void _startWaitingCountdown() {
    _waitingTimer?.cancel();
    _waitingCountdown = 30; // 30 saniye
    
    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_waitingCountdown > 0) {
            _waitingCountdown--;
            debugPrint('⏰ Bekleme countdown: $_waitingCountdown saniye kaldı');
          } else {
            // Süre doldu
            _waitingCountdown = 30; // Reset countdown
            debugPrint('⏰ Bekleme süresi doldu, reset ediliyor');
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _waitingTimer?.cancel(); // Timer'ı temizle
    _rotationController.dispose();
    _slideFadeController.dispose();
    _collisionController.dispose();

    super.dispose();
  }

  Future<void> _startGame() async {
    try {
      if (!mounted) return;
      
      // ViewModel referansını güvenli bir şekilde al
      final viewModel = Provider.of<DuelViewModel>(context, listen: false);
      
      // Kullanıcının online olduğundan emin ol
      await FirebaseService.setUserOnline();
      
      if (!mounted) return;
      
      // Jeton kontrolü
      final user = FirebaseService.getCurrentUser();
      if (user != null) {
        final tokens = await FirebaseService.getUserTokens(user.uid);
        if (!mounted) return;
        
        if (tokens < 2) {
          _showErrorDialog('Yetersiz Jeton', 
            'Düello oynamak için 2 jetona ihtiyacınız var. Mevcut jetonunuz: $tokens\n\n💡 Jetonlar oyun başladığında kesilir.');
          return;
        }
      }
      
      final success = await viewModel.startDuelGame();
      
      if (!mounted) return;
      
      if (!success) {
        _showErrorDialog('Oyun başlatılamadı', 
          'Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin. '
          'Yetersiz jeton varsa, reklam izleyerek jeton kazanabilirsiniz.');
        return;
      }
      
      debugPrint('DuelWaitingRoom - Matchmaking başladı, listener aktif');
      
    } catch (e) {
      debugPrint('DuelWaitingRoom _startGame hatası: $e');
      if (mounted) {
        _showErrorDialog('Hata', 'Beklenmeyen bir hata oluştu: $e');
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted || !context.mounted) {
      debugPrint('🚫 DuelWaitingRoom - Widget mounted değil, error dialog gösterilmiyor');
      return;
    }
    
    try {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: Text(message, style: const TextStyle(color: Colors.grey)),
          actions: [
            TextButton(
              onPressed: () {
                try {
                  if (Navigator.canPop(dialogContext)) {
                    Navigator.pop(dialogContext);
                  }
                } catch (e) {
                  debugPrint('❌ Error dialog close error: $e');
                }
              },
              child: const Text('Tamam', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('❌ Error dialog show error: $e');
    }
  }

  Future<bool> _showExitConfirmDialog() async {
    if (!mounted || !context.mounted) {
      debugPrint('🚫 DuelWaitingRoom - Exit confirm dialog iptal edildi, widget mounted değil');
      return false;
    }
    
    try {
      return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: const Color(0xFF2A2A2A),
            title: const Text(
              '🚪 Eşleşmeden Çık',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Eşleşmeden çıkmak istediğinizden emin misiniz?\nRakip arama iptal olacak!',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  try {
                    if (Navigator.canPop(dialogContext)) {
                      Navigator.of(dialogContext).pop(false);
                    }
                  } catch (e) {
                    debugPrint('❌ Exit confirm cancel error: $e');
                  }
                },
                child: const Text(
                  'İptal',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () {
                  try {
                    if (Navigator.canPop(dialogContext)) {
                      Navigator.of(dialogContext).pop(true);
                    }
                  } catch (e) {
                    debugPrint('❌ Exit confirm accept error: $e');
                  }
                },
                child: const Text(
                  'Çık',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          );
        },
      ) ?? false;
    } catch (e) {
      debugPrint('❌ Exit confirm dialog error: $e');
      return false;
    }
  }

  void _showExitDialog() {
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
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                'Aramayı İptal Et?',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          content: const Text(
            'Eğer şimdi çıkarsan, rakip arama iptal olacak. Emin misin?',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Vazgeç',
                style: TextStyle(color: Colors.blue),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                // Dialog'u kapat
                Navigator.of(context).pop();
                
                // Asenkron işlem sonrası widget hala aktif mi kontrol et
                if (!mounted || !context.mounted) {
                  debugPrint('🚫 DuelWaitingRoom - Widget mounted değil, exit işlemi iptal edildi');
                  return;
                }
                
                try {
                  final viewModel = Provider.of<DuelViewModel>(context, listen: false);
                  await viewModel.leaveGame();
                  
                  // Bekleme odasından çık ve DuelPage'e dön (oradan ana sayfaya gidecek)
                  if (mounted && context.mounted && Navigator.canPop(context)) {
                    Navigator.of(context).pop(false); // Oyun başlamadı sinyali
                  }
                } catch (e) {
                  debugPrint('❌ DuelWaitingRoom - Exit game error: $e');
                  // Hata durumunda da çıkış yap
                  try {
                    if (mounted && context.mounted && Navigator.canPop(context)) {
                      Navigator.of(context).pop(false);
                    }
                  } catch (navError) {
                    debugPrint('❌ DuelWaitingRoom - Navigation error: $navError');
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Çık',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldExit = await _showExitConfirmDialog();
        if (shouldExit && mounted && Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Consumer<DuelViewModel>(
          builder: (context, viewModel, child) {
            final gameState = viewModel.gameState;
            final game = viewModel.currentGame;
            
            debugPrint('🏠 DuelWaitingRoom build - GameState: $gameState, PlayerCount: ${game?.players.length ?? 0}');
            
            // Timeout durumunu kontrol et
            if (_hasTimedOut && (gameState == GameState.searching || gameState == GameState.initializing)) {
              debugPrint('⏰ DuelWaitingRoom - Timeout state gösteriliyor');
              return _buildTimeoutState();
            }
            
            // Game State'e göre UI render et
            switch (gameState) {
              case GameState.initializing:
                debugPrint('🔄 DuelWaitingRoom - Initializing state');
                return _buildLoadingState();
                
              case GameState.searching:
              case GameState.waitingRoom:
                debugPrint('🔍 DuelWaitingRoom - Searching/Waiting state, game: ${game != null}');
                return _buildWaitingRoom(context, game, viewModel);
                
              case GameState.opponentFound:
                debugPrint('🎯 === OPPONENT FOUND STATE RENDER EDİLİYOR ===');
                debugPrint('🎯 OpponentFound: ${viewModel.opponentFound}');
                debugPrint('🎯 PreGameCountdown: ${viewModel.preGameCountdown}');
                debugPrint('🎯 CurrentPlayer: ${viewModel.currentPlayer?.playerName}');
                debugPrint('🎯 OpponentPlayer: ${viewModel.opponentPlayer?.playerName}');
                return _buildOpponentFoundState(viewModel);
                
              case GameState.gameStarting:
                // Oyun başlıyor, DuelPage'e git
                if (!_hasNavigated) {
                  debugPrint('🚀 DuelWaitingRoom - Oyun başlıyor, DuelPage\'e gidiliyor');
                  _hasNavigated = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const DuelPage()),
                      );
                    }
                  });
                }
                return _buildGameStartingState();
                
              case GameState.playing:
                // Oyun çoktan başlamış, DuelPage'e git
                if (!_hasNavigated) {
                  debugPrint('🎮 DuelWaitingRoom - Oyun çoktan başlamış, DuelPage\'e gidiliyor');
                  _hasNavigated = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const DuelPage()),
                      );
                    }
                  });
                }
                return _buildGameStartingState();
                
              default:
                return _buildLoadingState();
            }
          },
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _getCurrentUserInfo() async {
    final user = FirebaseService.getCurrentUser();
    if (user == null) {
      return {'name': 'Sen', 'avatar': '👤'};
    }
    
    try {
      final userProfile = await FirebaseService.getUserProfile(user.uid);
      
      // Avatar'ı Realtime Database'den al
      final avatarData = await FirebaseService.getDatabase()
          .ref('users/${user.uid}/avatar')
          .get();
      final avatar = avatarData.value as String? ?? '👤';
      
      return {
        'name': userProfile?['displayName'] ?? user.displayName ?? 'Sen',
        'avatar': avatar,
      };
    } catch (e) {
      debugPrint('❌ Kullanıcı bilgileri alınamadı: $e');
      return {'name': 'Sen', 'avatar': '👤'};
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ana logo/icon
          AnimatedBuilder(
            animation: _rotationAnimation,
            builder: (context, child) {
              final scaleValue = (0.8 + 0.2 * math.sin(math.pi * _rotationAnimation.value * 0.5));
              return Transform.scale(
                scale: scaleValue,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade400,
                        Colors.purple.shade400,
                        Colors.pink.shade400,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.sports_esports,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 40),
          
          // Başlık
          const Text(
            'Düello Aranıyor',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 12),
          
          Text(
            'Sana uygun rakip arıyoruz...',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 16,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Loading indicator
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: Colors.blue,
              strokeWidth: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeoutState() {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.people_outline,
              color: Colors.orange,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Rakip Bulunamadı',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Column(
                children: [
                  Text(
                    'Şu anda online rakip yok',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Daha sonra tekrar deneyin\n• Arkadaşlarınızı davet edin\n• Diğer oyun modlarını deneyin',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Tekrar dene
                    setState(() {
                      _hasStartedGame = false;
                      _hasTimedOut = false;
                    });
                    _startGame();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, size: 18),
                      SizedBox(width: 8),
                      Text('Tekrar Dene'),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.home, size: 18),
                      SizedBox(width: 8),
                      Text('Ana Sayfa'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameStartingState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade800, Colors.green.shade600],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_circle_filled,
              color: Colors.white,
              size: 80,
            ),
            SizedBox(height: 20),
            Text(
              'Oyun Başlıyor!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Hazır ol...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingRoom(BuildContext context, DuelGame? game, DuelViewModel viewModel) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF0D0F14),
              const Color(0xFF1A1A2E),
              const Color(0xFF16213E),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Başlık
                _buildSimpleHeader(),
                
                const SizedBox(height: 40),
                
                // VS Bölümü
                Expanded(
                  child: _buildVSSection(game, viewModel),
                ),
                
                const SizedBox(height: 40),
                
                // Token Bilgisi
                _buildTokenInfo(),
                
                const SizedBox(height: 20),
                
                            // Test ve Çıkış Butonları
            _buildFooter(viewModel),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: _CyberGridPainter(_rotationAnimation.value),
          child: Container(),
        );
      },
    );
  }

  Widget _buildSimpleHeader() {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        final glowIntensity = 0.5 + (math.sin(_rotationAnimation.value * math.pi * 3) * 0.2);
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  colors: [
                    Colors.purple.shade800,
                    Colors.blue.shade700,
                    Colors.purple.shade800,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(glowIntensity),
                    blurRadius: 20,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: const Text(
                '⚔️ DÜELLO ODASI',
                style: TextStyle(
                  fontSize: 26,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 4,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Rakip aranıyor...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade300,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVSSection(DuelGame? game, DuelViewModel viewModel) {
    final opponentPlayer = viewModel.opponentPlayer;
    final hasOpponent = opponentPlayer != null;
    
    return Center(
      child: Row(
        children: [
          // Sol Oyuncu (Sen) - Direkt bilgiler
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _getCurrentUserInfo(),
              builder: (context, snapshot) {
                final userInfo = snapshot.data;
                return _buildPlayerCard(
                  userInfo?['name'] ?? 'Sen',
                  userInfo?['avatar'] ?? '👤',
                  Colors.blue,
                  isCurrentPlayer: true,
                );
              },
            ),
          ),
          
          // Ortada VS - Gelişmiş animasyon
          Container(
            width: 100,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _rotationAnimation,
                  builder: (context, child) {
                    final pulseScale = 1.0 + (math.sin(_rotationAnimation.value * math.pi * 4) * 0.1);
                    final glowIntensity = 0.6 + (math.sin(_rotationAnimation.value * math.pi * 5) * 0.3);
                    
                    return Transform.scale(
                      scale: pulseScale,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.yellow.shade400,
                              Colors.orange.shade600,
                              Colors.red.shade800,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(glowIntensity),
                              blurRadius: 25,
                              spreadRadius: 8,
                            ),
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 40,
                              spreadRadius: 12,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'VS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 4,
                                  offset: Offset(2, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                if (!hasOpponent)
                  AnimatedBuilder(
                    animation: _rotationAnimation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _rotationAnimation.value * math.pi * 2,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange.shade400,
                                Colors.red.shade600,
                              ],
                            ),
                          ),
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        ),
                      );
                    },
                  ),
                // 🕐 BEKLEME ODASINDA GERİ SAYIM
                if (!hasOpponent) ...[
                  const SizedBox(height: 30),
                  _buildWaitingCountdown(),
                ],
              ],
            ),
          ),
          
          // Sağ Oyuncu (Rakip)
          Expanded(
            child: hasOpponent
                ? _buildPlayerCard(
                    opponentPlayer.playerName,
                    opponentPlayer.avatar ?? '❓',
                    Colors.red,
                    isCurrentPlayer: false,
                  )
                : _buildSearchingCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(String name, String avatar, Color themeColor, {required bool isCurrentPlayer}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: themeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: themeColor.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: themeColor.withOpacity(0.2),
              border: Border.all(color: themeColor, width: 3),
            ),
            child: Center(
              child: Text(
                avatar,
                style: const TextStyle(fontSize: 50),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // İsim
          Text(
            name,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Etiket
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: themeColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isCurrentPlayer ? 'SEN' : 'RAKİP',
              style: TextStyle(
                color: themeColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Arama ikonu
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.withOpacity(0.2),
              border: Border.all(color: Colors.grey, width: 3),
            ),
            child: const Center(
              child: Text(
                '🔍',
                style: TextStyle(fontSize: 50),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Aranıyor yazısı
          const Text(
            'RAKİP',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Durum
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'ARANIYOR',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTokenInfoItem('Giriş Ücreti', '2', Colors.red.shade400),
              _buildTokenInfoItem('Potansiyel Kazanç', '4', Colors.green.shade400),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.grey.shade800),
          const SizedBox(height: 8),
          FutureBuilder<int>(
            future: Provider.of<DuelViewModel>(context, listen: false).getCurrentUserTokens(),
            builder: (context, snapshot) {
              final tokens = snapshot.data ?? 0;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Mevcut Jetonun: ',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  Text(
                    tokens.toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTokenInfoItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.monetization_on, color: color, size: 20),
          ],
        ),
      ],
    );
  }

  Widget _buildFooter(DuelViewModel viewModel) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Test Rakip Butonu
        SizedBox(
          height: 50,
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              try {
                debugPrint('🤖 Test rakip oluşturuluyor...');
                final success = await viewModel.createTestOpponent();
                if (success && mounted) {
                  debugPrint('✅ Test rakip oluşturuldu, oyun başlıyor');
                  // Test modunda direkt oyun sayfasına git
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const DuelPage()),
                  );
                } else {
                  debugPrint('❌ Test rakip oluşturulamadı');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Test rakip oluşturulamadı'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } catch (e) {
                debugPrint('❌ Test rakip hatası: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Hata: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.smart_toy, color: Colors.white),
            label: const Text('🤖 Test Rakip Oluştur'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shadowColor: Colors.green.shade700,
              elevation: 8,
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Çıkış Butonu
        SizedBox(
          height: 50,
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _showExitDialog,
            icon: const Icon(Icons.cancel, color: Colors.white),
            label: const Text('Aramayı İptal Et'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade800.withOpacity(0.8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shadowColor: Colors.red.shade800,
              elevation: 8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayersCard(DuelGame game, DuelViewModel viewModel) {
    final currentPlayer = viewModel.currentPlayer;
    final opponentPlayer = viewModel.opponentPlayer;
    final screenWidth = MediaQuery.of(context).size.width;
    final finalOffset = screenWidth * 0.25; // Kartın merkezden son uzaklığı

    return AnimatedBuilder(
      animation: _collisionAnimation,
      builder: (context, child) {
        // Kartların başlangıç pozisyonu (ekran dışı) ve animasyonlu hareketi
        final startOffset = screenWidth / 2;
        final currentPosition = startOffset * (1 - _collisionAnimation.value);

        // VS logosunun animasyonu: Belirli bir anda parlayıp sönecek
        final vsAnimation = (_collisionAnimation.value > 0.4 && _collisionAnimation.value < 0.7)
            ? (1 - ((_collisionAnimation.value - 0.4) / 0.3 - 0.5).abs() * 2)
            : 0.0;

        return SizedBox(
          height: 250,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Oyuncu 1 (Soldan gelip sola yerleşir)
              Transform.translate(
                offset: Offset(-finalOffset - currentPosition, 0),
                child: _buildPlayerAvatar(currentPlayer, isOpponent: false),
              ),
              
              // Oyuncu 2 (Sağdan gelip sağa yerleşir)
              Transform.translate(
                offset: Offset(finalOffset + currentPosition, 0),
                child: _buildPlayerAvatar(opponentPlayer, isOpponent: true),
              ),

              // VS Ayırıcı (Animasyonlu)
              Transform.scale(
                scale: 1.0 + (vsAnimation * 0.5),
                child: Opacity(
                  opacity: vsAnimation,
                  child: _buildVsSeparator(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayerAvatar(DuelPlayer? player, {required bool isOpponent}) {
    final avatar = player?.avatar ?? (isOpponent ? '❓' : '🤔');
    final name = player?.playerName ?? (isOpponent ? 'Aranıyor...' : 'Sen');
    final bgColor = isOpponent ? Colors.red.shade900 : Colors.blue.shade900;
    
    return SizedBox(
      width: 140,
      height: 175,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: bgColor.withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: bgColor.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 2,
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [bgColor, Colors.black.withOpacity(0.1)],
                  center: Alignment.center,
                  radius: 0.8,
                ),
              ),
              child: Center(
                child: Text(
                  avatar,
                  style: const TextStyle(fontSize: 40),
                ),
              ),
            ),
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVsSeparator() {
    const double vsFontSize = 64;
    const fontFamily = 'RussoOne';

    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Katman 1: En dıştaki, bulanık alev parlaması
          Text(
            'VS',
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: vsFontSize,
              color: Colors.transparent,
              shadows: [
                for (int i = 1; i <= 4; i++)
                  Shadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: i * 12.0,
                  ),
              ],
            ),
          ),

          // Katman 2: İçteki, keskin şimşek parlaması
          Text(
            'VS',
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: vsFontSize,
              color: Colors.transparent,
              shadows: [
                Shadow(
                  color: Colors.yellowAccent.withOpacity(0.8),
                  blurRadius: 25,
                ),
                Shadow(
                  color: Colors.white.withOpacity(0.7),
                  blurRadius: 15,
                ),
              ],
            ),
          ),

          // Katman 3: Ana metnin kendisi (Ateşli renk geçişi)
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                Colors.yellow.shade300,
                Colors.orange.shade600,
                Colors.red.shade800
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(bounds),
            child: const Text(
              'VS',
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: vsFontSize,
                color: Colors.white, // Bu renk önemsiz, shader kullanılacak
              ),
            ),
          ),
          
          // Katman 4: Metne derinlik katan ince dış çizgi
          Text(
            'VS',
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: vsFontSize,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.5
                ..color = Colors.black.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpponentFoundState(DuelViewModel viewModel) {
    debugPrint('🎨 === OPPONENT FOUND STATE WIDGET OLUŞTURULUYOR ===');
    
    final game = viewModel.currentGame;
    final opponentPlayer = viewModel.opponentPlayer;
    
    debugPrint('🎨 Game: ${game != null}');
    debugPrint('🎨 OpponentPlayer: ${opponentPlayer?.playerName} (${opponentPlayer?.avatar})');
    debugPrint('🎨 Countdown: ${viewModel.preGameCountdown}');
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0F0F23),
            const Color(0xFF1A1A3E),
            const Color(0xFF2D1B69),
            const Color(0xFF8B5CF6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Arka plan efektleri
          _buildBackgroundEffects(),
          
          // Ana içerik
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Başlık animasyonu
                  _buildAnimatedTitle(),
                  
                  const SizedBox(height: 50),
                  
                  // Oyuncular karşılaştırması
                  _buildVersusSection(opponentPlayer),
                  
                  const SizedBox(height: 60),
                  
                  // Countdown
                  _buildCountdownCircle(viewModel.preGameCountdown),
                  
                  const SizedBox(height: 30),
                  
                  // Alt mesaj
                  _buildBottomMessage(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundEffects() {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            // Dönen halka efektleri
            Positioned(
              top: 100,
              left: -50,
              child: Transform.rotate(
                angle: _rotationAnimation.value * math.pi * 2,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.purple.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 150,
              right: -75,
              child: Transform.rotate(
                angle: -_rotationAnimation.value * math.pi * 1.5,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.15),
                      width: 3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnimatedTitle() {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        final scale = 1.0 + (math.sin(_rotationAnimation.value * math.pi * 4) * 0.05);
        return Transform.scale(
          scale: scale,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.shade600,
                      Colors.red.shade600,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Text(
                  '🎯 RAKİP BULUNDU!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Mücadele başlamak üzere...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVersusSection(DuelPlayer? opponentPlayer) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getCurrentUserInfo(),
      builder: (context, snapshot) {
        final userInfo = snapshot.data;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Sen
            _buildPlayerProfile(
              userInfo?['name'] ?? 'Sen',
              userInfo?['avatar'] ?? '👤',
              Colors.blue,
              true,
            ),
            
            // VS Efekti
            _buildVSEffect(),
            
            // Rakip
            _buildPlayerProfile(
              opponentPlayer?.playerName ?? 'Rakip',
              opponentPlayer?.avatar ?? '🤖',
              Colors.red,
              false,
            ),
          ],
        );
      },
    );
  }

  Widget _buildVSEffect() {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        final pulseScale = 1.0 + (math.sin(_rotationAnimation.value * math.pi * 6) * 0.1);
        return Transform.scale(
          scale: pulseScale,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.yellow.shade400,
                  Colors.orange.shade600,
                  Colors.red.shade700,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.8),
                  blurRadius: 25,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'VS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 4,
                      offset: Offset(2, 2),
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

  Widget _buildCountdownCircle(int countdown) {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: Colors.white,
              width: 4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '$countdown',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 56,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 8,
                    offset: Offset(3, 3),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomMessage() {
    return Column(
      children: [
        Text(
          'Hazır ol!',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'En iyi kelime tahminini yap ve rakibini yen!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerProfile(String name, String avatar, Color color, bool isCurrentPlayer) {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.2),
            border: Border.all(color: color, width: 3),
          ),
          child: Center(
            child: Text(
              avatar,
              style: const TextStyle(fontSize: 50),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          name,
          style: TextStyle(
            color: isCurrentPlayer ? Colors.white : Colors.white70,
            fontSize: 16,
            fontWeight: isCurrentPlayer ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        if (isCurrentPlayer)
          const Text(
            '(Sen)',
            style: TextStyle(
              color: Colors.blue,
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  // 🕐 BEKLEME ODASINDA GERİ SAYIM WİDGET'I
  Widget _buildWaitingCountdown() {
    return Column(
      children: [
        // Countdown circle
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.blue.withOpacity(0.3),
                Colors.purple.withOpacity(0.1),
              ],
            ),
            border: Border.all(
              color: Colors.blue.withOpacity(0.6),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '$_waitingCountdown',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Rakip aranıyor...',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          '${_waitingCountdown}s kaldı',
          style: TextStyle(
            color: Colors.blue.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

}

class _CyberGridPainter extends CustomPainter {
  final double rotation;
  _CyberGridPainter(this.rotation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.max(size.width, size.height) * 0.7;

    // Arka Plan Renkleri
    final backgroundPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xff1a237e).withOpacity(0.5), // Indigo
          const Color(0xff4a148c).withOpacity(0.3), // Purple
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Izgara
    final gridPaint = Paint()
      ..color = Colors.cyan.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final ringPaint = Paint()
      ..color = Colors.cyan.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation * math.pi / 12); // Daha yavaş dönüş
    canvas.translate(-center.dx, -center.dy);

    const gridSize = 40.0;
    for (double i = 0; i <= size.width + gridSize; i += gridSize) {
      canvas.drawLine(Offset(i, -gridSize), Offset(i, size.height + gridSize), gridPaint);
    }
    for (double i = 0; i <= size.height + gridSize; i += gridSize) {
      canvas.drawLine(Offset(-gridSize, i), Offset(size.width + gridSize, i), gridPaint);
    }
    
    canvas.drawCircle(center, radius * 0.25, ringPaint);
    canvas.drawCircle(center, radius * 0.5, ringPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}