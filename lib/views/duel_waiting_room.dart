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
  
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;
  
  // Navigation flag - sadece bir kez pop yapmak için
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    
    // Pulse animasyonu
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);
    
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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
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
          return _buildWaitingRoom(game, viewModel);
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
            animation: _pulseAnimation,
            builder: (context, child) {
              final scaleValue = (_pulseAnimation.value * 0.3 + 0.8).clamp(0.8, 1.1);
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

  Widget _buildWaitingRoom(DuelGame game, DuelViewModel viewModel) {
    final currentPlayer = viewModel.currentPlayer;
    final playerCount = game.players.length;
    final isWaitingForOpponent = playerCount == 1;
    
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          '🎮 Düello Bekleme Odası',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.shade600.withOpacity(0.3),
                Colors.purple.shade600.withOpacity(0.3),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Durum göstergesi - Üst kısım
              _buildStatusIndicator(isWaitingForOpponent),
              
              const SizedBox(height: 20),
              
              // Oyuncular kartı - Merkez üst
              Expanded(
                flex: 3,
                child: _buildPlayersCard(game, viewModel),
              ),
              
              const SizedBox(height: 16),
              
              // Oyun bilgileri - Kompakt tasarım
              _buildCompactGameInfo(game),
              
              const SizedBox(height: 20),
              
              // Onay sistemi veya bekleme durumu - Alt merkez
              if (isWaitingForOpponent)
                _buildWaitingStatus()
              else
                _buildReadySystem(viewModel),
              
              const SizedBox(height: 20),
              
              // Başka rakip bul butonu (sadece rakip beklenirken göster)
              if (isWaitingForOpponent)
                _buildFindNewOpponentButton(viewModel),
              
              if (isWaitingForOpponent)
                const SizedBox(height: 12),
              
              // Çıkış butonu - En alt
              _buildExitButton(isWaitingForOpponent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(bool isWaitingForOpponent) {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        final rotationValue = _rotationAnimation.value.clamp(0.0, 1.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.rotate(
              angle: rotationValue * 2 * math.pi,
              child: Icon(
                isWaitingForOpponent ? Icons.search : Icons.people,
                color: isWaitingForOpponent ? Colors.orange : Colors.green,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              isWaitingForOpponent 
                ? 'Rakip Aranıyor...' 
                : 'Rakip Bulundu!',
              style: TextStyle(
                color: isWaitingForOpponent ? Colors.orange : Colors.green,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCompactGameInfo(DuelGame game) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildQuickInfoItem(Icons.text_fields, '5 Harf', Colors.blue),
          Container(width: 1, height: 20, color: Colors.grey.withOpacity(0.3)),
          _buildQuickInfoItem(Icons.casino, '6 Deneme', Colors.green),
          Container(width: 1, height: 20, color: Colors.grey.withOpacity(0.3)),
          _buildQuickInfoItem(Icons.tag, game.gameId.substring(0, 4).toUpperCase(), Colors.purple),
        ],
      ),
    );
  }

  Widget _buildQuickInfoItem(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildGameInfoCard(DuelGame game) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E1E1E),
            const Color(0xFF2A2A2A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade400, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Oyun Detayları',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  Icons.text_fields,
                  'Kelime Uzunluğu',
                  '5 Harf',
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoItem(
                  Icons.casino,
                  'Tahmin Hakkı',
                  '6 Deneme',
                  Colors.green,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  Icons.flash_on,
                  'Oyun Modu',
                  'Hızlı Düello',
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoItem(
                  Icons.tag,
                  'Oyun Kodu',
                  game.gameId.substring(0, 6).toUpperCase(),
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersCard(DuelGame game, DuelViewModel viewModel) {
    final currentPlayer = viewModel.currentPlayer;
    final playerCount = game.players.length;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Başlık
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade600, Colors.blue.shade600],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people, color: Colors.white, size: 20),
                const SizedBox(width: 6),
                Text(
                  'Oyuncular ($playerCount/2)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Oyuncular - Yatay düzen
          if (playerCount == 2)
            Row(
              children: [
                // Sol oyuncu
                Expanded(
                  child: _buildCompactPlayerCard(
                    game.players.values.where((p) => p.playerId == currentPlayer?.playerId).first,
                    true,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // VS Göstergesi
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade600,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    'VS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Sağ oyuncu
                Expanded(
                  child: _buildCompactPlayerCard(
                    game.players.values.where((p) => p.playerId != currentPlayer?.playerId).first,
                    false,
                  ),
                ),
              ],
            )
          else
            // Tek oyuncu durumu
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCompactPlayerCard(
                  game.players.values.first,
                  true,
                ),
                const SizedBox(height: 12),
                _buildEmptyPlayerSlot(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCompactPlayerCard(DuelPlayer player, bool isCurrentPlayer) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isCurrentPlayer 
          ? Colors.blue.shade600.withOpacity(0.2) 
          : const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: isCurrentPlayer 
          ? Border.all(color: Colors.blue.shade600, width: 2)
          : Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isCurrentPlayer 
                  ? [Colors.blue.shade400, Colors.blue.shade600]
                  : [Colors.grey.shade600, Colors.grey.shade800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              isCurrentPlayer ? Icons.person : Icons.person_outline,
              color: Colors.white,
              size: 32,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Oyuncu adı
          Text(
            player.playerName,
            style: TextStyle(
              color: isCurrentPlayer ? Colors.blue.shade200 : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 2),
          
          Text(
            isCurrentPlayer ? 'Sen' : 'Rakip',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12,
            ),
          ),
          
          const SizedBox(height: 6),
          
          // Durum göstergesi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: player.status == PlayerStatus.ready 
                ? Colors.green.shade600.withOpacity(0.2)
                : Colors.orange.shade600.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: player.status == PlayerStatus.ready 
                  ? Colors.green.shade600
                  : Colors.orange.shade600,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  player.status == PlayerStatus.ready 
                    ? Icons.check_circle_outline
                    : Icons.hourglass_empty,
                  color: player.status == PlayerStatus.ready 
                    ? Colors.green.shade300 
                    : Colors.orange.shade300,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  player.status == PlayerStatus.ready ? 'Hazır' : 'Beklemede',
                  style: TextStyle(
                    color: player.status == PlayerStatus.ready 
                      ? Colors.green.shade300 
                      : Colors.orange.shade300,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(DuelPlayer player, bool isCurrentPlayer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentPlayer 
          ? Colors.blue.shade600.withOpacity(0.2) 
          : const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: isCurrentPlayer 
          ? Border.all(color: Colors.blue.shade600, width: 2)
          : Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isCurrentPlayer 
                  ? [Colors.blue.shade400, Colors.blue.shade600]
                  : [Colors.grey.shade600, Colors.grey.shade800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              isCurrentPlayer ? Icons.person : Icons.person_outline,
              color: Colors.white,
              size: 28,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Oyuncu bilgileri
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.playerName,
                  style: TextStyle(
                    color: isCurrentPlayer ? Colors.blue.shade200 : Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isCurrentPlayer ? 'Sen' : 'Rakip Oyuncu',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Durum göstergesi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: player.status == PlayerStatus.ready 
                ? Colors.green.shade600.withOpacity(0.2)
                : Colors.orange.shade600.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: player.status == PlayerStatus.ready 
                  ? Colors.green.shade600
                  : Colors.orange.shade600,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  player.status == PlayerStatus.ready 
                    ? Icons.check_circle_outline
                    : Icons.hourglass_empty,
                  color: player.status == PlayerStatus.ready 
                    ? Colors.green.shade300 
                    : Colors.orange.shade300,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  player.status == PlayerStatus.ready ? 'Hazır' : 'Beklemede',
                  style: TextStyle(
                    color: player.status == PlayerStatus.ready 
                      ? Colors.green.shade300 
                      : Colors.orange.shade300,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlayerSlot() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _pulseAnimation.value.clamp(0.0, 1.0),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.withOpacity(0.3),
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade700,
                  ),
                  child: Icon(
                    Icons.person_add,
                    color: Colors.grey.shade500,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Rakip Bekleniyor...',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Biri katılsın',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade600),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.more_horiz,
                        color: Colors.grey.shade400,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Boş',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWaitingStatus() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final pulseValue = (_pulseAnimation.value * 0.3 + 0.7).clamp(0.3, 1.0);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.orange.shade600.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.orange.shade600.withOpacity(pulseValue),
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.hourglass_empty,
                color: Colors.orange.shade400,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Rakip Oyuncu Bekleniyor...',
                style: TextStyle(
                  color: Colors.orange.shade200,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReadySystem(DuelViewModel viewModel) {
    final isReady = viewModel.isPlayerReady;
    final countdown = viewModel.readyCountdown;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isReady 
          ? Colors.green.shade600.withOpacity(0.15)
          : Colors.blue.shade600.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isReady ? Colors.green.shade600 : Colors.blue.shade600,
        ),
      ),
      child: Row(
        children: [
          // Sol taraf - Icon ve durum
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Icon(
                  isReady ? Icons.check_circle : Icons.play_circle_outline,
                  color: isReady ? Colors.green.shade400 : Colors.blue.shade400,
                  size: 40,
                ),
                const SizedBox(height: 8),
                Text(
                  isReady ? 'Hazırsın!' : 'Hazır mısın?',
                  style: TextStyle(
                    color: isReady ? Colors.green.shade200 : Colors.blue.shade200,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (countdown > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${countdown}s',
                    style: TextStyle(
                      color: Colors.orange.shade400,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Sağ taraf - Buton
          Expanded(
            flex: 3,
            child: Column(
              children: [
                if (!isReady)
                  ElevatedButton.icon(
                    onPressed: () => viewModel.setPlayerReady(true),
                    icon: const Icon(Icons.check, color: Colors.white, size: 20),
                    label: const Text(
                      'Hazırım!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => viewModel.setPlayerReady(false),
                        icon: const Icon(Icons.close, color: Colors.white, size: 18),
                        label: const Text(
                          'Bekle',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Rakip bekleniyor...',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFindNewOpponentButton(DuelViewModel viewModel) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          // Loading dialog göster
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                backgroundColor: const Color(0xFF2A2A2A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.blue),
                    const SizedBox(height: 16),
                    const Text(
                      'Başka rakip aranıyor...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              );
            },
          );

          try {
            final success = await viewModel.findNewOpponent();
            
            // Dialog'u kapat
            if (mounted) {
              Navigator.of(context).pop();
            }
            
            if (!success && mounted) {
              // Hata mesajı göster
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Başka rakip bulunamadı. Tekrar deneyin.'),
                  backgroundColor: Colors.red.shade600,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } catch (e) {
            // Dialog'u kapat
            if (mounted) {
              Navigator.of(context).pop();
            }
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Bir hata oluştu. Tekrar deneyin.'),
                  backgroundColor: Colors.red.shade600,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        },
        icon: const Icon(Icons.refresh, color: Colors.white),
        label: const Text(
          'Başka Rakip Bul',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange.shade600,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildExitButton(bool isWaitingForOpponent) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _showExitDialog,
        icon: const Icon(Icons.exit_to_app, color: Colors.white),
        label: Text(
          isWaitingForOpponent ? 'Aramayı İptal Et' : 'Bekleme Odasından Çık',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade600,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(bool isWaitingForOpponent, DuelViewModel viewModel) {
    return Column(
      children: [
        // Ana çıkış butonu
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _showExitDialog,
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            label: Text(
              isWaitingForOpponent ? 'Aramayı İptal Et' : 'Bekleme Odasından Çık',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Ana sayfaya dön butonu
        TextButton.icon(
          onPressed: () async {
            final viewModel = Provider.of<DuelViewModel>(context, listen: false);
            await viewModel.leaveGame();
            
            // Bekleme odasından çık ve DuelPage'e dön (oradan ana sayfaya gidecek)
            if (mounted) {
              Navigator.of(context).pop(false); // Oyun başlamadı sinyali
            }
          },
          icon: Icon(Icons.home, color: Colors.grey.shade400),
          label: Text(
            'Ana Sayfa',
            style: TextStyle(color: Colors.grey.shade400),
          ),
        ),
      ],
    );
  }
}