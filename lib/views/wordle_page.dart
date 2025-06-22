// lib/views/wordle_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../viewmodels/wordle_viewmodel.dart';
import '../widgets/shake_widget.dart';
import '../widgets/keyboard_widget.dart';
import '../services/firebase_service.dart';

class WordlePage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final GameMode gameMode;

  const WordlePage({Key? key, required this.toggleTheme, required this.gameMode}) : super(key: key);

  @override
  State<WordlePage> createState() => _WordlePageState();
}

class _WordlePageState extends State<WordlePage> {
  late WordleViewModel _viewModel;
  late VoidCallback _listener;
  bool _hasShownDialog = false; // Dialog gösterim durumunu izlemek için

  @override
  void initState() {
    super.initState();
    _viewModel = Provider.of<WordleViewModel>(context, listen: false);
    
    _listener = () {
      if (_viewModel.gameOver && !_hasShownDialog) {
        _hasShownDialog = true; // Dialogu gösteriyoruz
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showResultDialog(_viewModel);
        });
      }
    };
    _viewModel.addListener(_listener);
    
    // Oyun modunu build tamamlandıktan sonra ayarla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.resetGame(mode: widget.gameMode);
    });
  }

  @override
  void dispose() {
    _viewModel.removeListener(_listener);
    super.dispose();
  }

  void _showResultDialog(WordleViewModel viewModel) {
    bool won = viewModel.guesses[viewModel.currentAttempt].join().toTurkishUpperCase() == viewModel.secretWord;
    bool timeOut = viewModel.totalRemainingSeconds <= 0;

    // Oyun sonucunu Firebase'e kaydet
    _saveGameResult(viewModel, won, timeOut);
    
    // Başarı tablosu istatistiklerini güncelle
    viewModel.updateLeaderboardStats(context);

    String title;
    String content;
    List<Widget> actions = [];

    if (timeOut && !won) {
      title = 'Süre Doldu!';
      content = 'Doğru kelime: ${viewModel.secretWord}';
      actions.add(
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _showReplayOrMainMenuDialog();
          },
          child: const Text('Yeniden Başla'),
        ),
      );
      actions.add(
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _navigateToMainMenu();
          },
          child: const Text('Ana Menü'),
        ),
      );
    } else if (won) {
      if (viewModel.gameMode == GameMode.challenge && viewModel.currentLevel == viewModel.maxLevel) {
        // Zorlu modda maksimum seviyeye ulaşıldı
        _showMaxLevelDialog();
        return; // Fonksiyondan çık
      } else if (viewModel.gameMode == GameMode.challenge) {
        // Zorlu modda sonraki seviyeye geç
        title = 'Tebrikler!';
        actions.add(
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Mevcut dialogu kapat
              _showNextLevelDialog();
            },
            child: const Text('Devam'),
          ),
        );
      } else {
        // Günlük modda kazandınız
        title = 'Tebrikler!';
        content = 'Günlük kelimeyi doğru bildiniz!';
        actions.add(
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToMainMenu();
            },
            child: const Text('Ana Menü'),
          ),
        );
        actions.add(
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Share.share(viewModel.generateShareText());
            },
            child: const Text('Paylaş'),
          ),
        );
      }
    } else {
      // Kaybettiniz
      title = 'Kaybettiniz!';
      content = 'Doğru kelime: ${viewModel.secretWord}';
      actions.add(
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _showReplayOrMainMenuDialog();
          },
          child: const Text('Yeniden Başla'),
        ),
      );
      actions.add(
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _navigateToMainMenu();
          },
          child: const Text('Ana Menü'),
        ),
      );
    }

    showDialog(
      context: context,
      barrierDismissible: false, // Kullanıcının dışarıya tıklayarak kapatmasını engeller
      builder: (_) => AlertDialog(
        title: Text(title),
        actions: actions,
      ),
    );
  }

  void _showNextLevelDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Kullanıcının dışarıya tıklayarak kapatmasını engeller
      builder: (_) => AlertDialog(
        title: const Text('Seviye Atladınız!'),
        content: const Text('Bir sonraki seviyeye geçmek ister misiniz?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Mevcut dialogu kapat
              _viewModel.goToNextLevel();
              setState(() {
                _hasShownDialog = false; // Yeni seviyede dialog gösterimini tekrar etkinleştir
              });
            },
            child: const Text('Devam'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToMainMenu();
            },
            child: const Text('Ana Menü'),
          ),
        ],
      ),
    );
  }

  void _showMaxLevelDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Kullanıcının dışarıya tıklayarak kapatmasını engeller
      builder: (_) => AlertDialog(
        title: const Text('Maksimum Seviyeye Ulaşıldı!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.celebration,
              color: Colors.blue,
              size: 50,
            ),
            const SizedBox(height: 10),
            const Text(
              'Tüm seviyeleri tamamladınız. Tebrikler!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToMainMenu();
            },
            child: const Text('Ana Menü'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _hasShownDialog = false; // Yeni oyun için dialog gösterimini tekrar etkinleştir
              });
              _viewModel.resetGame();
            },
            child: const Text('Tekrar Oyna'),
          ),
        ],
      ),
    );
  }

  void _showReplayOrMainMenuDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Kullanıcının dışarıya tıklayarak kapatmasını engeller
      builder: (_) => AlertDialog(
        title: const Text('Ne Yapmak İstersiniz?'),
        content: const Text('Oyunu yeniden başlatmak veya ana menüye dönmek ister misiniz?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _hasShownDialog = false; // Yeni oyun için dialog gösterimini tekrar etkinleştir
              });
              _viewModel.resetGame();
            },
            child: const Text('Yeniden Başla'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToMainMenu();
            },
            child: const Text('Ana Menü'),
          ),
        ],
      ),
    );
  }

void _navigateToMainMenu() {
  debugPrint('Ana Menüye Dönüldü');
  Navigator.pushReplacementNamed(context, '/'); // Ana menü rotası olarak '/' kullanıldı
}

  Future<void> _saveGameResult(WordleViewModel viewModel, bool won, bool timeOut) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Oyun süresini hesapla
      final gameDuration = Duration(
        seconds: WordleViewModel.totalGameSeconds - viewModel.totalRemainingSeconds,
      );

      // Skor hesapla (basit algoritma)
      int score = 0;
      if (won) {
        // Kazanılan oyunlar için skor hesaplama
        final attemptsUsed = viewModel.currentAttempt + 1;
        final timeBonus = viewModel.totalRemainingSeconds * 2;
        final attemptBonus = (WordleViewModel.maxAttempts - attemptsUsed) * 50;
        score = 100 + timeBonus + attemptBonus;
      } else if (!timeOut) {
        // Kaybedilen ama zaman aşımı olmayan oyunlar için az puan
        score = viewModel.currentAttempt * 10;
      }

      // Firebase'e kaydet
      await FirebaseService.saveGameResult(
        uid: user.uid,
        gameType: viewModel.gameMode == GameMode.daily ? 'Günlük Oyun' : 'Zorlu Mod',
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

      // Seviye güncellemesi
      await FirebaseService.updateUserLevel(user.uid);

      print('Oyun sonucu Firebase\'e kaydedildi: Score=$score, Won=$won, Duration=${gameDuration.inSeconds}s');
    } catch (e) {
      print('Oyun sonucu kaydetme hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WordleViewModel>(
      builder: (context, viewModel, child) {
        final screenWidth = MediaQuery.of(context).size.width;

        // Toplam horizontal padding ve margin hesaplama
        double totalHorizontalPadding = 10.0 * 2; // Padding.symmetric(horizontal: 10)
        double totalBoxMargin = 4.0 * viewModel.currentWordLength; // margin.all(2) her kutu için

        // Kullanılabilir genişliği hesaplama
        double availableWidth = screenWidth - totalHorizontalPadding - totalBoxMargin - 2.0; // Küçük bir epsilon ekleyin

        // Kutucuk genişliğini hesaplama
        double boxSize = availableWidth / viewModel.currentWordLength;
        boxSize = boxSize.clamp(30.0, 60.0); // Minimum ve maksimum boyutlar

        return Scaffold(
          appBar: AppBar(
            title: Text(viewModel.gameMode == GameMode.daily ? 'Günlük Oyun' : 'Zorlu Mod'),
            centerTitle: true,
            actions: [
              if (!viewModel.gameOver) // Sadece oyun sırasında zamanlayıcıyı göster
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
              IconButton(
                icon: const Icon(Icons.brightness_6),
                onPressed: widget.toggleTheme,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  setState(() {
                    _hasShownDialog = false; // Oyun sıfırlandığında dialog gösterim durumunu sıfırla
                  });
                  _viewModel.resetGame();
                },
              ),
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      // Grid ve Shake Animasyonu için
                      ShakeWidget(
                        shake: viewModel.needsShake,
                        onShakeComplete: () {
                          viewModel.resetShake();
                        },
                        child: _buildGuessGrid(viewModel, screenWidth),
                      ),
                      const SizedBox(height: 15),
                      // Klavye için KeyboardWidget'i kullanın
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: SizedBox(
                          height: 220, // Klavye yüksekliğini ayarlayın
                          child: const KeyboardWidget(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Ek Bilgiler: En İyi Süre ve Deneme
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('En İyi Süre: ${viewModel.bestTime < 9999 ? _formatTime(viewModel.bestTime) : "Yok"}'),
                                Text('En Az Deneme: ${viewModel.bestAttempts < 999 ? viewModel.bestAttempts : "Yok"}'),
                              ],
                            ),
                            if (viewModel.gameMode == GameMode.challenge) ...[
                              const SizedBox(height: 8),
                              Text('Seviye: ${viewModel.currentLevel} / ${viewModel.maxLevel}'),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildGuessGrid(WordleViewModel viewModel, double screenWidth) {
    // Toplam horizontal padding ve margin hesaplama
    double totalHorizontalPadding = 10.0 * 2; // Padding.symmetric(horizontal: 10)
    double totalBoxMargin = 4.0 * viewModel.currentWordLength; // margin.all(2) her kutu için

    // Kullanılabilir genişliği hesaplama
    double availableWidth = screenWidth - totalHorizontalPadding - totalBoxMargin - 2.0; // Küçük bir epsilon ekleyin

    // Kutucuk genişliğini hesaplama
    double boxSize = availableWidth / viewModel.currentWordLength;
    boxSize = boxSize.clamp(30.0, 60.0); // Minimum ve maksimum boyutlar

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(WordleViewModel.maxAttempts, (row) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(viewModel.currentWordLength, (col) {
                return Container(
                  margin: const EdgeInsets.all(2),
                  width: boxSize,
                  height: boxSize,
                  decoration: BoxDecoration(
                    color: viewModel.getBoxColor(row, col),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade700),
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown, // Metni kutuya sığdır
                    child: Text(
                      viewModel.guesses[row][col],
                      style: TextStyle(
                        fontSize: boxSize * 0.5, // Dinamik font size
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}";
  }
}