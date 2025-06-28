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


class ThemedGamePage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final String themeId;

  const ThemedGamePage({
    Key? key, 
    required this.toggleTheme, 
    required this.themeId,
  }) : super(key: key);

  @override
  State<ThemedGamePage> createState() => _ThemedGamePageState();
}

class _ThemedGamePageState extends State<ThemedGamePage> {
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
    
    // Tema modu ayarını yap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.resetGame(mode: GameMode.themed, themeId: widget.themeId);
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

    // Skor ve jeton hesaplama
    int score = 0;
    int tokensEarned = 0;
    
    if (won) {
      final attemptsUsed = viewModel.currentAttempt + 1;
      final timeBonus = viewModel.totalRemainingSeconds * 2;
      final attemptBonus = (WordleViewModel.maxAttempts - attemptsUsed) * 50;
      score = 100 + timeBonus + attemptBonus;
      tokensEarned = 2; // Tema modu: 2 jeton
    } else if (!timeOut) {
      score = viewModel.currentAttempt * 10;
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
        final timeBonus = viewModel.totalRemainingSeconds * 2;
        final attemptBonus = (WordleViewModel.maxAttempts - attemptsUsed) * 50;
        score = 100 + timeBonus + attemptBonus;
      } else if (!timeOut) {
        score = viewModel.currentAttempt * 10;
      }

      await FirebaseService.saveGameResult(
        uid: user.uid,
        gameType: 'Tema Modu',
        score: score,
        isWon: won,
        duration: gameDuration,
        additionalData: {
          'attempts': viewModel.currentAttempt + 1,
          'timeOut': timeOut,
          'secretWord': viewModel.secretWord,
          'wordLength': viewModel.currentWordLength,
          'theme': viewModel.currentTheme,
          'themeName': viewModel.themeName,
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
            '🚪 Oyundan Çık',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Oyundan çıkmak istediğinizden emin misiniz?\nİlerlemeniz kaybolacak!',
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
          backgroundColor: _getThemeColor(viewModel.currentTheme),
          appBar: AppBar(
            backgroundColor: _getThemeColor(viewModel.currentTheme).withOpacity(0.8),
            title: Text('${viewModel.themeEmoji} ${viewModel.themeName}'),
            centerTitle: true,
            actions: [
              // Jeton göstergesi
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
                    const SizedBox(width: 4),
                    Text('${viewModel.userTokens}'),
                  ],
                ),
              ),
              // İpucu butonu
              if (!viewModel.gameOver)
                IconButton(
                  icon: const Icon(Icons.lightbulb_outline),
                  onPressed: () => _showHintDialog(viewModel),
                  tooltip: 'Harf İpucu (3 🪙)',
                ),
              // Zamanlayıcı
              if (!viewModel.gameOver)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Center(
                    child: Text(
                      _formatTime(viewModel.totalRemainingSeconds),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              // Yenile butonu
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  setState(() {
                    _hasShownDialog = false;
                  });
                  _viewModel.resetGame(mode: GameMode.themed, themeId: widget.themeId);
                },
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Tema bilgi paneli
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getThemeColor(viewModel.currentTheme).withOpacity(0.8),
                        _getThemeColor(viewModel.currentTheme).withOpacity(0.6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        viewModel.themeEmoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${viewModel.themeName} kategorisinden kelimeler!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
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
                        const SizedBox(height: 16),
                        // Oyun istatistikleri
                        GameStats(viewModel: viewModel),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        );
      },
    );
  }

  Color _getThemeColor(String themeId) {
    return Colors.grey[800]!;
  }

  String _formatTime(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}";
  }

  /// İpucu dialog'unu göster
  void _showHintDialog(WordleViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lightbulb, color: Colors.amber),
            SizedBox(width: 8),
            Text('İpucu Seçenekleri'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mevcut Jetonlar: ${viewModel.userTokens} 🪙'),
            const SizedBox(height: 16),
            
            // Harf İpucu
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                      SizedBox(width: 8),
                      Text('Harf İpucu', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('Rastgele bir harfi gösterir', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('3 🪙'),
                      ElevatedButton(
                        onPressed: viewModel.userTokens >= 3 && viewModel.revealedHints.length < viewModel.currentWordLength
                            ? () async {
                                Navigator.pop(context);
                                await _buyLetterHint(viewModel);
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(80, 30),
                        ),
                        child: const Text('Al'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            if (viewModel.userTokens < 3) ...[
              const SizedBox(height: 12),
              const Text(
                'Yetersiz jeton! Reklam izleyerek ücretsiz jeton kazanabilirsiniz.',
                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ],
        ),
        actions: [
          if (viewModel.userTokens < 3)
            TextButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await _watchAdForTokens(viewModel);
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Reklam İzle'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
        ],
      ),
    );
  }

  /// Harf ipucu satın al
  Future<void> _buyLetterHint(WordleViewModel viewModel) async {
    bool success = await viewModel.buyLetterHint();
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Harf ipucu alındı! (3 jeton harcandı)'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ İpucu alınamadı! Yetersiz jeton veya tüm harfler açılmış.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Reklam izleyerek jeton kazan
  Future<void> _watchAdForTokens(WordleViewModel viewModel) async {
    bool success = await viewModel.watchAdForTokens();
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 1 jeton kazandınız!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Reklam şu anda mevcut değil!'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
} 