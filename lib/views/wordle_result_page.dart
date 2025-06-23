import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:math' as math;
import '../viewmodels/wordle_viewmodel.dart';

class WordleResultPage extends StatefulWidget {
  final bool isWinner;
  final bool isTimeOut;
  final String secretWord;
  final int attempts;
  final int timeSpent;
  final GameMode gameMode;
  final int currentLevel;
  final int maxLevel;
  final String shareText;
  final int tokensEarned;
  final int score;

  const WordleResultPage({
    Key? key,
    required this.isWinner,
    required this.isTimeOut,
    required this.secretWord,
    required this.attempts,
    required this.timeSpent,
    required this.gameMode,
    required this.currentLevel,
    required this.maxLevel,
    required this.shareText,
    this.tokensEarned = 0,
    this.score = 0,
  }) : super(key: key);

  @override
  State<WordleResultPage> createState() => _WordleResultPageState();
}

class _WordleResultPageState extends State<WordleResultPage>
    with TickerProviderStateMixin {
  late AnimationController _confettiController;
  late AnimationController _mainAnimationController;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late AnimationController _bounceController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _bounceAnimation;

  List<ConfettiParticle> confettiParticles = [];
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();

    // Ana animasyon kontrolcüsü
    _mainAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Konfeti animasyonu
    _confettiController = AnimationController(
      duration: const Duration(seconds: 5),
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

    // Bounce animasyonu
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 600),
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

    _bounceAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.bounceOut,
    ));

    // Animasyonları başlat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAnimations();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _mainAnimationController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  void _startAnimations() {
    if (_hasAnimated || !mounted) return;
    _hasAnimated = true;

    // Ana animasyonu başlat
    _mainAnimationController.forward();

    // Kazanırsa konfeti ve pulse animasyonları
    if (widget.isWinner && mounted) {
      _pulseController.repeat(reverse: true);

      // Konfeti oluştur ve başlat
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _createConfetti();
          _confettiController.forward();
        }
      });

      // Bounce animasyonu
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _bounceController.forward();
        }
      });
    }

    // Alt panel slide animasyonu
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        _slideController.forward();
      }
    });
  }

  void _createConfetti() {
    final random = math.Random();
    confettiParticles.clear();

    // 100'den fazla konfeti parçacığı oluştur
    for (int i = 0; i < 150; i++) {
      confettiParticles.add(ConfettiParticle(
        x: random.nextDouble(),
        y: -0.1,
        velocityX: (random.nextDouble() - 0.5) * 2,
        velocityY: random.nextDouble() * 2 + 1,
        color: _getRandomColor(random),
        size: random.nextDouble() * 8 + 4,
        rotation: random.nextDouble() * 2 * math.pi,
        rotationSpeed: (random.nextDouble() - 0.5) * 6,
      ));
    }
  }

  Color _getRandomColor(math.Random random) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.cyan,
      Colors.amber,
      Colors.lime,
    ];
    return colors[random.nextInt(colors.length)];
  }

  LinearGradient _getBackgroundGradient() {
    if (widget.isTimeOut) {
      return const LinearGradient(
        colors: [Color(0xFF2C1810), Color(0xFF8B4513)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    } else if (widget.isWinner) {
      return const LinearGradient(
        colors: [Color(0xFF1A5F1A), Color(0xFF2E8B57)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    } else {
      return const LinearGradient(
        colors: [Color(0xFF8B1538), Color(0xFFDC143C)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: _getBackgroundGradient()),
        child: Stack(
          children: [
            // Arka plan partikülleri
            ...List.generate(30, (index) => _buildBackgroundParticle(index)),

            // Ana içerik
            SafeArea(
              child: Column(
                children: [
                  // Üst boşluk
                  const SizedBox(height: 20),

                  // Ana sonuç alanı
                  Expanded(
                    flex: 3,
                    child: _buildMainResult(),
                  ),

                  // Alt panel
                  _buildBottomPanel(),
                ],
              ),
            ),

            // Konfeti animasyonu
            if (confettiParticles.isNotEmpty && widget.isWinner)
              AnimatedBuilder(
                animation: _confettiController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: ConfettiPainter(
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
      left: random.nextDouble() * 400,
      top: random.nextDouble() * 800,
      child: AnimatedBuilder(
        animation: _mainAnimationController,
        builder: (context, child) {
          return Opacity(
            opacity: 0.1 * _fadeAnimation.value,
            child: Transform.rotate(
              angle: _mainAnimationController.value * 2 * math.pi + index,
              child: Container(
                width: random.nextDouble() * 6 + 2,
                height: random.nextDouble() * 6 + 2,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainResult() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ana ikon ve başlık
            AnimatedBuilder(
              animation: widget.isWinner ? _pulseAnimation : _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: widget.isWinner ? _pulseAnimation.value : 1.0,
                  child: _buildMainIcon(),
                );
              },
            ),

            const SizedBox(height: 20),

            // Ana başlık
            if (widget.isWinner)
              ScaleTransition(
                scale: _bounceAnimation,
                child: _buildWinnerTitle(),
              )
            else
              _buildLoserTitle(),

            const SizedBox(height: 15),

            // Gizli kelime
            _buildSecretWord(),

            const SizedBox(height: 20),

            // İstatistikler
            _buildStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildMainIcon() {
    IconData iconData;
    Color iconColor;
    double iconSize = 100;

    if (widget.isTimeOut) {
      iconData = Icons.access_time;
      iconColor = Colors.orange;
    } else if (widget.isWinner) {
      iconData = Icons.celebration;
      iconColor = Colors.yellow;
      iconSize = 120;
    } else {
      iconData = Icons.sentiment_dissatisfied;
      iconColor = Colors.red.shade300;
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
      child: Icon(
        iconData,
        size: iconSize,
        color: iconColor,
      ),
    );
  }

  Widget _buildWinnerTitle() {
    String titleText;
    if (widget.gameMode == GameMode.challenge && widget.currentLevel == widget.maxLevel) {
      titleText = 'Maksimum Seviye!';
    } else if (widget.gameMode == GameMode.challenge) {
      titleText = 'Seviye Geçtiniz!';
    } else {
      titleText = 'Tebrikler!';
    }

    return Column(
      children: [
        Text(
          titleText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(2, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        if (widget.gameMode == GameMode.daily)
          const Text(
            'Günlük kelimeyi doğru bildiniz!',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  Widget _buildLoserTitle() {
    String titleText = widget.isTimeOut ? 'Süre Doldu!' : 'Kaybettiniz!';

    return Text(
      titleText,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.w800,
        shadows: [
          Shadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(2, 2),
          ),
        ],
      ),
    );
  }

  Widget _buildSecretWord() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(25),
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
          const Text(
            'Doğru Kelime',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.secretWord,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Deneme', '${widget.attempts}/6'),
              _buildStatItem('Süre', _formatTime(widget.timeSpent)),
              if (widget.score > 0) _buildStatItem('Puan', '${widget.score}'),
            ],
          ),
          if (widget.tokensEarned > 0) ...[
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.amber, Colors.orange],
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monetization_on, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '+${widget.tokensEarned} JETON',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (widget.gameMode == GameMode.challenge) ...[
            const SizedBox(height: 10),
            Text(
              'Seviye: ${widget.currentLevel} / ${widget.maxLevel}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomPanel() {
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
            // Aksiyon butonları
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Üst sıra butonlar
        Row(
          children: [
            if (widget.isWinner && widget.gameMode == GameMode.daily) ...[
              Expanded(
                child: _buildActionButton(
                  'Paylaş',
                  Icons.share,
                  Colors.blue,
                  () => Share.share(widget.shareText),
                ),
              ),
              const SizedBox(width: 10),
            ],
            if (widget.isWinner && widget.gameMode == GameMode.challenge && widget.currentLevel < widget.maxLevel) ...[
              Expanded(
                child: _buildActionButton(
                  'Devam',
                  Icons.arrow_forward,
                  Colors.green,
                  () => _goToNextLevel(),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: _buildActionButton(
                widget.isWinner && widget.gameMode == GameMode.challenge && widget.currentLevel == widget.maxLevel 
                  ? 'Tekrar Oyna' 
                  : 'Yeniden Başla',
                Icons.refresh,
                Colors.orange,
                () => _restartGame(),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 10),
        
        // Alt sıra buton
        SizedBox(
          width: double.infinity,
          child: _buildActionButton(
            'Ana Menü',
            Icons.home,
            Colors.grey.shade600,
            () => _goToHome(),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String text, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: 20),
      label: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 5,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}";
  }

  void _goToNextLevel() {
    Navigator.pushReplacementNamed(context, '/wordle', arguments: {
      'gameMode': GameMode.challenge,
      'nextLevel': true,
    });
  }

  void _restartGame() {
    Navigator.pushReplacementNamed(context, '/wordle', arguments: {
      'gameMode': widget.gameMode,
      'restart': true,
    });
  }

  void _goToHome() {
    Navigator.pushReplacementNamed(context, '/home');
  }
}

// Konfeti parçacığı sınıfı
class ConfettiParticle {
  double x;
  double y;
  double velocityX;
  double velocityY;
  Color color;
  double size;
  double rotation;
  double rotationSpeed;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.velocityX,
    required this.velocityY,
    required this.color,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
  });
}

// Konfeti painter sınıfı
class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;
  final double progress;

  ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      // Partikül pozisyonunu güncelle
      final currentY = particle.y + (particle.velocityY * progress);
      final currentX = particle.x + (particle.velocityX * progress * 0.5);
      final currentRotation = particle.rotation + (particle.rotationSpeed * progress);

      // Ekran dışına çıkanları gösterme
      if (currentY > 1.2) continue;

      final paint = Paint()
        ..color = particle.color.withOpacity(math.max(0, 1 - progress * 0.5));

      canvas.save();
      canvas.translate(currentX * size.width, currentY * size.height);
      canvas.rotate(currentRotation);

      // Konfeti şekli (dikdörtgen)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: particle.size,
            height: particle.size * 0.6,
          ),
          const Radius.circular(2),
        ),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 