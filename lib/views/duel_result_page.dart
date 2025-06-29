import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import 'dart:math' as math;
import '../models/duel_game.dart';
import '../services/firebase_service.dart';
import '../viewmodels/duel_viewmodel.dart';
import 'duel_page.dart';
import 'duel_waiting_room.dart';

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
  
  // 🎊 KONFETI CONTROLLER - Profesyonel paket
  late ConfettiController _confettiController;
  
  late AnimationController _mainAnimationController;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  
  bool _hasAnimated = false;
  int _tokensEarned = 0;
  int _tokensLost = 0;

  @override
  void initState() {
    super.initState();
    
    // 🎊 KONFETI CONTROLLER - Hızlı ve etkili
    _confettiController = ConfettiController(duration: const Duration(seconds: 4));
    
    debugPrint('🎊 ConfettiController oluşturuldu: $_confettiController');
    
    // Ana animasyon kontrolcüsü
    _mainAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
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
    _confettiController.stop();
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
    
    debugPrint('🎊 DuelResult _startAnimations - isWinner: $isWinner, hasOpponent: $hasOpponent');
    
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
    
    // 🎊 KONFETI İÇİN GENİŞLETİLMİŞ KOŞUL - Test modu dahil
    if (isWinner && mounted) { // hasOpponent koşulunu kaldırdık
      debugPrint('🎉 KAZANDIN! Konfeti başlatılıyor HEMEN!');
      _pulseController.repeat(reverse: true);
      
      // 🎊 PROFESYONEL KONFETI PAKETI - 1 saniye gecikme ile
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          debugPrint('🎊 ✅ 1 saniye sonra konfeti başlatılıyor!');
          _confettiController.play();
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
            
                        // 🎊 BASIT ÜSTTEN KONFETI - GARANTİLİ ÇALIŞIR
            if (isWinner)
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirection: math.pi / 2, // Aşağı doğru
                  maxBlastForce: 20,
                  minBlastForce: 5,
                  emissionFrequency: 0.05,
                  numberOfParticles: 20,
                  gravity: 0.2,
                  shouldLoop: false,
                  colors: const [
                    Colors.yellow,
                    Colors.orange,
                    Colors.red,
                    Colors.blue,
                    Colors.green,
                  ],
                ),
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
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: AnimatedBuilder(
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
        ),
      ),
    );
  }

  Widget _buildResultIcon(bool isWinner, bool hasOpponent) {
    double iconSize = 120;
    
    if (isWinner) {
      // 🏆 KAZANMA ANİMASYONU + GIF
      return Container(
        width: iconSize + 40,
        height: iconSize + 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.yellow.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: ClipOval(
                child: Image.asset(
                  'assets/winner/Animation - 1751114693941.gif',
                  width: iconSize,
                  height: iconSize,
                  fit: BoxFit.cover,
                  gaplessPlayback: true, // Kesintisiz oynatma
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('❌ Winner gif yüklenemedi: $error');
                    // Hata durumunda fallback ikon
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🏆', style: TextStyle(fontSize: 36)),
                        const SizedBox(height: 4),
                        Icon(
                          Icons.emoji_events_rounded,
                          color: Colors.amber,
                          size: 32,
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      );
    } else {
      // 💔 KAYBETME VEYA RAKİP YOK ANİMASYONU + GIF
      IconData iconData;
    Color iconColor;
      String? gifPath;
      String emoji;
    
    if (!hasOpponent) {
      emoji = '🚫';
        iconData = Icons.person_off_rounded;
      iconColor = Colors.orange;
        gifPath = 'assets/alert/Animation - 1751119517404.gif';
    } else {
      emoji = '💔';
        iconData = Icons.sentiment_dissatisfied_rounded;
      iconColor = Colors.red.shade300;
        gifPath = 'assets/lose/Animation - 1751114981463.gif';
      }

      return Container(
        width: iconSize + 40,
        height: iconSize + 40,
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 3),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
        child: ClipOval(
          child: Image.asset(
            gifPath,
            width: iconSize,
            height: iconSize,
            fit: BoxFit.cover,
            gaplessPlayback: true, // Kesintisiz oynatma
            errorBuilder: (context, error, stackTrace) {
              debugPrint('❌ Lose/Alert gif yüklenemedi: $error');
              // Hata durumunda fallback ikon
              return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
                  Text(emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(height: 4),
          Icon(
                    iconData,
            color: iconColor,
            size: 32,
          ),
        ],
          );
        },
          ),
        ),
      );
    }
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
    final bool isWinner = widget.game.winnerId == widget.currentPlayer.playerId;
    
    return Column(
      children: [
        // 🎊 TEST BUTONU - Sadece kazanma durumunda
        if (isWinner)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildActionButton(
              'KONFETİ TEST',
              Icons.celebration_rounded,
              Colors.purple.shade600,
              () {
                debugPrint('🎊 TEST BUTONU TIKLANDI!');
                _confettiController.play();
                debugPrint('🎊 Konfeti play() çağırıldı');
              },
            ),
          ),
        
        // Ana butonlar
        Row(
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
                  try {
                    // DuelViewModel'ı reset et
                    final viewModel = Provider.of<DuelViewModel>(context, listen: false);
                    viewModel.resetForNewGame();
                    
                    debugPrint('🔄 DuelResultPage - ViewModel reset edildi, yeni oyun başlatılıyor');
                    
                    // DuelWaitingRoom'a git (yeni oyun için)
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                        builder: (context) => const DuelWaitingRoom(),
                      ),
                    );
                  } catch (e) {
                    debugPrint('❌ Tekrar oyna hatası: $e');
                    // Hata durumunda basit çözüm
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const DuelWaitingRoom(),
                    ),
                  );
                  }
                },
              ),
            ),
          ],
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

 