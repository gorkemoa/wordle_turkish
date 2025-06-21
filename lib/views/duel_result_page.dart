import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/duel_game.dart';
import '../services/firebase_service.dart';
import 'duel_page.dart';

class DuelResultPage extends StatelessWidget {
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

  Future<void> _saveGameResult() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final bool isWinner = game.winnerId == currentPlayer.playerId;
      final bool hasOpponent = opponentPlayer != null;
      
      // Skor hesapla
      int score = 0;
      if (isWinner && hasOpponent) {
        // Kazanılan duello için skor
        final attemptsUsed = currentPlayer.currentAttempt + 1;
        final timeBonus = (300 - gameDuration.inSeconds).clamp(0, 300); // 5 dakika max
        final attemptBonus = (6 - attemptsUsed) * 50;
        score = 200 + timeBonus + attemptBonus;
      } else if (!isWinner && hasOpponent) {
        // Kaybedilen duello için az puan
        score = currentPlayer.currentAttempt * 20;
      } else {
        // Rakip ayrıldıysa minimum puan
        score = 50;
      }

      // Firebase'e kaydet
      await FirebaseService.saveGameResult(
        uid: user.uid,
        gameType: 'Duello',
        score: score,
        isWon: isWinner && hasOpponent,
        duration: gameDuration,
        additionalData: {
          'attempts': currentPlayer.currentAttempt + 1,
          'hasOpponent': hasOpponent,
          'opponentName': opponentPlayer?.playerName ?? 'Ayrıldı',
          'secretWord': game.secretWord,
          'gameId': game.gameId,
        },
      );

      // Seviye güncellemesi
      await FirebaseService.updateUserLevel(user.uid);

      print('Duello sonucu Firebase\'e kaydedildi: Score=$score, Won=$isWinner, Duration=${gameDuration.inSeconds}s');
    } catch (e) {
      print('Duello sonucu kaydetme hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWinner = game.winnerId == currentPlayer.playerId;
    final bool hasOpponent = opponentPlayer != null;
    
    // Oyun sonucunu kaydet (sadece bir kez)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _saveGameResult();
    });
    
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          'Oyun Sonucu',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildResultHeader(isWinner, hasOpponent),
            const SizedBox(height: 30),
            _buildScoreComparison(),
            const SizedBox(height: 30),
            _buildGameStats(),
            const SizedBox(height: 30),
            if (hasOpponent) _buildPlayerComparison(),
            const SizedBox(height: 30),
            _buildGameBoard(),
            const SizedBox(height: 40),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildResultHeader(bool isWinner, bool hasOpponent) {
    IconData resultIcon;
    String resultTitle;
    String resultSubtitle;
    Color resultColor;

    if (!hasOpponent) {
      resultIcon = Icons.person_off;
      resultTitle = '🚫 Rakip Ayrıldı';
      resultSubtitle = 'Oyun iptal edildi';
      resultColor = Colors.orange;
    } else if (isWinner) {
      resultIcon = Icons.emoji_events;
      resultTitle = '🏆 TEBRİKLER!';
      resultSubtitle = 'Rakibinizi yendiniz!';
      resultColor = Colors.green;
    } else if (game.winnerId != null) {
      resultIcon = Icons.sentiment_dissatisfied;
      resultTitle = '😔 Kaybettiniz';
      resultSubtitle = 'Bir dahaki sefere!';
      resultColor = Colors.red;
    } else {
      resultIcon = Icons.timer_off;
      resultTitle = '⏰ Berabere';
      resultSubtitle = 'Kimse bulamadı';
      resultColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            resultColor.withOpacity(0.8),
            resultColor.withOpacity(0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: resultColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            resultIcon,
            size: 80,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          Text(
            resultTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            resultSubtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
            ),
          ),
          if (game.winnerId == null && game.secretWord.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Kelime: ${game.secretWord}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreComparison() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart, color: Colors.blue.shade400),
              const SizedBox(width: 8),
              const Text(
                'Skor Karşılaştırması',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildPlayerScore(
                  name: playerName,
                  attempts: currentPlayer.currentAttempt + 1,
                  isWinner: game.winnerId == currentPlayer.playerId,
                  isCurrentPlayer: true,
                ),
              ),
              const SizedBox(width: 16),
              const Text('VS', 
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              Expanded(
                child: _buildPlayerScore(
                  name: opponentPlayer?.playerName ?? 'Rakip Ayrıldı',
                  attempts: (opponentPlayer?.currentAttempt ?? -1) + 1,
                  isWinner: game.winnerId == opponentPlayer?.playerId,
                  isCurrentPlayer: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerScore({
    required String name,
    required int attempts,
    required bool isWinner,
    required bool isCurrentPlayer,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentPlayer ? Colors.blue.shade600.withOpacity(0.2) : const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: isWinner 
          ? Border.all(color: Colors.green, width: 2)
          : (isCurrentPlayer ? Border.all(color: Colors.blue.shade600) : null),
      ),
      child: Column(
        children: [
          Text(
            name,
            style: TextStyle(
              color: isCurrentPlayer ? Colors.blue.shade200 : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            attempts > 6 ? 'Bulamadı' : '$attempts/6',
            style: TextStyle(
              color: isWinner ? Colors.green : Colors.grey,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          if (isWinner)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '🏆 KAZANDI',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGameStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.green.shade400),
              const SizedBox(width: 8),
              const Text(
                'Oyun İstatistikleri',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildStatRow('Oyun Süresi:', _formatDuration(gameDuration)),
          _buildStatRow('Gizli Kelime:', game.secretWord),
          _buildStatRow('Toplam Tahmin:', '${currentPlayer.currentAttempt}'),
          _buildStatRow('Başlama Saati:', _formatTime(game.startedAt)),
          if (game.finishedAt != null)
            _buildStatRow('Bitiş Saati:', _formatTime(game.finishedAt)),
          _buildStatRow('Oyun Modu:', 'Hızlı Düello'),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerComparison() {
    if (opponentPlayer == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people, color: Colors.purple.shade400),
              const SizedBox(width: 8),
              const Text(
                'Detaylı Karşılaştırma',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildComparisonRow('Doğru Tahmin Sayısı', 
            _countCorrectGuesses(currentPlayer), 
            _countCorrectGuesses(opponentPlayer!)
          ),
          _buildComparisonRow('Kısmen Doğru Tahmin', 
            _countPartialGuesses(currentPlayer), 
            _countPartialGuesses(opponentPlayer!)
          ),
          _buildComparisonRow('Toplam Tahmin', 
            currentPlayer.currentAttempt, 
            opponentPlayer!.currentAttempt
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(String label, int playerValue, int opponentValue) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$playerValue',
                    style: TextStyle(
                      color: Colors.blue.shade200,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text('vs', style: TextStyle(color: Colors.grey)),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$opponentValue',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGameBoard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.grid_on, color: Colors.orange.shade400),
              const SizedBox(width: 8),
              const Text(
                'Tahmin Geçmişi',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildPlayerGuesses('Senin Tahminlerin', currentPlayer),
              ),
              const SizedBox(width: 16),
              if (opponentPlayer != null)
                Expanded(
                  child: _buildPlayerGuesses('Rakip Tahminleri', opponentPlayer!),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerGuesses(String title, DuelPlayer player) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 180,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              childAspectRatio: 1,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: 30,
            itemBuilder: (context, index) {
              final row = index ~/ 5;
              final col = index % 5;
              
              String letter = '';
              Color boxColor = const Color(0xFF3A3A3C);
              
              if (row < player.currentAttempt) {
                letter = player.guesses[row][col] == '_' ? '' : player.guesses[row][col];
                boxColor = _getColorFromString(player.guessColors[row][col]);
              }
              
              return Container(
                decoration: BoxDecoration(
                  color: boxColor,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Center(
                  child: Text(
                    letter,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
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

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.home, color: Colors.white),
            label: const Text(
              'Ana Menüye Dön',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () {
              // Direkt yeni düello sayfasına git
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const DuelPage()),
              );
            },
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text(
              'Tekrar Oyna',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Yardımcı metodlar
  Color _getColorFromString(String colorString) {
    switch (colorString) {
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orange;
      case 'grey':
        return Colors.grey;
      default:
        return const Color(0xFF3A3A3C);
    }
  }

  int _countCorrectGuesses(DuelPlayer player) {
    int count = 0;
    for (int i = 0; i < player.currentAttempt; i++) {
      for (int j = 0; j < 5; j++) {
        if (player.guessColors[i][j] == 'green') {
          count++;
        }
      }
    }
    return count;
  }

  int _countPartialGuesses(DuelPlayer player) {
    int count = 0;
    for (int i = 0; i < player.currentAttempt; i++) {
      for (int j = 0; j < 5; j++) {
        if (player.guessColors[i][j] == 'orange') {
          count++;
        }
      }
    }
    return count;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return 'Bilinmiyor';
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
} 