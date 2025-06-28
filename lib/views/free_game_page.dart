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

// Serbest oyun sayfası

class FreeGamePage extends StatefulWidget {
  final VoidCallback toggleTheme;

  const FreeGamePage({Key? key, required this.toggleTheme}) : super(key: key);

  @override
  State<FreeGamePage> createState() => _FreeGamePageState();
}

class _FreeGamePageState extends State<FreeGamePage> {
  late WordleViewModel _viewModel;
  late VoidCallback _listener;
  bool _hasShownDialog = false;
  
  // Oyun ayarları
  bool _isTimerEnabled = false;
  int _timerDuration = 300; // 5 dakika varsayılan (saniye)
  int _wordLength = 5; // 5 harf varsayılan

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
    
    // Serbest mod ayarını yap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.resetGame(
        mode: GameMode.unlimited,
        customWordLength: _wordLength,
        customTimerDuration: _isTimerEnabled ? _timerDuration : null,
      );
    });
  }

  @override
  void dispose() {
    _viewModel.removeListener(_listener);
    super.dispose();
  }

  void _showResultDialog(WordleViewModel viewModel) {
    bool timeOut = viewModel.totalRemainingSeconds <= 0;
    bool won = viewModel.isWinner; // ViewModel'den doğru kazanma durumunu al

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
      tokensEarned = 2; // Serbest mod: 2 jeton
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
        gameType: 'Serbest Oyun',
        score: score,
        isWon: won,
        duration: gameDuration,
        additionalData: {
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
          appBar: AppBar(
            title: const Text(
              '🎯 Serbest Oyun',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
            elevation: 0,
            actions: [
              // Ayarlar butonu
              IconButton(
                icon: const Icon(Icons.settings_rounded),
                onPressed: () => _showGameSettings(viewModel),
                tooltip: 'Oyun Ayarları',
              ),
              // Yenile butonu
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () {
                  setState(() {
                    _hasShownDialog = false;
                  });
                  _applyGameSettings(viewModel);
                },
                tooltip: 'Yeni Oyun',
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
                            children: [
                // Kompakt kontrol paneli
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Row(
                    children: [
                      // Jeton
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text('${viewModel.userTokens}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold , color: Colors.black)),
                          ],
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Oyun bilgileri
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                                                         _buildCompactStat('🎯', '${viewModel.currentAttempt + 1}/6'),
                            _buildCompactStat('🔤', '${viewModel.currentWordLength}'),
                                                         if (_isTimerEnabled)
                               _buildCompactStat('⏱️', '${viewModel.totalRemainingSeconds}s'),
                          ],
                        ),
                      ),
                      
                      // İpucu butonu
                      if (!viewModel.gameOver)
                        IconButton(
                          onPressed: () => _showHintDialog(viewModel),
                          icon: const Icon(Icons.lightbulb_outline, size: 20),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.orange.shade100,
                            foregroundColor: Colors.orange.shade700,
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Tahmin ızgarası
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ShakeWidget(
                      shake: viewModel.needsShake,
                      onShakeComplete: () => viewModel.resetShake(),
                      child: GuessGrid(screenWidth: screenWidth),
                    ),
                  ),
                ),
                
                // Klavye
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SizedBox(
                    height: 200,
                    child: const KeyboardWidget(),
                  ),
                ),
              ],
            ),
          ),
        ));
      },
    );
  }

  Widget _buildCompactStat(String icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }



  void _showHintDialog(WordleViewModel viewModel) {
    if (viewModel.userTokens < 3) {
      // Yetersiz jeton durumu
      _showStyledDialog(
        title: '💰 Yetersiz Jeton',
        content: 'İpucu almak için en az 3 jetonunuz olmalı.\n\nŞu anki jetonlarınız: ${viewModel.userTokens} 🪙',
        primaryButtonText: 'Tamam',
        primaryButtonColor: Colors.grey.shade600,
        onPrimaryPressed: () => Navigator.of(context).pop(),
      );
      return;
    }

    // Açılabilecek harfler var mı kontrol et
    final availablePositions = <int>[];
    for (int i = 0; i < viewModel.currentWordLength; i++) {
      if (!viewModel.revealedHints.contains(i)) {
        availablePositions.add(i);
      }
    }

    if (availablePositions.isEmpty) {
      // Tüm harfler açılmış
      _showStyledDialog(
        title: '🎯 Tüm Harfler Açık',
        content: 'Bu kelimede artık açılacak harf kalmadı.\n\nTüm harfler zaten görünüyor!',
        primaryButtonText: 'Tamam',
        primaryButtonColor: Colors.blue.shade600,
        onPrimaryPressed: () => Navigator.of(context).pop(),
      );
      return;
    }

    // İpucu alma onayı
    _showStyledDialog(
      title: '💡 Harf İpucu',
      content: 'Rastgele bir harfi açmak için 3 jeton harcamak istiyor musunuz?\n\n💰 Mevcut jetonlarınız: ${viewModel.userTokens}\n💳 Harcanacak: 3 jeton\n💰 Kalan: ${viewModel.userTokens - 3} jeton',
      primaryButtonText: 'İpucu Al',
      primaryButtonColor: Colors.orange.shade600,
      secondaryButtonText: 'İptal',
      secondaryButtonColor: Colors.grey.shade600,
      onPrimaryPressed: () async {
        Navigator.of(context).pop();
        await _buyLetterHint(viewModel);
      },
      onSecondaryPressed: () => Navigator.of(context).pop(),
    );
  }

  void _showStyledDialog({
    required String title,
    required String content,
    required String primaryButtonText,
    required Color primaryButtonColor,
    required VoidCallback onPrimaryPressed,
    String? secondaryButtonText,
    Color? secondaryButtonColor,
    VoidCallback? onSecondaryPressed,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 16,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Theme.of(context).colorScheme.surface.withOpacity(0.8),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Başlık
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                // İçerik
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 24),
                
                // Butonlar
                Row(
                  children: [
                    if (secondaryButtonText != null) ...[
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onSecondaryPressed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: secondaryButtonColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            secondaryButtonText,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onPrimaryPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryButtonColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        child: Text(
                          primaryButtonText,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Harf ipucu satın al
  Future<void> _buyLetterHint(WordleViewModel viewModel) async {
    // Loading indicator göster
    _showLoadingDialog();
    
    bool success = await viewModel.buyLetterHint();
    
    // Loading dialog'unu kapat
    if (mounted) Navigator.of(context).pop();
    
    if (success) {
      if (mounted) {
        _showStyledDialog(
          title: '🎉 İpucu Alındı!',
          content: 'Rastgele bir harf açıldı!\n\n✨ Oyun tahtasında sarı renkle görüntülenen ipucu harfini kontrol edin.\n\n💰 3 jeton harcandı\n💰 Kalan jetonlarınız: ${viewModel.userTokens}',
          primaryButtonText: 'Harika!',
          primaryButtonColor: Colors.green.shade600,
          onPrimaryPressed: () => Navigator.of(context).pop(),
        );
      }
    } else {
      if (mounted) {
        _showStyledDialog(
          title: '❌ İpucu Alınamadı',
          content: 'İpucu alırken bir sorun oluştu.\n\nMümkün nedenler:\n• Yetersiz jeton\n• Tüm harfler zaten açılmış\n• Bağlantı sorunu',
          primaryButtonText: 'Tamam',
          primaryButtonColor: Colors.red.shade600,
          onPrimaryPressed: () => Navigator.of(context).pop(),
        );
      }
    }
  }

  /// Loading dialog göster
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Theme.of(context).colorScheme.surface,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
                const SizedBox(height: 16),
                Text(
                  '💡 İpucu hazırlanıyor...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
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

  /// Oyun ayarları dialog'unu göster
  void _showGameSettings(WordleViewModel viewModel) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.tune_rounded, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Serbest Oyun Ayarları'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Kelime uzunluğu seçimi
                  const Text('🔤 Kelime Uzunluğu', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [4, 5, 6, 7, 8].map((length) {
                      return ChoiceChip(
                        label: Text('$length', style: const TextStyle(fontSize: 12)),
                        selected: _wordLength == length,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() {
                              _wordLength = length;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 16),
                  const Divider(),
                  
                  // Süre ayarları
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('⏱️ Süre Sınırı'),
                    subtitle: Text(_isTimerEnabled ? '${(_timerDuration/60).round()} dakika süre' : 'Süresiz oyna'),
                    value: _isTimerEnabled,
                    onChanged: (value) {
                      setDialogState(() {
                        _isTimerEnabled = value;
                      });
                    },
                  ),
                  
                  // Süre seçici
                  if (_isTimerEnabled) ...[
                    const SizedBox(height: 8),
                    Text('Süre: ${(_timerDuration/60).round()} dakika'),
                    Slider(
                      value: _timerDuration / 60,
                      min: 1,
                      max: 15,
                      divisions: 14,
                      label: '${(_timerDuration/60).round()} dk',
                      onChanged: (value) {
                        setDialogState(() {
                          _timerDuration = (value * 60).round();
                        });
                      },
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _applyGameSettings(viewModel);
                  },
                  child: const Text('Uygula'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Oyun ayarlarını uygula
  void _applyGameSettings(WordleViewModel viewModel) {
    setState(() {
      _hasShownDialog = false;
    });
    
    // Ayarları uygulayarak yeni oyun başlat
    viewModel.resetGame(
      mode: GameMode.unlimited,
      customWordLength: _wordLength,
      customTimerDuration: _isTimerEnabled ? _timerDuration : null,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎯 ${_wordLength} harfli ${_isTimerEnabled ? '${(_timerDuration/60).round()} dakika süreli' : 'süresiz'} oyun başladı!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
} 