import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import '../models/duel_game.dart';
import '../services/firebase_service.dart';
import 'duel_page.dart';

// Düello sonuç sayfası

class DuelResultPage extends StatefulWidget {
  final DuelGame game;
  final DuelPlayer currentPlayer;
  final DuelPlayer? opponentPlayer;
  final String playerName;
  final Duration gameDuration;

  const DuelResultPage({
    Key? key,
    required this.game,
    required this.currentPlayer,
    this.opponentPlayer,
    required this.playerName,
    required this.gameDuration,
  }) : super(key: key);

  @override
  State<DuelResultPage> createState() => _DuelResultPageState();
}

class _DuelResultPageState extends State<DuelResultPage> 
    with TickerProviderStateMixin {
  
  late AnimationController _confettiController;
  late AnimationController _mainAnimationController;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  
  List<ConfettiParticle> confettiParticles = [];
  bool _hasAnimated = false;
  int _tokensEarned = 0;
  int _tokensLost = 0;

  @override
  void initState() {
    super.initState();
    
    // Ana animasyon kontrolcüsü
    _mainAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    // Konfeti animasyonu - daha uzun süre
    _confettiController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    
    // Pulse animasyonu
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    // Slide animasyonu
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    // Animasyonları tanımla
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainAnimationController,
      curve: Curves.elasticOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainAnimationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    // Oyun sonucunu kaydet ve animasyonları başlat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _saveGameResult();
      _startAnimations();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _mainAnimationController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _startAnimations() {
    if (_hasAnimated || !mounted) return;
    _hasAnimated = true;
    
    final bool isWinner = widget.game.winnerId == widget.currentPlayer.playerId;
    final bool hasOpponent = widget.opponentPlayer != null;
    
    // Jeton hesapla - Basit sistem
    if (isWinner && hasOpponent) {
      _tokensEarned = 20;
    } else if (!isWinner && hasOpponent) {
      _tokensLost = 20;
    }
    
    // Ana animasyonu başlat
    if (mounted) {
      _mainAnimationController.forward();
    }
    
    // Pulse animasyonunu sürekli çalıştır (sadece kazananda)
    if (isWinner && hasOpponent && mounted) {
      _pulseController.repeat(reverse: true);
      
      // Konfeti patlat
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _createAdvancedConfetti();
          _confettiController.forward();
        }
      });
    }
    
    // Alt paneli slide ile göster
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        _slideController.forward();
      }
    });
  }

  void _createAdvancedConfetti() {
    final random = math.Random();
    final screenCenter = MediaQuery.of(context).size.width / 2;
    final screenHeight = MediaQuery.of(context).size.height;
    
    confettiParticles = List.generate(80, (index) {
      // Merkezi patlatma efekti için açı hesapla
      final angle = (index / 80) * 2 * math.pi;
      final speed = random.nextDouble() * 8 + 4;
      final distance = random.nextDouble() * 300 + 100;
      
      return ConfettiParticle(
        x: screenCenter + math.cos(angle) * 50, // Merkezden başla
        y: screenHeight * 0.3, // Ekranın üst kısmından
        color: [
          Colors.yellow.shade400,
          Colors.orange.shade400,
          Colors.red.shade400,
          Colors.pink.shade400,
          Colors.purple.shade400,
          Colors.blue.shade400,
          Colors.green.shade400,
          Colors.cyan.shade400,
        ][random.nextInt(8)],
        size: random.nextDouble() * 12 + 6,
        speedX: math.cos(angle) * speed,
        speedY: -random.nextDouble() * 8 - 2, // Yukarı doğru patlama
        rotation: random.nextDouble() * 2 * math.pi,
        rotationSpeed: (random.nextDouble() - 0.5) * 0.3,
        gravity: random.nextDouble() * 0.3 + 0.1,
        life: 1.0,
        fadeSpeed: random.nextDouble() * 0.02 + 0.01,
      );
    });
  }

  Future<void> _saveGameResult() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final bool isWinner = widget.game.winnerId == widget.currentPlayer.playerId;
      final bool hasOpponent = widget.opponentPlayer != null;
      
      // Skor hesapla - Basit sistem: Kazanan +20, Kaybeden -20
      int score = 0;
      if (isWinner && hasOpponent) {
        score = 20; // Kazanan 20 puan alır
      } else if (!isWinner && hasOpponent) {
        score = -20; // Kaybeden 20 puan kaybeder
      } else {
        score = 0; // Rakip yoksa puan değişmez
      }

      // Firebase'e kaydet
      await FirebaseService.saveGameResult(
        uid: user.uid,
        gameType: 'Duello',
        score: score,
        isWon: isWinner && hasOpponent,
        duration: widget.gameDuration,
        additionalData: {
          'attempts': widget.currentPlayer.currentAttempt + 1,
          'hasOpponent': hasOpponent,
          'opponentName': widget.opponentPlayer?.playerName ?? 'Ayrıldı',
          'secretWord': widget.game.secretWord,
          'gameId': widget.game.gameId,
          'tokensEarned': _tokensEarned,
          'tokensLost': _tokensLost,
        },
      );

      // Puan ve jeton güncellemesi
      if (_tokensEarned > 0) {
        await FirebaseService.updateUserStats(user.uid, {
          'tokens': FieldValue.increment(_tokensEarned),
          'points': FieldValue.increment(20), // Kazanan 20 puan alır
        });
      } else if (_tokensLost > 0) {
        await FirebaseService.updateUserStats(user.uid, {
          'tokens': FieldValue.increment(-_tokensLost),
          'points': FieldValue.increment(-20), // Kaybeden 20 puan kaybeder
        });
      }

      await FirebaseService.updateUserLevel(user.uid);
      debugPrint('Duello sonucu kaydedildi: Score=$score, Won=$isWinner, Tokens=${_tokensEarned - _tokensLost}');
    } catch (e) {
      debugPrint('Duello sonucu kaydetme hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWinner = widget.game.winnerId == widget.currentPlayer.playerId;
    final bool hasOpponent = widget.opponentPlayer != null;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: _getBackgroundGradient(isWinner, hasOpponent),
        ),
        child: Stack(
          children: [
            // Arka plan partikülleri
            ...List.generate(20, (index) => _buildBackgroundParticle(index)),
            
            // Ana içerik
            SafeArea(
              child: Column(
                children: [
                  // Üst header
                  _buildHeader(),
                  
                  // Ana sonuç alanı
                  Expanded(
                    flex: 3,
                    child: _buildMainResult(isWinner, hasOpponent),
                  ),
                  
                  // Alt panel
                  _buildBottomPanel(isWinner, hasOpponent),
                ],
              ),
            ),
            
            // Konfeti animasyonu - tam ekran
            if (confettiParticles.isNotEmpty)
              AnimatedBuilder(
                animation: _confettiController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: AdvancedConfettiPainter(
                      particles: confettiParticles,
                      progress: _confettiController.value,
                    ),
                    size: Size.infinite,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundParticle(int index) {
    final random = math.Random(index);
    return Positioned(
      left: random.nextDouble() * MediaQuery.of(context).size.width,
      top: random.nextDouble() * MediaQuery.of(context).size.height,
      child: AnimatedBuilder(
        animation: _mainAnimationController,
        builder: (context, child) {
          return Opacity(
            opacity: 0.1 * _fadeAnimation.value,
            child: Container(
              width: random.nextDouble() * 4 + 2,
              height: random.nextDouble() * 4 + 2,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          );
        },
      ),
    );
  }

  LinearGradient _getBackgroundGradient(bool isWinner, bool hasOpponent) {
    if (!hasOpponent) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF1A1A2E),
          const Color(0xFF16213E),
          const Color(0xFF0F4C75),
        ],
      );
    } else if (isWinner) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF00F260),
          const Color(0xFF0575E6),
          const Color(0xFF021B79),
        ],
      );
    } else {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFFF416C),
          const Color(0xFFFF4B2B),
          const Color(0xFF1A1A2E),
        ],
      );
    }
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildHeaderButton(
            icon: Icons.home_rounded,
            onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
          AnimatedBuilder(
            animation: _fadeAnimation,
            child: const Text(
              'DÜELLO SONUCU',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: child,
              );
            },
          ),
          _buildHeaderButton(
            icon: Icons.refresh_rounded,
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const DuelPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildMainResult(bool isWinner, bool hasOpponent) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ana ikon ve sonuç
            _buildResultIcon(isWinner, hasOpponent),
            
            const SizedBox(height: 24),
            
            // Ana mesaj
            _buildResultMessage(isWinner, hasOpponent),
            
            const SizedBox(height: 20),
            
            // Gizli kelime
            if (widget.game.secretWord.isNotEmpty)
              _buildSecretWordCard(),
            
            const SizedBox(height: 16),
            
            // İstatistikler
            _buildStatsRow(),
          ],
        ),
      ),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildResultIcon(bool isWinner, bool hasOpponent) {
    String emoji;
    IconData icon;
    Color iconColor;
    
    if (!hasOpponent) {
      emoji = '🚫';
      icon = Icons.person_off_rounded;
      iconColor = Colors.orange;
    } else if (isWinner) {
      emoji = '🏆';
      icon = Icons.emoji_events_rounded;
      iconColor = Colors.amber;
    } else {
      emoji = '💔';
      icon = Icons.sentiment_dissatisfied_rounded;
      iconColor = Colors.red.shade300;
    }
    
    Widget iconWidget = Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withOpacity(0.3),
            Colors.white.withOpacity(0.1),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 36),
          ),
          const SizedBox(height: 4),
          Icon(
            icon,
            color: iconColor,
            size: 32,
          ),
        ],
      ),
    );
    
    // Kazananda pulse efekti
    if (isWinner && hasOpponent) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        child: iconWidget,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: child,
          );
        },
      );
    }
    
    return iconWidget;
  }

  Widget _buildResultMessage(bool isWinner, bool hasOpponent) {
    String title;
    String subtitle;
    
    if (!hasOpponent) {
      title = 'RAKIP AYRILD!';
      subtitle = 'Oyun iptal edildi';
    } else if (isWinner) {
      title = 'MÜTHIŞ!';
      subtitle = 'Sen kazandın! 🎉';
    } else {
      title = 'İYİ MÜCADELE!';
      subtitle = 'Rakibin bu sefer daha şanslıydı';
    }
    
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSecretWordCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'GİZLİ KELİME',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.game.secretWord,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatCard(
          '⏱️',
          _formatDuration(widget.gameDuration),
          'SÜRE',
        ),
        _buildStatCard(
          '🎯',
          '${widget.currentPlayer.currentAttempt + 1}/6',
          'TAHMİN',
        ),
        if (widget.opponentPlayer != null)
          _buildStatCard(
            '⚔️',
            '${widget.opponentPlayer!.currentAttempt + 1}/6',
            'RAKİP',
          ),
      ],
    );
  }

  Widget _buildStatCard(String emoji, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(bool isWinner, bool hasOpponent) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Oyuncu karşılaştırması
            _buildPlayerVS(),
            
            const SizedBox(height: 16),
            
            // Jeton bilgisi
            if (_tokensEarned > 0 || _tokensLost > 0)
              _buildTokenCard(),
            
            if (_tokensEarned > 0 || _tokensLost > 0)
              const SizedBox(height: 16),
            
            // Aksiyon butonları
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerVS() {
    return Row(
      children: [
        // Mevcut oyuncu
        Expanded(
          child: _buildPlayerMiniCard(
            name: widget.playerName,
            attempts: widget.currentPlayer.currentAttempt,
            isWinner: widget.game.winnerId == widget.currentPlayer.playerId,
            isCurrentPlayer: true,
          ),
        ),
        
        const SizedBox(width: 16),
        
        // VS
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: const Text(
            'VS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Rakip oyuncu
        Expanded(
          child: _buildPlayerMiniCard(
            name: widget.opponentPlayer?.playerName ?? 'Ayrıldı',
            attempts: widget.opponentPlayer?.currentAttempt ?? -1,
            isWinner: widget.game.winnerId == widget.opponentPlayer?.playerId,
            isCurrentPlayer: false,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerMiniCard({
    required String name,
    required int attempts,
    required bool isWinner,
    required bool isCurrentPlayer,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentPlayer 
          ? Colors.blue.withOpacity(0.2)
          : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: isWinner 
          ? Border.all(color: Colors.amber, width: 2)
          : Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isCurrentPlayer 
                  ? [Colors.blue.shade400, Colors.blue.shade600]
                  : [Colors.grey.shade600, Colors.grey.shade800],
              ),
            ),
            child: Icon(
              isCurrentPlayer ? Icons.person_rounded : Icons.person_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // İsim
          Text(
            name,
            style: TextStyle(
              color: isCurrentPlayer ? Colors.blue.shade200 : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 4),
          
          // Sonuç
          Text(
            attempts >= 6 ? 'X' : '${attempts + 1}/6',
            style: TextStyle(
              color: isWinner ? Colors.amber : Colors.grey.shade300,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          
          // Kazanma durumu
          if (isWinner)
            const Text(
              '👑',
              style: TextStyle(fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildTokenCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _tokensEarned > 0 
            ? [Colors.amber.shade600, Colors.orange.shade600]
            : [Colors.red.shade600, Colors.red.shade800],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (_tokensEarned > 0 ? Colors.amber : Colors.red).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _tokensEarned > 0 ? Icons.add_circle_rounded : Icons.remove_circle_rounded,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            '🪙 ${_tokensEarned > 0 ? '+$_tokensEarned' : '-$_tokensLost'} JETON',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            'ANA SAYFA',
            Icons.home_rounded,
            Colors.blue.shade600,
            () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            'TEKRAR OYNA',
            Icons.refresh_rounded,
            Colors.green.shade600,
            () {
              // Yeni DuelPage instance'ı ile temiz başlangıç
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const DuelPage(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String text, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}

// Gelişmiş konfeti parçacığı
class ConfettiParticle {
  double x;
  double y;
  final Color color;
  final double size;
  double speedX;
  double speedY;
  double rotation;
  final double rotationSpeed;
  final double gravity;
  double life;
  final double fadeSpeed;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.color,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.rotation,
    required this.rotationSpeed,
    required this.gravity,
    required this.life,
    required this.fadeSpeed,
  });

  void update() {
    x += speedX;
    y += speedY;
    speedY += gravity; // Yerçekimi etkisi
    rotation += rotationSpeed;
    life -= fadeSpeed;
    
    // Hava direnci
    speedX *= 0.995;
    speedY *= 0.995;
  }
}

// Gelişmiş konfeti çizici
class AdvancedConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;
  final double progress;

  AdvancedConfettiPainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      particle.update();
      
      // Yaşam süresi bittiyse atla
      if (particle.life <= 0) continue;
      
      final paint = Paint()
        ..color = particle.color.withOpacity(particle.life.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(particle.x, particle.y);
      canvas.rotate(particle.rotation);
      
      // Farklı şekillerde konfeti
      if (particle.size > 8) {
        // Büyük parçacıklar için yıldız şekli
        _drawStar(canvas, paint, particle.size);
      } else {
        // Küçük parçacıklar için kare
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: particle.size,
            height: particle.size,
          ),
          paint,
        );
      }
      
      canvas.restore();
    }
  }

  void _drawStar(Canvas canvas, Paint paint, double size) {
    final path = Path();
    const double angleStep = math.pi / 5;
    
    for (int i = 0; i < 10; i++) {
      final double angle = i * angleStep;
      final double radius = (i % 2 == 0) ? size : size * 0.5;
      final double x = radius * math.cos(angle);
      final double y = radius * math.sin(angle);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 