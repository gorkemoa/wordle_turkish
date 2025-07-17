// lib/widgets/multiplayer_waiting_screen.dart

import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 🎮 Multiplayer eşleştirme bekleme ekranı
/// 
/// Bu widget şu özellikleri sağlar:
/// - Animasyonlu yükleme göstergesi
/// - Bekleme oyuncu sayısı
/// - İptal ve tekrar deneme butonları
/// - Gerçek zamanlı durum güncellemeleri
class MultiplayerWaitingScreen extends StatefulWidget {
  final int waitingPlayersCount;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;

  const MultiplayerWaitingScreen({
    Key? key,
    required this.waitingPlayersCount,
    this.onCancel,
    this.onRetry,
  }) : super(key: key);

  @override
  State<MultiplayerWaitingScreen> createState() => _MultiplayerWaitingScreenState();
}

class _MultiplayerWaitingScreenState extends State<MultiplayerWaitingScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _dotsController;
  
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _dotsAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _rotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _dotsController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _dotsAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _dotsController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animasyonlu logo
              _buildAnimatedLogo(),
              
              const SizedBox(height: 32),
              
              // Başlık
              const Text(
                'Rakip Aranıyor',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Animasyonlu alt başlık
              _buildAnimatedSubtitle(),
              
              const SizedBox(height: 32),
              
              // Bekleme istatistikleri
              _buildWaitingStats(),
              
              const SizedBox(height: 48),
              
              // İpuçları
              _buildTips(),
              
              const SizedBox(height: 32),
              
              // Butonlar
              _buildButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationAnimation.value,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF538D4E),
                        const Color(0xFF6AAA64),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF538D4E).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.people,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAnimatedSubtitle() {
    return AnimatedBuilder(
      animation: _dotsAnimation,
      builder: (context, child) {
        int dotsCount = (_dotsAnimation.value * 4).floor();
        String dots = '.' * dotsCount;
        
        return Text(
          'Eşleştirme yapılıyor$dots',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        );
      },
    );
  }

  Widget _buildWaitingStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF538D4E).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.people_outline,
                label: 'Bekleyen Oyuncular',
                value: widget.waitingPlayersCount.toString(),
                color: const Color(0xFF538D4E),
              ),
              _buildStatItem(
                icon: Icons.speed,
                label: 'Ortalama Eşleştirme',
                value: '< 30s',
                color: const Color(0xFFC9B458),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // İlerleme çubuğu
          _buildProgressBar(),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
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
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return AnimatedBuilder(
      animation: _dotsAnimation,
      builder: (context, child) {
        return Column(
          children: [
            const Text(
              'Eşleştirme İlerlemesi',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _dotsAnimation.value,
              backgroundColor: Colors.grey.shade800,
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFF538D4E),
              ),
              minHeight: 6,
            ),
          ],
        );
      },
    );
  }

  Widget _buildTips() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: Color(0xFFC9B458),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'İpuçları',
                style: TextStyle(
                  color: Color(0xFFC9B458),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTipItem('• Aynı anda birden fazla oyuncu bekliyor'),
          _buildTipItem('• Eşleşme bulunana kadar bekleyin'),
          _buildTipItem('• İnternet bağlantınızı kontrol edin'),
        ],
      ),
    );
  }

  Widget _buildTipItem(String tip) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        tip,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildButtons() {
    return Row(
      children: [
        // İptal butonu
        Expanded(
          child: OutlinedButton(
            onPressed: widget.onCancel,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.grey),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'İptal',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Tekrar dene butonu
        Expanded(
          child: ElevatedButton(
            onPressed: widget.onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF538D4E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Tekrar Dene',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
} 