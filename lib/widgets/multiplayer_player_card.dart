// lib/widgets/multiplayer_player_card.dart

import 'package:flutter/material.dart';
import '../models/multiplayer_game.dart';

/// 🎮 Multiplayer oyuncu kartı
/// 
/// Bu widget şu bilgileri gösterir:
/// - Oyuncu adı ve avatarı
/// - Mevcut deneme sayısı
/// - Oyuncu durumu (hazır, oynuyor, bitirdi)
/// - Kazanma göstergesi
/// - Bağlantı durumu
class MultiplayerPlayerCard extends StatefulWidget {
  final MultiplayerPlayer? player;
  final bool isCurrentPlayer;
  final bool isWinner;
  final bool showConnectionStatus;

  const MultiplayerPlayerCard({
    Key? key,
    required this.player,
    required this.isCurrentPlayer,
    this.isWinner = false,
    this.showConnectionStatus = true,
  }) : super(key: key);

  @override
  State<MultiplayerPlayerCard> createState() => _MultiplayerPlayerCardState();
}

class _MultiplayerPlayerCardState extends State<MultiplayerPlayerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    // Kazanan animasyonu
    if (widget.isWinner) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(MultiplayerPlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isWinner && !oldWidget.isWinner) {
      _glowController.repeat(reverse: true);
    } else if (!widget.isWinner && oldWidget.isWinner) {
      _glowController.stop();
      _glowController.reset();
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.player == null) {
      return _buildEmptyCard();
    }

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _getCardColors(),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _getBorderColor(),
              width: widget.isWinner ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _getBorderColor().withOpacity(
                  widget.isWinner ? _glowAnimation.value : 0.3,
                ),
                blurRadius: widget.isWinner ? 12 : 4,
                spreadRadius: widget.isWinner ? 2 : 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar ve bağlantı durumu
              _buildAvatarSection(),
              
              const SizedBox(height: 8),
              
              // Oyuncu adı
              _buildPlayerName(),
              
              const SizedBox(height: 8),
              
              // İstatistikler
              _buildStats(),
              
              const SizedBox(height: 8),
              
              // Durum göstergesi
              _buildStatusIndicator(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade700,
          width: 1,
        ),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey,
            child: Icon(
              Icons.person_outline,
              color: Colors.white,
              size: 24,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Bekleniyor...',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Stack(
      children: [
        // Avatar
        CircleAvatar(
          radius: 24,
          backgroundColor: _getAvatarBackgroundColor(),
          child: Text(
            widget.player!.avatar,
            style: const TextStyle(fontSize: 24),
          ),
        ),
        
        // Bağlantı durumu göstergesi
        if (widget.showConnectionStatus)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: _getConnectionColor(),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlayerName() {
    return Text(
      widget.player!.displayName,
      style: TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        decoration: widget.isWinner ? TextDecoration.underline : null,
      ),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem(
          icon: Icons.edit,
          value: '${widget.player!.currentAttempt}/6',
          label: 'Deneme',
        ),
        _buildStatItem(
          icon: Icons.score,
          value: widget.player!.score.toString(),
          label: 'Skor',
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white70,
          size: 14,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(),
            color: _getStatusColor(),
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            _getStatusText(),
            style: TextStyle(
              color: _getStatusColor(),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getCardColors() {
    if (widget.isWinner) {
      return [
        const Color(0xFF4CAF50),
        const Color(0xFF66BB6A),
      ];
    }

    if (widget.isCurrentPlayer) {
      return [
        const Color(0xFF3A3A3C),
        const Color(0xFF2A2A2D),
      ];
    }

    return [
      const Color(0xFF2A2A2D),
      const Color(0xFF1A1A1D),
    ];
  }

  Color _getBorderColor() {
    if (widget.isWinner) {
      return const Color(0xFF4CAF50);
    }

    if (widget.isCurrentPlayer) {
      return const Color(0xFF538D4E);
    }

    return Colors.grey.shade700;
  }

  Color _getAvatarBackgroundColor() {
    if (widget.isWinner) {
      return const Color(0xFF4CAF50);
    }

    if (widget.isCurrentPlayer) {
      return const Color(0xFF538D4E);
    }

    return const Color(0xFF3A3A3C);
  }

  Color _getConnectionColor() {
    if (widget.player!.isOnline) {
      return Colors.green;
    }

    return Colors.red;
  }

  Color _getStatusColor() {
    switch (widget.player!.status) {
      case PlayerStatus.waiting:
        return Colors.grey;
      case PlayerStatus.ready:
        return Colors.blue;
      case PlayerStatus.playing:
        return Colors.green;
      case PlayerStatus.finished:
        return Colors.purple;
      case PlayerStatus.disconnected:
        return Colors.red;
    }
  }

  IconData _getStatusIcon() {
    switch (widget.player!.status) {
      case PlayerStatus.waiting:
        return Icons.hourglass_empty;
      case PlayerStatus.ready:
        return Icons.check_circle;
      case PlayerStatus.playing:
        return Icons.play_arrow;
      case PlayerStatus.finished:
        return Icons.flag;
      case PlayerStatus.disconnected:
        return Icons.signal_wifi_off;
    }
  }

  String _getStatusText() {
    switch (widget.player!.status) {
      case PlayerStatus.waiting:
        return 'Bekliyor';
      case PlayerStatus.ready:
        return 'Hazır';
      case PlayerStatus.playing:
        return 'Oynuyor';
      case PlayerStatus.finished:
        return 'Bitirdi';
      case PlayerStatus.disconnected:
        return 'Çevrimdışı';
    }
  }
} 