// lib/views/wordle_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../viewmodels/wordle_viewmodel.dart';
import '../widgets/shake_widget.dart';
import '../widgets/keyboard_widget.dart';
import '../widgets/guess_grid.dart';
import '../services/firebase_service.dart';

import 'wordle_result_page.dart';

// Wordle oyun sayfası

class WordlePage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final GameMode gameMode;
  final String? themeId;

  const WordlePage({Key? key, required this.toggleTheme, required this.gameMode, this.themeId}) : super(key: key);

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
      _viewModel.resetGame(mode: widget.gameMode, themeId: widget.themeId);
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

    // Skor ve jeton hesaplama
    int score = 0;
    int tokensEarned = 0;
    
    if (won) {
      final attemptsUsed = viewModel.currentAttempt + 1;
      final timeBonus = viewModel.totalRemainingSeconds * 2;
      final attemptBonus = (WordleViewModel.maxAttempts - attemptsUsed) * 50;
      score = 100 + timeBonus + attemptBonus;
      
      // Jeton hesaplama - zorlu modda seviyeye göre artan jeton
              if (viewModel.gameMode == GameMode.unlimited) {
          tokensEarned = 2; // Serbest mod: 2 jeton
      } else if (viewModel.gameMode == GameMode.challenge) {
        // Zorlu mod: seviyeye göre artan jeton (2, 4, 6, 8, 10)
        tokensEarned = viewModel.currentLevel * 2;
      } else {
        tokensEarned = 1; // Diğer modlar: 1 jeton
      }
    } else if (!timeOut) {
      score = viewModel.currentAttempt * 10;
    }

    // Yeni sonuç sayfasına yönlendir
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
        gameType: viewModel.gameMode == GameMode.unlimited ? 'Serbest Oyun' : 'Zorlu Mod',
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

        // Toplam horizontal padding ve margin hesaplama
        double totalHorizontalPadding = 10.0 * 2; // Padding.symmetric(horizontal: 10)
        double totalBoxMargin = 4.0 * viewModel.currentWordLength; // margin.all(2) her kutu için

        // Kullanılabilir genişliği hesaplama
        double availableWidth = screenWidth - totalHorizontalPadding - totalBoxMargin - 2.0; // Küçük bir epsilon ekleyin

        // Kutucuk genişliğini hesaplama
        double boxSize = availableWidth / viewModel.currentWordLength;
        boxSize = boxSize.clamp(30.0, 60.0); // Minimum ve maksimum boyutlar

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
            backgroundColor: viewModel.gameMode == GameMode.challenge 
              ? const Color(0xFF0A0A0A) // Zorlu mod için siyah arkaplan
              : null,
            appBar: _buildAppBar(viewModel),
            body: SafeArea(
              child: viewModel.gameMode == GameMode.challenge
                ? WillPopScope(
                    onWillPop: () async {
                      _showChallengeExitWarning(viewModel);
                      return false; // Geri gitmeyi engelle
                    },
                    child: _buildChallengeBody(viewModel, screenWidth),
                  )
                : _buildNormalBody(viewModel, screenWidth),
            ),
          ),
        );
      },
    );
  }

     PreferredSizeWidget _buildAppBar(WordleViewModel viewModel) {
     return AppBar(
      title: Text(_getGameModeTitle(viewModel.gameMode)),
      centerTitle: true,
      leading: viewModel.gameMode == GameMode.challenge 
        ? IconButton(
            icon: const Icon(Icons.warning_amber, color: Colors.red),
            onPressed: () => _showChallengeExitWarning(viewModel),
            tooltip: 'Çıkış Uyarısı',
          )
        : null,
      actions: [
        // Jeton göstergesi
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
              const SizedBox(width: 4),
              Text(
                '${viewModel.userTokens}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        // İpucu butonu - zorlu modda gösterme
        if (!viewModel.gameOver && viewModel.gameMode != GameMode.challenge)
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            onPressed: () => _showHintDialog(viewModel),
            tooltip: 'Harf İpucu (1 🪙)',
          ),
        // Zamanlayıcı - zorlu modda gösterme
        if (!viewModel.gameOver && viewModel.gameMode != GameMode.challenge)
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
        // Yenile butonu - zorlu modda gösterme
        if (viewModel.gameMode != GameMode.challenge)
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _hasShownDialog = false;
              });
              _viewModel.resetGame();
            },
          ),
      ],
    );
  }

  Widget _buildNormalBody(WordleViewModel viewModel, double screenWidth) {
    return LayoutBuilder(
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
                child: GuessGrid(screenWidth: screenWidth),
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
    );
  }

  Widget _buildChallengeBody(WordleViewModel viewModel, double screenWidth) {
    return LayoutBuilder(
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
                child: GuessGrid(screenWidth: screenWidth),
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
    );
  }



  String _formatTime(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}";
  }

  String _getGameModeTitle(GameMode gameMode) {
    switch (gameMode) {
      case GameMode.unlimited:
        return 'Serbest Oyun';
      case GameMode.challenge:
        return '⚔️ ZORLU MOD ⚔️';
      case GameMode.timeRush:
        return 'Zamana Karşı';
      case GameMode.themed:
        return 'Tema Modu';
      default:
        return 'Oyun';
    }
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
            
            // Harf İpucu (Sarı)
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
            
            const SizedBox(height: 12),
            
            // Yer İpucu (Yeşil)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.place, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text('Yer İpucu', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('Yanlış yerdeki harfi gösterir', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('7 🪙'),
                      ElevatedButton(
                        onPressed: viewModel.userTokens >= 7
                            ? () async {
                                Navigator.pop(context);
                                await _buyPositionHint(viewModel);
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
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

  /// Harf ipucu satın al (sarı - 3 jeton)
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
  
  /// Yer ipucu satın al (yeşil - 7 jeton)
  Future<void> _buyPositionHint(WordleViewModel viewModel) async {
    bool success = await viewModel.buyPositionHint();
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Yer ipucu alındı! (7 jeton harcandı)'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Yer ipucu alınamadı! Yetersiz jeton veya uygun harf yok.'),
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

  void _showChallengeExitWarning(WordleViewModel viewModel) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // Android geri tuşunu engelle
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A1D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.red.shade400, width: 3),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade400, Colors.red.shade600],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'ÇIKIŞ UYARISI!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          content: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2A2A2A),
                  const Color(0xFF1A1A1D),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade400.withOpacity(0.3), width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade400, width: 1),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        '⚠️ DİKKAT ⚠️',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Zorlu moddan çıkarsan 24 saatlik hakkını kaybedersin!\n\nBu özel mod sadece günde 1 kez oynanabilir.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade800, Colors.orange.shade600],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '💡 Emin misin? Bu kararını geri alamazsın!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'DEVAM ET',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Dialog'u kapat
                Navigator.pop(context); // WordlePage'den çık
                // Hakkı kaybet
                viewModel.resetGame();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'ÇIKIŞ YAP',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}