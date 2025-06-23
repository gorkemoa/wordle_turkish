import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/duel_viewmodel.dart';
import '../models/duel_game.dart';

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

  @override
  void initState() {
    super.initState();
    
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
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _slideFadeController.dispose();
    _collisionController.dispose();
    super.dispose();
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
                if (!mounted) return;
                
                final viewModel = Provider.of<DuelViewModel>(context, listen: false);
                await viewModel.leaveGame();
                
                // Bekleme odasından çık ve DuelPage'e dön (oradan ana sayfaya gidecek)
                if (mounted && context.mounted) {
                  Navigator.of(context).pop(false); // Oyun başlamadı sinyali
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
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Consumer<DuelViewModel>(
        builder: (context, viewModel, child) {
          final game = viewModel.currentGame;
          
          // Oyun yükleniyor
          if (game == null) {
            return _buildLoadingState();
          }

          // İki oyuncu varsa ve oyun hazır ise, oyun sayfasına dön
          if ((game.status == GameStatus.active || viewModel.showingCountdown) && !_hasNavigated) {
            debugPrint('DuelWaitingRoom - Oyun başlıyor! Status: ${game.status}, showingCountdown: ${viewModel.showingCountdown}');
            _hasNavigated = true; // Flag'i set et
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) { // mounted kontrolü yeterli
                debugPrint('DuelWaitingRoom - Navigator.pop(true) çağrılıyor');
                Navigator.of(context).pop(true); // Oyun başladı sinyali
              }
            });
            return _buildGameStartingState();
          }

          // Bekleme odası
          return WillPopScope(
            onWillPop: () async {
              _showExitDialog();
              return false; // Geri tuşunu manuel yöneteceğiz
            },
            child: _buildWaitingRoom(context, game, viewModel),
          );
        },
      ),
    );
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

  Widget _buildWaitingRoom(BuildContext context, DuelGame game, DuelViewModel viewModel) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      body: Stack(
        children: [
          // Hareketli Arka Plan
          _buildAnimatedBackground(),

          // Ana İçerik
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: AnimatedBuilder(
                animation: _slideFadeController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: child,
                    ),
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildHeader(),
                    _buildPlayersCard(game, viewModel),
                    _buildTokenInfo(),
                    _buildFooter(viewModel),
                  ],
                ),
              ),
            ),
          ),
        ],
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

  Widget _buildHeader() {
    return const Column(
      children: [
        Text(
          'Rakip Bekleniyor...',
          style: TextStyle(
            fontFamily: 'RussoOne',
            fontSize: 28,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Sana en uygun rakip aranıyor, lütfen bekle.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white70,
          ),
        ),
      ],
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
    return SizedBox(
      height: 50, // Buton için sabit alan
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