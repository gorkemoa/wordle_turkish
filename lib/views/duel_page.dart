import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/duel_viewmodel.dart';
import '../models/duel_game.dart';
import '../widgets/keyboard_widget.dart';

class DuelPage extends StatefulWidget {
  const DuelPage({Key? key}) : super(key: key);

  @override
  State<DuelPage> createState() => _DuelPageState();
}

class _DuelPageState extends State<DuelPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startGame();
    });
  }

  Future<void> _startGame() async {
    final viewModel = Provider.of<DuelViewModel>(context, listen: false);
    final success = await viewModel.startDuelGame();
    
    if (!success) {
      _showErrorDialog('Oyun başlatılamadı', 'Bağlantı hatası oluştu');
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Dialog'u kapat
              Navigator.pop(context); // Ana sayfaya dön
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _showGameResultDialog(DuelGame game) {
    final viewModel = Provider.of<DuelViewModel>(context, listen: false);
    final currentPlayer = viewModel.currentPlayer;
    final opponentPlayer = viewModel.opponentPlayer;
    
    if (currentPlayer == null) return;

    String title;
    String message;
    Color titleColor = Colors.blue;

    if (game.winnerId == currentPlayer.playerId) {
      title = '🎉 Kazandınız!';
      message = 'Tebrikler! Rakibinizi yendiniz.';
      titleColor = Colors.green;
    } else if (game.winnerId != null) {
      title = '😔 Kaybettiniz';
      message = 'Rakibiniz sizden önce kelimeyi buldu.';
      titleColor = Colors.red;
    } else {
      title = '⏰ Oyun Sona Erdi';
      message = 'Kimse kelimeyi bulamadı.\nKelime: ${game.secretWord}';
      titleColor = Colors.orange;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 16),
            if (opponentPlayer != null) ...[
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        'Sen',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: game.winnerId == currentPlayer.playerId 
                              ? Colors.green : Colors.grey,
                        ),
                      ),
                      Text('${currentPlayer.currentAttempt + 1}/6'),
                    ],
                  ),
                  const Text(' VS '),
                  Column(
                    children: [
                      Text(
                        opponentPlayer.playerName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: game.winnerId == opponentPlayer.playerId 
                              ? Colors.green : Colors.grey,
                        ),
                      ),
                      Text('${opponentPlayer.currentAttempt + 1}/6'),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await viewModel.leaveGame();
              Navigator.pop(context); // Dialog'u kapat
              Navigator.pop(context); // Ana sayfaya dön
            },
            child: const Text('Ana Menü'),
          ),
          TextButton(
            onPressed: () async {
              await viewModel.leaveGame();
              Navigator.pop(context); // Dialog'u kapat
              _startGame(); // Yeni oyun başlat
            },
            child: const Text('Tekrar Oyna'),
          ),
        ],
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
      ),
      body: Consumer<DuelViewModel>(
        builder: (context, viewModel, child) {
          final game = viewModel.currentGame;
          
          // Oyun yükleniyor
          if (game == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.blue),
                  SizedBox(height: 16),
                  Text(
                    'Rakip aranıyor...',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Lütfen bekleyin',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          // Oyun bitti kontrolü
          if (game.status == GameStatus.finished) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showGameResultDialog(game);
            });
          }

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
                  padding: const EdgeInsets.all(8),
                  child: _DuelKeyboardWidget(viewModel: viewModel),
                ),
            ],
          );
        },
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
                  letter = player.guesses[row][col];
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
}

// Düello için özel klavye widget'ı
class _DuelKeyboardWidget extends StatelessWidget {
  final DuelViewModel viewModel;

  const _DuelKeyboardWidget({required this.viewModel});

  final List<List<String>> keyboardRows = const [
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', 'Ğ', 'Ü'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'Ş', 'İ'],
    ['Z', 'X', 'C', 'V', 'B', 'N', 'M', 'Ö', 'Ç', 'BACK', 'ENTER'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keyboardRows.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((key) {
            if (key == 'BACK') {
              return _buildSpecialKey(
                context,
                icon: Icons.backspace_rounded,
                onTap: viewModel.onBackspace,
                color: Colors.redAccent,
              );
            } else if (key == 'ENTER') {
              return _buildSpecialKey(
                context,
                label: 'GİR',
                onTap: viewModel.onEnter,
                color: Colors.green,
                flex: 2,
              );
            } else {
              return _buildLetterKey(context, key);
            }
          }).toList(),
        );
      }).toList(),
    );
  }

  Widget _buildLetterKey(BuildContext context, String key) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
        child: GestureDetector(
          onTap: () => viewModel.onKeyTap(key),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF565758),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Text(
              key,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
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
    int flex = 1,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: color ?? const Color(0xFF565758),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: label != null
                ? Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  )
                : Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
} 