import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../viewmodels/wordle_viewmodel.dart';
import '../widgets/shake_widget.dart';
import '../widgets/keyboard_widget.dart';
import '../widgets/guess_grid.dart';
import '../widgets/game_stats.dart';
import '../services/firebase_service.dart';
import 'wordle_result_page.dart';

// Zorlu mod oyun sayfası

class ChallengeGamePage extends StatefulWidget {
  final VoidCallback toggleTheme;

  const ChallengeGamePage({Key? key, required this.toggleTheme}) : super(key: key);

  @override
  State<ChallengeGamePage> createState() => _ChallengeGamePageState();
}

class _ChallengeGamePageState extends State<ChallengeGamePage> {
  late WordleViewModel _viewModel;
  late VoidCallback _listener;
  bool _hasShownDialog = false;

  @override
  void initState() {
    super.initState();
    _viewModel = Provider.of<WordleViewModel>(context, listen: false);
    
    _listener = () {
      if (_viewModel.gameOver && !_hasShownDialog) {
        _hasShownDialog = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showResultDialog(_viewModel);
        });
      }
    };
    _viewModel.addListener(_listener);
    
    // Zorlu mod ayarını yap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.resetGame(mode: GameMode.challenge);
    });
  }

  @override
  void dispose() {
    _viewModel.removeListener(_listener);
    super.dispose();
  }

  void _showResultDialog(WordleViewModel viewModel) {
    bool won = viewModel.isWinner; // ViewModel'den doğru kazanma durumunu al
    bool timeOut = viewModel.totalRemainingSeconds <= 0;

    // Oyun sonucunu Firebase'e kaydet
    _saveGameResult(viewModel, won, timeOut);
    
    // Başarı tablosu istatistiklerini güncelle
    viewModel.updateLeaderboardStats(context);

    // Skor ve jeton hesaplama - Zorlu modda seviyeye göre artırılmış ödül
    int score = 0;
    int tokensEarned = 0;
    
    if (won) {
      final attemptsUsed = viewModel.currentAttempt + 1;
      final timeBonus = viewModel.totalRemainingSeconds * 3; // Zorlu modda daha yüksek zaman bonusu
      final attemptBonus = (WordleViewModel.maxAttempts - attemptsUsed) * 75; // Daha yüksek deneme bonusu
      final levelBonus = viewModel.currentLevel * 100; // Seviye bonusu
      score = 200 + timeBonus + attemptBonus + levelBonus; // Başlangıç puanı daha yüksek
      
      // Jeton hesaplama - seviyeye göre artan jeton (2, 4, 6, 8, 10)
      tokensEarned = viewModel.currentLevel * 2;
    } else if (!timeOut) {
      score = viewModel.currentAttempt * 15; // Daha yüksek temel puan
    }

    // Sonuç sayfasına yönlendir
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => WordleResultPage(
          isWinner: won,
          isTimeOut: timeOut,
          secretWord: viewModel.secretWord,
          attempts: viewModel.currentAttempt + 1,
          timeSpent: WordleViewModel.totalGameSeconds - viewModel.totalRemainingSeconds,
          gameMode: viewModel.gameMode,
          currentLevel: viewModel.currentLevel,
          maxLevel: viewModel.maxLevel,
          shareText: viewModel.generateShareText(),
          tokensEarned: tokensEarned,
          score: score,
        ),
      ),
    );
  }

  Future<void> _saveGameResult(WordleViewModel viewModel, bool won, bool timeOut) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final gameDuration = Duration(
        seconds: WordleViewModel.totalGameSeconds - viewModel.totalRemainingSeconds,
      );

      int score = 0;
      if (won) {
        final attemptsUsed = viewModel.currentAttempt + 1;
        final timeBonus = viewModel.totalRemainingSeconds * 3;
        final attemptBonus = (WordleViewModel.maxAttempts - attemptsUsed) * 75;
        final levelBonus = viewModel.currentLevel * 100;
        score = 200 + timeBonus + attemptBonus + levelBonus;
      } else if (!timeOut) {
        score = viewModel.currentAttempt * 15;
      }

      await FirebaseService.saveGameResult(
        uid: user.uid,
        gameType: 'Zorlu Mod',
        score: score,
        isWon: won,
        duration: gameDuration,
        additionalData: {
          'level': viewModel.currentLevel,
          'attempts': viewModel.currentAttempt + 1,
          'timeOut': timeOut,
          'secretWord': viewModel.secretWord,
          'wordLength': viewModel.currentWordLength,
        },
      );

      await FirebaseService.updateUserLevel(user.uid);
    } catch (e) {
      print('Oyun sonucu kaydetme hatası: $e');
    }
  }

  Future<bool> _showExitConfirmDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade800,
          title: const Text(
            '⚔️ Zorlu Moddan Çık',
            style: TextStyle(color: Colors.red),
          ),
          content: const Text(
            'Zorlu moddan çıkmak istediğinizden emin misiniz?\n\n24 saatlik özel hakkınızı kaybedeceksiniz!',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'İptal',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Çık',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WordleViewModel>(
      builder: (context, viewModel, child) {
        final screenWidth = MediaQuery.of(context).size.width;

        return PopScope(
          canPop: false,
          onPopInvoked: (didPop) async {
            if (didPop) return;
            final shouldPop = await _showExitConfirmDialog();
            if (shouldPop && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            backgroundColor: const Color(0xFF0A0A0A),
            appBar: AppBar(
              backgroundColor: const Color(0xFF1A1A1D),
              title: const Text('⚔️ ZORLU MOD ⚔️', style: TextStyle(color: Colors.red)),
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.warning_amber, color: Colors.red),
                onPressed: _showExitWarning,
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Seviye ${viewModel.currentLevel}/${viewModel.maxLevel}',
                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Bilgi paneli
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.red.shade900, Colors.orange.shade800],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            '🔥 GÜNDE TEK ŞANS! 🔥',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${viewModel.currentWordLength} harfli kelime - ${viewModel.currentLevel * 2} jeton ödülü',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    
                    // Grid
                    ShakeWidget(
                      shake: viewModel.needsShake,
                      onShakeComplete: () {
                        viewModel.resetShake();
                      },
                      child: GuessGrid(screenWidth: screenWidth),
                    ),
                    const SizedBox(height: 15),
                    
                    // Klavye
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: SizedBox(
                        height: 220,
                        child: const KeyboardWidget(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showExitWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ UYARI!', style: TextStyle(color: Colors.red)),
        content: const Text('Zorlu moddan çıkarsan 24 saatlik hakkını kaybedersin!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Devam Et'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Çıkış Yap', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
} 