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

// Zamana karşı oyun sayfası

class TimeRushGamePage extends StatefulWidget {
  final VoidCallback toggleTheme;

  const TimeRushGamePage({Key? key, required this.toggleTheme}) : super(key: key);

  @override
  State<TimeRushGamePage> createState() => _TimeRushGamePageState();
}

class _TimeRushGamePageState extends State<TimeRushGamePage> with TickerProviderStateMixin {
  late WordleViewModel _viewModel;
  late VoidCallback _listener;
  bool _hasShownDialog = false;
  late AnimationController _successAnimationController;
  late Animation<double> _successScaleAnimation;
  bool _showSuccessAnimation = false;

  @override
  void initState() {
    super.initState();
    _viewModel = Provider.of<WordleViewModel>(context, listen: false);
    
    // Başarı animasyonu için controller
    _successAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _successScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _successAnimationController,
      curve: Curves.elasticOut,
    ));
    
    _listener = () {
      if (_viewModel.gameOver && !_hasShownDialog) {
        _hasShownDialog = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showResultDialog(_viewModel);
        });
      }
    };
    _viewModel.addListener(_listener);
    
    // Zamana karşı mod ayarını yap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.resetGame(mode: GameMode.timeRush);
    });
  }

  @override
  void dispose() {
    _viewModel.removeListener(_listener);
    _successAnimationController.dispose();
    super.dispose();
  }

  void _showResultDialog(WordleViewModel viewModel) {
    // Zamana karşı modda farklı sonuç hesaplama
    int wordsCompleted = viewModel.wordsGuessedCount;
    
    // Jeton hesaplama - kelime başına 2 jeton
    int tokensEarned = wordsCompleted * 2;

    // Sonuç sayfasına yönlendir
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => WordleResultPage(
          isWinner: wordsCompleted > 0,
          isTimeOut: true, // Zamana karşı modda her zaman zaman aşımı
          secretWord: viewModel.secretWord,
          attempts: viewModel.currentAttempt + 1,
          timeSpent: 60, // Başlangıç süresi
          gameMode: viewModel.gameMode,
          currentLevel: viewModel.currentLevel,
          maxLevel: viewModel.maxLevel,
          shareText: viewModel.generateShareText(),
          tokensEarned: tokensEarned,
          score: wordsCompleted, // Puan yerine kelime sayısı
        ),
      ),
    );
  }

  void _triggerSuccessAnimation() {
    setState(() {
      _showSuccessAnimation = true;
    });
    
    _successAnimationController.forward().then((_) {
      _successAnimationController.reverse().then((_) {
        setState(() {
          _showSuccessAnimation = false;
        });
      });
    });
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
        final screenHeight = MediaQuery.of(context).size.height;

        // Eğer yeni kelime doğru tahmin edildiyse animasyonu tetikle
        if (viewModel.isWinner && !_showSuccessAnimation) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _triggerSuccessAnimation();
          });
        }

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
          backgroundColor: Colors.grey.shade900,
          appBar: AppBar(
            backgroundColor: Colors.grey.shade900,
            title: const Text('⏰ ZAMANA KARŞI'),
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
              // Zamanlayıcı
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${viewModel.timeRushSeconds}s',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Skor paneli
                Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple.shade700, Colors.indigo.shade700],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: _showSuccessAnimation 
                        ? Border.all(color: Colors.green, width: 3)
                        : null,
                  ),
                  child: AnimatedBuilder(
                    animation: _successScaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _showSuccessAnimation ? _successScaleAnimation.value : 1.0,
                                                 child: Row(
                           mainAxisAlignment: MainAxisAlignment.center,
                           children: [
                             Column(
                               children: [
                                 const Icon(Icons.speed, color: Colors.amber, size: 28),
                                 const Text('Doğru Kelime', style: TextStyle(color: Colors.white, fontSize: 14)),
                                 Text(
                                   '${viewModel.wordsGuessedCount}',
                                   style: const TextStyle(
                                     color: Colors.white,
                                     fontSize: 28,
                                     fontWeight: FontWeight.bold,
                                   ),
                                 ),
                                 Text(
                                   '+${viewModel.wordsGuessedCount * 2} jeton',
                                   style: TextStyle(
                                     color: Colors.amber.shade300,
                                     fontSize: 12,
                                     fontWeight: FontWeight.w500,
                                   ),
                                 ),
                               ],
                             ),
                           ],
                         ),
                      );
                    }
                  ),
                ),
                
                // Grid - Expanded ile sabit alan
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ShakeWidget(
                      shake: viewModel.needsShake,
                      onShakeComplete: () {
                        viewModel.resetShake();
                      },
                      child: Container(
                        decoration: _showSuccessAnimation 
                            ? BoxDecoration(
                                border: Border.all(color: Colors.green, width: 2),
                                borderRadius: BorderRadius.circular(8),
                              )
                            : null,
                        child: GuessGrid(screenWidth: screenWidth),
                      ),
                    ),
                  ),
                ),
                
                // Klavye - Sabit alan
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: const KeyboardWidget(),
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
} 