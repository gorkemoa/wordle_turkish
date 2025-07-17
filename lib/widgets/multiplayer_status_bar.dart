// lib/widgets/multiplayer_status_bar.dart

import 'package:flutter/material.dart';

/// 🎮 Multiplayer oyun durum çubuğu
/// 
/// Bu widget şu bilgileri gösterir:
/// - Oyun durumu (sıra, bekleme, bitmiş)
/// - Aktif oyuncu göstergesi
/// - Oyun süresi (opsiyonel)
/// - Animasyonlu durum göstergeleri
class MultiplayerStatusBar extends StatefulWidget {
  final String status;
  final bool isMyTurn;
  final bool gameFinished;
  final Duration? gameTime;

  const MultiplayerStatusBar({
    Key? key,
    required this.status,
    required this.isMyTurn,
    required this.gameFinished,
    this.gameTime,
  }) : super(key: key);

  @override
  State<MultiplayerStatusBar> createState() => _MultiplayerStatusBarState();
}

class _MultiplayerStatusBarState extends State<MultiplayerStatusBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Sadece sıra geldiğinde animasyon
    if (widget.isMyTurn && !widget.gameFinished) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(MultiplayerStatusBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Animasyon durumunu güncelle
    if (widget.isMyTurn && !widget.gameFinished) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _getGradientColors(),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _getPrimaryColor().withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Sol taraf: Durum göstergesi
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: widget.isMyTurn && !widget.gameFinished 
                        ? _pulseAnimation.value 
                        : 1.0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getIndicatorColor(),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _getIndicatorColor().withOpacity(0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Text(
                widget.status,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          // Sağ taraf: Ek bilgiler
          Row(
            children: [
              // Oyun süresi (varsa)
              if (widget.gameTime != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatTime(widget.gameTime!),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              
              const SizedBox(width: 8),
              
              // Durum ikonu
              Icon(
                _getStatusIcon(),
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Color> _getGradientColors() {
    if (widget.gameFinished) {
      return [
        const Color(0xFF4A4A4A),
        const Color(0xFF2A2A2A),
      ];
    }
    
    if (widget.isMyTurn) {
      return [
        const Color(0xFF538D4E),
        const Color(0xFF6AAA64),
      ];
    }
    
    return [
      const Color(0xFFC9B458),
      const Color(0xFFD4AC0D),
    ];
  }

  Color _getPrimaryColor() {
    if (widget.gameFinished) {
      return const Color(0xFF4A4A4A);
    }
    
    if (widget.isMyTurn) {
      return const Color(0xFF538D4E);
    }
    
    return const Color(0xFFC9B458);
  }

  Color _getIndicatorColor() {
    if (widget.gameFinished) {
      return Colors.grey;
    }
    
    if (widget.isMyTurn) {
      return Colors.greenAccent;
    }
    
    return Colors.orangeAccent;
  }

  IconData _getStatusIcon() {
    if (widget.gameFinished) {
      return Icons.flag;
    }
    
    if (widget.isMyTurn) {
      return Icons.edit;
    }
    
    return Icons.hourglass_empty;
  }

  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }
} 