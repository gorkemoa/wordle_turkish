import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/duel_viewmodel.dart';
import '../models/duel_game.dart';
import '../services/firebase_service.dart';
import '../widgets/shake_widget.dart';
import 'duel_result_page.dart';

// Düello sayfası

class DuelPage extends StatefulWidget {
  const DuelPage({Key? key}) : super(key: key);

  @override
  State<DuelPage> createState() => _DuelPageState();
}

class _DuelPageState extends State<DuelPage> with TickerProviderStateMixin {
  late AnimationController _borderController;
  late Animation<double> _borderAnimation;
  bool _hasNavigatedToResult = false;
  bool _shouldShowRedBorder = false;
  DuelViewModel? _viewModel;

  @override
  void initState() {
    super.initState();
    debugPrint('🎮 DuelPage initState başladı');

    _borderController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _borderAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _borderController,
      curve: Curves.easeInOut,
    ));

    // DuelPage artık her durumda açık kalacak - oyun durumuna göre UI gösterecek
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      _viewModel = Provider.of<DuelViewModel>(context, listen: false);
    } catch (e) {
      debugPrint('didChangeDependencies viewModel error: $e');
      _viewModel = null;
    }
  }

  @override
  void dispose() {
    _borderController.dispose();
    super.dispose();
  }

  void _checkForInvalidWord(DuelViewModel viewModel) {
    if (!mounted) return;
    
    if (viewModel.needsShake && !_shouldShowRedBorder) {
      setState(() {
        _shouldShowRedBorder = true;
      });
      
      _borderController.repeat(reverse: true);
      
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          _borderController.stop();
          setState(() {
            _shouldShowRedBorder = false;
          });
        }
      });
    }
  }

  void _navigateToResultPage(DuelGame game) {
    if (_hasNavigatedToResult || !mounted || !context.mounted) return;
    _hasNavigatedToResult = true;
    
    try {
      final viewModel = _viewModel ?? Provider.of<DuelViewModel>(context, listen: false);
      final currentPlayer = viewModel.currentPlayer;

      debugPrint('🚀 DuelPage - Sonuç sayfasına yönlendiriliyor');
      debugPrint('🎮 Game status: ${game.status}');
      debugPrint('🏆 Winner: ${game.winnerId}');
      debugPrint('👤 CurrentPlayer: ${currentPlayer?.playerName}');
      debugPrint('🤖 OpponentPlayer: ${viewModel.opponentPlayer?.playerName}');

      if (currentPlayer == null) {
        debugPrint('❌ CurrentPlayer null, navigation iptal ediliyor');
        _hasNavigatedToResult = false;
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => DuelResultPage(
            game: game,
            currentPlayer: currentPlayer,
            opponentPlayer: viewModel.opponentPlayer,
            playerName: viewModel.playerName,
            gameDuration: viewModel.gameDuration,
          ),
        ),
      );
      debugPrint('✅ DuelResultPage navigation başarılı');
    } catch (e) {
      debugPrint('❌ DuelPage - Sonuç sayfasına yönlendirme hatası: $e');
      _hasNavigatedToResult = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _showExitConfirmDialog();
        if (shouldPop && mounted && context.mounted && Navigator.canPop(context)) {
          (_viewModel ?? Provider.of<DuelViewModel>(context, listen: false)).leaveGame();
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          Consumer<DuelViewModel>(
            builder: (context, viewModel, child) {
              if (viewModel.currentGame?.status != GameStatus.active) {
                return const SizedBox.shrink();
              }
              
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: 'Kelimeden rastgele bir harf göster',
                    child: _buildPowerUpButton(
                      '15',
                      Icons.lightbulb_outline,
                      Colors.amber,
                      () => _buyLetterHint(viewModel),
                    ),
                  ),
                  const SizedBox(width: 4),
                  
                  if (!viewModel.firstRowVisible)
                    Tooltip(
                      message: 'Rakibin ilk tahminini gör',
                      child: _buildPowerUpButton(
                        '10',
                        Icons.visibility,
                        Colors.orange,
                        () => _buyFirstRowVisibility(viewModel),
                      ),
                    ),
                  if (!viewModel.allRowsVisible && viewModel.firstRowVisible)
                    const SizedBox(width: 4),
                  if (!viewModel.allRowsVisible)
                    Tooltip(
                      message: 'Rakibin tüm tahminlerini gör',
                      child: _buildPowerUpButton(
                        '20',
                        Icons.remove_red_eye,
                        Colors.red,
                        () => _buyAllRowsVisibility(viewModel),
                      ),
                    ),
                  const SizedBox(width: 8),
                ],
              );
            },
          ),
          
          Consumer<DuelViewModel>(
            builder: (context, viewModel, child) {
              return FutureBuilder<int>(
                future: FirebaseService.getCurrentUser() != null 
                    ? FirebaseService.getUserTokens(FirebaseService.getCurrentUser()!.uid)
                    : Future.value(0),
                builder: (context, snapshot) {
                  final tokens = snapshot.data ?? 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '$tokens',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.red),
            onPressed: () => _showExitDialog(context),
          ),
        ],
      ),
      body: Consumer<DuelViewModel>(
        builder: (context, viewModel, child) {
          final gameState = viewModel.gameState;
          final game = viewModel.currentGame;
          
          debugPrint('🎮 DuelPage build - GameState: $gameState, Game: ${game != null}');
          
          // Oyun durumuna göre UI göster
          switch (gameState) {
            case GameState.gameStarting:
              return _buildGameStartingState();
              
            case GameState.playing:
              // Oyun başladığında navigation flag'ını sıfırla
              if (_hasNavigatedToResult) {
                _hasNavigatedToResult = false;
                debugPrint('🔄 DuelPage - hasNavigatedToResult sıfırlandı');
              }
              
              if (game != null) {
                return Column(
                  children: [
                    _buildPlayersInfo(viewModel),
                    Expanded(
                      child: _buildGameBoard(viewModel),
                    ),
                    if (viewModel.isGameActive)
                      Container(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        child: _DuelKeyboardWidget(viewModel: viewModel),
                      ),
                  ],
                );
              }
              return _buildLoadingState();
              
            case GameState.finished:
              if (game != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_hasNavigatedToResult) {
                    _navigateToResultPage(game);
                  }
                });
                return _buildGameFinishedState();
              }
              return _buildLoadingState();
              
            default:
              return _buildLoadingState();
          }
        },
      ),
    ));
  }

  void _showExitDialog(BuildContext context) {
      showDialog(
        context: context,
        builder: (dialogContext) {
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
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Devam Et',
                style: TextStyle(color: Colors.blue),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  final viewModel = _viewModel ?? Provider.of<DuelViewModel>(context, listen: false);
                  await viewModel.leaveGame();
                  if (mounted && context.mounted) {
                    Navigator.popUntil(context, (route) => route.isFirst);
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

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Oyun Yükleniyor...',
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

  Widget _buildGameFinishedState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Colors.green,
          ),
          SizedBox(height: 16),
          Text(
            'Oyun bitti! Sonuçlar yükleniyor...',
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
          _buildPlayerCard(
            name: viewModel.playerName,
            attempts: currentPlayer?.currentAttempt ?? 0,
            status: currentPlayer?.status ?? PlayerStatus.waiting,
            isWinner: game.winnerId == currentPlayer?.playerId,
            isCurrentPlayer: true,
          ),
          
          const Text(
            'VS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          
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
          Expanded(
            child: ShakeWidget(
              shake: viewModel.needsShake,
              onShakeComplete: () {
                viewModel.resetShake();
              },
              child: _buildPlayerBoard(
                title: 'Senin Tahminlerin',
                player: viewModel.currentPlayer,
                currentGuess: viewModel.currentGuess,
                currentColumn: viewModel.currentColumn,
                viewModel: viewModel,
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          Expanded(
            child: _buildOpponentBoard(
              title: 'Rakip Tahminleri',
              player: viewModel.opponentPlayer,
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkForInvalidWord(viewModel);
      }
    });
    
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
            itemCount: 30,
            itemBuilder: (context, index) {
              final row = index ~/ 5;
              final col = index % 5;
              
              String letter = '';
              Color boxColor = const Color(0xFF3A3A3C);
              Color textColor = Colors.white;
              
              if (player != null && row < player.guesses.length) {
                if (row < player.currentAttempt) {
                  letter = player.guesses[row][col] == '_' ? '' : player.guesses[row][col];
                  boxColor = viewModel.getColorFromString(player.guessColors[row][col]);
                }
                else if (row == player.currentAttempt && currentGuess != null) {
                  if (col < currentColumn) {
                    letter = currentGuess[col];
                    boxColor = const Color(0xFF565758);
                  }
                }
              }
              
              bool shouldShowRedBorder = _shouldShowRedBorder && 
                                       player != null && 
                                       row == player.currentAttempt;
              
              if (shouldShowRedBorder) {
                return AnimatedBuilder(
                  animation: _borderAnimation,
                  builder: (context, child) {
                    final animatedBorderColor = Color.lerp(
                      const Color(0xFF565758),
                      Colors.red.shade400,
                      _borderAnimation.value,
                    )!;
                    
                    return Container(
                      decoration: BoxDecoration(
                        color: boxColor,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: animatedBorderColor,
                          width: 2.0 + (_borderAnimation.value * 1.0),
                        ),
                        boxShadow: _borderAnimation.value > 0.5 ? [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.4),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ] : null,
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
                );
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

  Widget _buildOpponentBoard({
    required String title,
    DuelPlayer? player,
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
            itemCount: 30,
            itemBuilder: (context, index) {
              final row = index ~/ 5;
              final col = index % 5;
              
              String letter = '';
              Color boxColor = const Color(0xFF3A3A3C);
              Color textColor = Colors.white;
              
              bool isRowVisible = viewModel.shouldShowOpponentRow(row);
              
              if (player != null && row < player.guesses.length) {
                if (row < player.currentAttempt) {
                  if (isRowVisible) {
                    letter = player.guesses[row][col] == '_' ? '' : player.guesses[row][col];
                    boxColor = viewModel.getColorFromString(player.guessColors[row][col]);
                  } else {
                    letter = '?';
                    boxColor = const Color(0xFF4A4A4A);
                    textColor = Colors.grey;
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

  Future<void> _buyFirstRowVisibility(DuelViewModel viewModel) async {
    try {
      final success = await viewModel.buyFirstRowVisibility();
      if (!success && mounted) {
        _showPowerUpErrorDialog('Yetersiz Jeton', 'İlk satırı görmek için 10 jetona ihtiyacınız var.');
      }
    } catch (e) {
      if (mounted) {
        _showPowerUpErrorDialog('Hata', 'İşlem sırasında bir hata oluştu.');
      }
    }
  }

  Future<void> _buyAllRowsVisibility(DuelViewModel viewModel) async {
    try {
      final success = await viewModel.buyAllRowsVisibility();
      if (!success && mounted) {
        _showPowerUpErrorDialog('Yetersiz Jeton', 'Tüm satırları görmek için 20 jetona ihtiyacınız var.');
      }
    } catch (e) {
      if (mounted) {
        _showPowerUpErrorDialog('Hata', 'İşlem sırasında bir hata oluştu.');
      }
    }
  }

  Future<void> _buyLetterHint(DuelViewModel viewModel) async {
    try {
      final hintLetter = await viewModel.buyLetterHint();
      if (!mounted) return;
      
      if (hintLetter == 'INSUFFICIENT_TOKENS') {
        _showPowerUpErrorDialog('Yetersiz Jeton', 'Harf ipucu için 15 jetona ihtiyacınız var. Mevcut jetonunuz yetersiz.');
      } else if (hintLetter == 'ALL_LETTERS_GUESSED') {
        _showPowerUpErrorDialog('İpucu Yok', 'Kelimedeki tüm harfler zaten tahmin edilmiş. İpucu verilecek harf kalmadı.');
      } else if (hintLetter != null && hintLetter.length == 1) {
        _showHintDialog(hintLetter);
      } else {
        _showPowerUpErrorDialog('Hata', 'İpucu alınırken bir hata oluştu. Lütfen tekrar deneyin.');
      }
    } catch (e) {
      if (mounted) {
        _showPowerUpErrorDialog('Hata', 'İpucu alınırken beklenmeyen bir hata oluştu: $e');
      }
    }
  }

  void _showHintDialog(String hintLetter) {
    if (!mounted || !context.mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.lightbulb, color: Colors.amber, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('İpucu!', style: TextStyle(color: Colors.white, fontSize: 20)),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.amber.withOpacity(0.1), Colors.orange.withOpacity(0.1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Kelimede şu harf var:',
                style: TextStyle(color: Colors.grey, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    hintLetter,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '💡 Bu harfi kelimende kullanabilirsin!',
                style: TextStyle(color: Colors.amber, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Anladım!', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPowerUpErrorDialog(String title, String message) {
      if (!mounted || !context.mounted) return;
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, style: const TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: const Column(
                  children: [
                    Text(
                      '💡 Jeton Kazanma Yolları:',
                      style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• Düello kazanarak 4 jeton\n• Reklam izleyerek\n• Jeton mağazasından satın al',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Anladım', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      );
  }

  Future<bool> _showExitConfirmDialog() async {
    if (!mounted || !context.mounted) return false;
    
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text(
            '🚪 Düellodan Çık',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Düellodan çıkmak istediğinizden emin misiniz?\nOyunu kaybetmiş sayılacaksınız!',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'İptal',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
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

  Widget _buildPowerUpButton(
    String cost,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(
              cost,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.monetization_on,
              color: Colors.amber,
              size: 12,
            ),
          ],
        ),
      ),
    );
  }
}

class _DuelKeyboardWidget extends StatelessWidget {
  final DuelViewModel viewModel;

  const _DuelKeyboardWidget({required this.viewModel});

  final List<List<String>> keyboardRows = const [
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', 'Ğ', 'Ü'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'Ş', 'İ'],
    ['Z', 'X', 'C', 'V', 'B', 'N', 'M', 'Ö', 'Ç', 'BACK'],
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    final keyHeight = screenHeight * 0.07;
    final fontSize = screenWidth * 0.04;
    final spacing = screenWidth * 0.005;
    
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
          flex: rowIndex == 2 ? 1.5 : 1,
        ));
      } else {
        keys.add(_buildLetterKey(
          context, 
          key, 
          keyHeight, 
          fontSize, 
          spacing,
          flex: rowIndex == 1 ? 1.1 : 1.0,
        ));
      }
    }
    
    return keys;
  }

  Widget _buildLetterKey(BuildContext context, String key, double keyHeight, 
                        double fontSize, double spacing, {double flex = 1.0}) {
    final keyboardLetters = viewModel.keyboardLetters;
    final keyStatus = keyboardLetters[key];
    
    Color getKeyColor() {
      switch (keyStatus) {
        case 'green':
          return Colors.green.shade600;
        case 'orange':
          return Colors.orange.shade600;
        case 'grey':
          return Colors.grey.shade700;
        default:
          return const Color(0xFF565758);
      }
    }
    
    Color getKeyColorSecondary() {
      switch (keyStatus) {
        case 'green':
          return Colors.green.shade800;
        case 'orange':
          return Colors.orange.shade800;
        case 'grey':
          return Colors.grey.shade800;
        default:
          return const Color(0xFF3A3A3C);
      }
    }
    
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
                    getKeyColor(),
                    getKeyColorSecondary(),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: keyStatus != null 
                    ? getKeyColor().withOpacity(0.8)
                    : const Color(0xFF6D6D6D),
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
                  color: keyStatus == 'grey' 
                    ? Colors.grey.shade400 
                    : Colors.white,
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