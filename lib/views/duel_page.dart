import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/duel_viewmodel.dart';
import '../models/duel_game.dart';
import '../widgets/keyboard_widget.dart';
import 'duel_result_page.dart';
import 'duel_waiting_room.dart';

class DuelPage extends StatefulWidget {
  const DuelPage({Key? key}) : super(key: key);

  @override
  State<DuelPage> createState() => _DuelPageState();
}

class _DuelPageState extends State<DuelPage> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Pulse animasyonu
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startGame();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startGame() async {
    try {
      final viewModel = Provider.of<DuelViewModel>(context, listen: false);
      final success = await viewModel.startDuelGame();
      
      if (!mounted) return;
      
      if (!success) {
        _showErrorDialog('Oyun başlatılamadı', 'Bağlantı hatası oluştu');
        return;
      }
      
      // Bekleme odasına yönlendir
      final gameStarted = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => const DuelWaitingRoom(),
        ),
      );
      
      debugPrint('DuelPage - Bekleme odasından döndü, gameStarted: $gameStarted');
      
      // Eğer oyun başlamadıysa ana sayfaya dön
      if (gameStarted != true && mounted) {
        debugPrint('DuelPage - Oyun başlamadı, ana sayfaya dönülüyor');
        Navigator.of(context).pop();
      } else if (gameStarted == true && mounted) {
        debugPrint('DuelPage - Oyun başladı, burada kalıyoruz');
        // Oyun başladıysa burada kalıp oyunu göster
      }
    } catch (e) {
      print('DuelPage _startGame hatası: $e');
      if (mounted) {
        _showErrorDialog('Hata', 'Beklenmeyen bir hata oluştu: $e');
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Dialog'u kapat
              Navigator.pop(context); // Ana sayfaya dön
            },
            child: const Text('Tamam', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  void _navigateToResultPage(DuelGame game) {
    final viewModel = Provider.of<DuelViewModel>(context, listen: false);
    final currentPlayer = viewModel.currentPlayer;
    final opponentPlayer = viewModel.opponentPlayer;
    
    if (currentPlayer == null) return;

    // Sonuç sayfasına yönlendir
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => DuelResultPage(
          game: game,
          currentPlayer: currentPlayer,
          opponentPlayer: opponentPlayer,
          playerName: viewModel.playerName,
          gameDuration: viewModel.gameDuration,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          'Düello Modu',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.red),
            onPressed: () => _showExitDialog(),
          ),
        ],
      ),
      body: Consumer<DuelViewModel>(
        builder: (context, viewModel, child) {
          final game = viewModel.currentGame;
          
          // Debug bilgisi
          if (game != null) {
            debugPrint('DuelPage build - Oyun durumu: ${game.status}, showingCountdown: ${viewModel.showingCountdown}, isGameActive: ${viewModel.isGameActive}');
          }
          
          // Oyun yükleniyor
          if (game == null) {
            debugPrint('DuelPage - Oyun null, loading gösteriliyor');
            return _buildLoadingState();
          }
          
          // Bekleme durumu - bu durumda bekleme odası açık olmalı
          if (game.status == GameStatus.waiting) {
            debugPrint('DuelPage - Oyun waiting durumunda, loading gösteriliyor');
            return _buildLoadingState();
          }

          // Countdown göster
          if (viewModel.showingCountdown) {
            debugPrint('DuelPage - Countdown gösteriliyor');
            return _buildGameStartCountdown();
          }

          // Oyun bitti kontrolü
          if (game.status == GameStatus.finished) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _navigateToResultPage(game);
            });
          }

          // Aktif oyun
          debugPrint('DuelPage - Aktif oyun gösteriliyor');
          return Column(
            children: [
              // Oyuncu bilgileri
              _buildPlayersInfo(viewModel),
              
              // Oyun tahtası
              Expanded(
                child: _buildGameBoard(viewModel),
              ),
              
              // Klavye
              if (viewModel.isGameActive)
                Container(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: _DuelKeyboardWidget(viewModel: viewModel),
                ),
            ],
          );
        },
      ),
    );
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
                'Oyundan Çık?',
                style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
          content: const Text(
            'Eğer şimdi çıkarsan, oyunu kaybetmiş sayılacaksın. Emin misin?',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Devam Et',
                style: TextStyle(color: Colors.blue),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final viewModel = Provider.of<DuelViewModel>(context, listen: false);
                await viewModel.leaveGame();
                Navigator.popUntil(context, (route) => route.isFirst);
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

  Widget _buildLoadingState() {
    return const Center(
            child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
              children: [
          CircularProgressIndicator(
            color: Colors.blue,
          ),
          SizedBox(height: 16),
                Text(
            'Oyun yükleniyor...',
                  style: TextStyle(
              color: Colors.white,
              fontSize: 18,
                fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }









  Widget _buildPlayersInfo(DuelViewModel viewModel) {
    final currentPlayer = viewModel.currentPlayer;
    final opponentPlayer = viewModel.opponentPlayer;
    final game = viewModel.currentGame!;

    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF1E1E1E),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Mevcut oyuncu
          _buildPlayerCard(
            name: viewModel.playerName,
            attempts: currentPlayer?.currentAttempt ?? 0,
            status: currentPlayer?.status ?? PlayerStatus.waiting,
            isWinner: game.winnerId == currentPlayer?.playerId,
            isCurrentPlayer: true,
          ),
          
          // VS
          const Text(
            'VS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          // Rakip oyuncu
          _buildPlayerCard(
            name: opponentPlayer?.playerName ?? 'Bekleniyor...',
            attempts: opponentPlayer?.currentAttempt ?? 0,
            status: opponentPlayer?.status ?? PlayerStatus.waiting,
            isWinner: game.winnerId == opponentPlayer?.playerId,
            isCurrentPlayer: false,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard({
    required String name,
    required int attempts,
    required PlayerStatus status,
    required bool isWinner,
    required bool isCurrentPlayer,
  }) {
    Color statusColor = Colors.grey;
    String statusText = 'Bekliyor';

    switch (status) {
      case PlayerStatus.playing:
        statusColor = Colors.blue;
        statusText = 'Oynuyor';
        break;
      case PlayerStatus.won:
        statusColor = Colors.green;
        statusText = 'Kazandı!';
        break;
      case PlayerStatus.lost:
        statusColor = Colors.red;
        statusText = 'Kaybetti';
        break;
      case PlayerStatus.disconnected:
        statusColor = Colors.orange;
        statusText = 'Ayrıldı';
        break;
      default:
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentPlayer ? const Color(0xFF2A2A2A) : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: isWinner ? Border.all(color: Colors.green, width: 2) : null,
      ),
      child: Column(
        children: [
          Text(
            name,
            style: TextStyle(
              color: isCurrentPlayer ? Colors.blue : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$attempts/6',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            statusText,
            style: TextStyle(color: statusColor, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildGameBoard(DuelViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Mevcut oyuncunun tahtası
          Expanded(
            child: _buildPlayerBoard(
              title: 'Senin Tahminlerin',
              player: viewModel.currentPlayer,
              currentGuess: viewModel.currentGuess,
              currentColumn: viewModel.currentColumn,
              viewModel: viewModel,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Rakip oyuncunun tahtası
          Expanded(
            child: _buildPlayerBoard(
              title: 'Rakip Tahminleri',
              player: viewModel.opponentPlayer,
              currentGuess: null,
              currentColumn: 0,
              viewModel: viewModel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerBoard({
    required String title,
    DuelPlayer? player,
    List<String>? currentGuess,
    required int currentColumn,
    required DuelViewModel viewModel,
  }) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              childAspectRatio: 1,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: 30, // 6 satır x 5 sütun
            itemBuilder: (context, index) {
              final row = index ~/ 5;
              final col = index % 5;
              
              String letter = '';
              Color boxColor = const Color(0xFF3A3A3C);
              Color textColor = Colors.white;
              
              if (player != null && row < player.guesses.length) {
                // Tamamlanmış tahminler
                if (row < player.currentAttempt) {
                  letter = player.guesses[row][col] == '_' ? '' : player.guesses[row][col];
                  boxColor = viewModel.getColorFromString(player.guessColors[row][col]);
                }
                // Mevcut satır (sadece mevcut oyuncu için)
                else if (row == player.currentAttempt && currentGuess != null) {
                  if (col < currentColumn) {
                    letter = currentGuess[col];
                    boxColor = const Color(0xFF565758);
                  }
                }
              }
              
              return Container(
                decoration: BoxDecoration(
                  color: boxColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: letter.isEmpty ? const Color(0xFF565758) : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    letter,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGameStartCountdown() {
    return Container(
      color: const Color(0xFF121212),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
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
                        colors: [Colors.green.shade400, Colors.blue.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 60,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            Text(
              'Oyun Başlıyor!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Hazır mısın? Kelimeyi ilk bulan kazanır!',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const LinearProgressIndicator(
              color: Colors.green,
              backgroundColor: Color(0xFF2A2A2A),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadyConfirmation(DuelViewModel viewModel) {
    final currentPlayer = viewModel.currentPlayer;
    final opponentPlayer = viewModel.opponentPlayer;
    
    final currentReady = currentPlayer?.status == PlayerStatus.ready;
    final opponentReady = opponentPlayer?.status == PlayerStatus.ready;
    final allReady = currentReady && opponentReady;
    
    if (allReady) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green.shade600.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.shade600),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade400, size: 20),
            const SizedBox(width: 8),
            Text(
              'Her iki oyuncu hazır! Oyun başlıyor...',
              style: TextStyle(
                color: Colors.green.shade200,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    
    return Column(
      children: [
        // Countdown timer
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade600.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade600),
          ),
          child: Column(
            children: [
              Text(
                '⏰ ${viewModel.readyCountdown} saniye',
                style: TextStyle(
                  color: Colors.red.shade200,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Onaylamassanız yeni rakip aranacak!',
                style: TextStyle(
                  color: Colors.red.shade300,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Oyuncu onay durumları
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: currentReady 
                    ? Colors.green.shade600.withOpacity(0.2)
                    : Colors.orange.shade600.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: currentReady ? Colors.green.shade600 : Colors.orange.shade600,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      currentReady ? Icons.check_circle : Icons.access_time,
                      color: currentReady ? Colors.green.shade400 : Colors.orange.shade400,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sen',
                      style: TextStyle(
                        color: currentReady ? Colors.green.shade200 : Colors.orange.shade200,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      currentReady ? 'Hazır' : 'Bekliyor',
                      style: TextStyle(
                        color: currentReady ? Colors.green.shade300 : Colors.orange.shade300,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(width: 16),
            
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: opponentReady 
                    ? Colors.green.shade600.withOpacity(0.2)
                    : Colors.orange.shade600.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: opponentReady ? Colors.green.shade600 : Colors.orange.shade600,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      opponentReady ? Icons.check_circle : Icons.access_time,
                      color: opponentReady ? Colors.green.shade400 : Colors.orange.shade400,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      opponentPlayer?.playerName ?? 'Rakip',
                      style: TextStyle(
                        color: opponentReady ? Colors.green.shade200 : Colors.orange.shade200,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      opponentReady ? 'Hazır' : 'Bekliyor',
                      style: TextStyle(
                        color: opponentReady ? Colors.green.shade300 : Colors.orange.shade300,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 20),
        
        // Onay butonu
        if (!currentReady)
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              onPressed: () => viewModel.setPlayerReady(true),
              icon: const Icon(Icons.check, color: Colors.white, size: 28),
              label: const Text(
                'HAZIR! OYNAMAYA BAŞLA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
              ),
            ),
          ),
      ],
    );
  }
}

// Düello için özel klavye widget'ı
class _DuelKeyboardWidget extends StatelessWidget {
  final DuelViewModel viewModel;

  const _DuelKeyboardWidget({required this.viewModel});

  final List<List<String>> keyboardRows = const [
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', 'Ğ', 'Ü'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'Ş', 'İ'],
    ['ENTER', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', 'Ö', 'Ç', 'BACK'],
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Responsive boyutlar
    final keyHeight = screenHeight * 0.07; // Ekran yüksekliğinin %7'si
    final fontSize = screenWidth * 0.04; // Ekran genişliğinin %4'ü
    final spacing = screenWidth * 0.005; // Responsive spacing
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.02,
        vertical: screenHeight * 0.01,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: keyboardRows.asMap().entries.map((entry) {
          int rowIndex = entry.key;
          List<String> row = entry.value;
          
          return Padding(
            padding: EdgeInsets.symmetric(vertical: spacing),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _buildRowKeys(context, row, rowIndex, keyHeight, fontSize, spacing),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Widget> _buildRowKeys(BuildContext context, List<String> row, int rowIndex, 
                           double keyHeight, double fontSize, double spacing) {
    List<Widget> keys = [];
    
    for (int i = 0; i < row.length; i++) {
      String key = row[i];
      
      if (key == 'BACK') {
        keys.add(_buildSpecialKey(
          context,
          icon: Icons.backspace_rounded,
          onTap: viewModel.onBackspace,
          color: Colors.red.shade600,
          keyHeight: keyHeight,
          fontSize: fontSize,
          spacing: spacing,
          flex: rowIndex == 2 ? 1.5 : 1, // Son satırda biraz büyük
        ));
      } else if (key == 'ENTER') {
        keys.add(_buildSpecialKey(
          context,
          label: 'GİR',
          onTap: viewModel.onEnter,
          color: Colors.green.shade600,
          keyHeight: keyHeight,
          fontSize: fontSize,
          spacing: spacing,
          flex: rowIndex == 2 ? 1.5 : 1, // Son satırda biraz büyük
        ));
      } else {
        keys.add(_buildLetterKey(
          context, 
          key, 
          keyHeight, 
          fontSize, 
          spacing,
          flex: rowIndex == 1 ? 1.1 : 1.0, // Orta satır biraz büyük
        ));
      }
    }
    
    return keys;
  }

  Widget _buildLetterKey(BuildContext context, String key, double keyHeight, 
                        double fontSize, double spacing, {double flex = 1.0}) {
    return Expanded(
      flex: (flex * 10).round(),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => viewModel.onKeyTap(key),
            borderRadius: BorderRadius.circular(8),
            splashColor: Colors.blue.withOpacity(0.3),
            highlightColor: Colors.blue.withOpacity(0.1),
            child: Container(
              height: keyHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF565758),
                    const Color(0xFF3A3A3C),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF6D6D6D),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                key,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 1,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialKey(
    BuildContext context, {
    String? label,
    IconData? icon,
    required VoidCallback onTap,
    Color? color,
    required double keyHeight,
    required double fontSize,
    required double spacing,
    double flex = 1.0,
  }) {
    return Expanded(
      flex: (flex * 10).round(),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            splashColor: color?.withOpacity(0.3) ?? Colors.grey.withOpacity(0.3),
            highlightColor: color?.withOpacity(0.1) ?? Colors.grey.withOpacity(0.1),
            child: Container(
              height: keyHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color ?? const Color(0xFF565758),
                    (color ?? const Color(0xFF565758)).withOpacity(0.8),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (color ?? const Color(0xFF6D6D6D)).withOpacity(0.5),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: label != null
                  ? Text(
                      label,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: fontSize * 0.9,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.7),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    )
                  : Icon(
                      icon, 
                      color: Colors.white, 
                      size: fontSize * 1.2,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.7),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
} 