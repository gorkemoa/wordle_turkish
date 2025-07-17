// lib/views/multiplayer_game_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/multiplayer_game_viewmodel.dart';
import '../models/multiplayer_game.dart';
import '../widgets/multiplayer_game_grid.dart';
import '../widgets/multiplayer_keyboard.dart';
import '../widgets/multiplayer_player_card.dart';
import '../widgets/multiplayer_status_bar.dart';
import '../widgets/multiplayer_waiting_screen.dart';
import '../services/haptic_service.dart';

/// 🎮 Multiplayer oyun sayfası
/// 
/// Bu sayfa şu bileşenleri içerir:
/// - Eşleştirme bekleme ekranı
/// - Oyuncu kartları
/// - Oyun grid'i
/// - Klavye
/// - Durum çubuğu
/// - Sonuç dialog'u
class MultiplayerGamePage extends StatefulWidget {
  final VoidCallback? onBack;

  const MultiplayerGamePage({
    Key? key,
    this.onBack,
  }) : super(key: key);

  @override
  State<MultiplayerGamePage> createState() => _MultiplayerGamePageState();
}

class _MultiplayerGamePageState extends State<MultiplayerGamePage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _shakeController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeViewModel();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );
  }

  void _initializeViewModel() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<MultiplayerGameViewModel>();
      viewModel.initialize().then((_) {
        _fadeController.forward();
        // Otomatik eşleştirme arama başlat
        _startMatchmaking();
      });
    });
  }

  void _startMatchmaking() {
    final viewModel = context.read<MultiplayerGameViewModel>();
    viewModel.findMatch().then((success) {
      if (success) {
        debugPrint('✅ Eşleştirme başarılı');
      } else {
        debugPrint('❌ Eşleştirme başarısız');
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Consumer<MultiplayerGameViewModel>(
          builder: (context, viewModel, child) {
            return _buildBody(viewModel);
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1A1A1D),
      elevation: 0,
      title: const Text(
        'Multiplayer Oyun',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () {
          HapticService.triggerLightHaptic();
          _handleBackPressed();
        },
      ),
      actions: [
        Consumer<MultiplayerGameViewModel>(
          builder: (context, viewModel, child) {
            return IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: viewModel.isInGame ? null : () {
                HapticService.triggerMediumHaptic();
                _startMatchmaking();
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildBody(MultiplayerGameViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF538D4E),
        ),
      );
    }

    if (viewModel.error != null) {
      return _buildErrorScreen(viewModel);
    }

    if (!viewModel.isMatched) {
      return MultiplayerWaitingScreen(
        waitingPlayersCount: viewModel.waitingPlayersCount,
        onCancel: () => _handleBackPressed(),
        onRetry: () => _startMatchmaking(),
      );
    }

    return _buildGameScreen(viewModel);
  }

  Widget _buildErrorScreen(MultiplayerGameViewModel viewModel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            viewModel.error!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              HapticService.triggerMediumHaptic();
              _startMatchmaking();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF538D4E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
            ),
            child: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }

  Widget _buildGameScreen(MultiplayerGameViewModel viewModel) {
    return Column(
      children: [
        // Durum çubuğu
        MultiplayerStatusBar(
          status: viewModel.getGameStatusText(),
          isMyTurn: viewModel.isMyTurn,
          gameFinished: viewModel.gameFinished,
        ),
        
        // Oyuncular
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Mevcut oyuncu
              Expanded(
                child: MultiplayerPlayerCard(
                  player: viewModel.currentPlayer,
                  isCurrentPlayer: true,
                  isWinner: viewModel.isWinner && viewModel.gameFinished,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // VS
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2D),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'VS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Rakip oyuncu
              Expanded(
                child: MultiplayerPlayerCard(
                  player: viewModel.opponent,
                  isCurrentPlayer: false,
                  isWinner: !viewModel.isWinner && viewModel.gameFinished,
                ),
              ),
            ],
          ),
        ),
        
        // Oyun grid'i
        Expanded(
          child: AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_shakeAnimation.value * 10, 0),
                child: MultiplayerGameGrid(
                  guesses: viewModel.guesses,
                  guessColors: viewModel.guessColors,
                  currentAttempt: viewModel.currentAttempt,
                  currentColumn: viewModel.currentColumn,
                  wordLength: viewModel.currentMatch?.wordLength ?? 5,
                  onCellTap: viewModel.canMakeMove ? (row, col) {
                    // Hücre tıklama işlevi (opsiyonel)
                  } : null,
                ),
              );
            },
          ),
        ),
        
        // Klavye
        MultiplayerKeyboard(
          keyboardColors: viewModel.keyboardColors,
          onKeyPressed: viewModel.canMakeMove ? (key) {
            _handleKeyPress(viewModel, key);
          } : null,
          onDeletePressed: viewModel.canMakeMove ? () {
            viewModel.deleteLetter();
          } : null,
          onEnterPressed: viewModel.canMakeMove ? () {
            _handleEnterPress(viewModel);
          } : null,
          enabled: viewModel.canMakeMove,
        ),
        
        const SizedBox(height: 16),
      ],
    );
  }

  void _handleKeyPress(MultiplayerGameViewModel viewModel, String key) {
    viewModel.inputLetter(key);
  }

  void _handleEnterPress(MultiplayerGameViewModel viewModel) {
    if (viewModel.currentColumn == (viewModel.currentMatch?.wordLength ?? 5)) {
      viewModel.submitGuess().then((_) {
        if (viewModel.error != null) {
          _shakeController.forward().then((_) {
            _shakeController.reset();
          });
        }
      });
    }
  }

  void _handleBackPressed() {
    final viewModel = context.read<MultiplayerGameViewModel>();
    
    if (viewModel.isInGame) {
      _showExitConfirmation();
    } else {
      widget.onBack?.call();
      Navigator.of(context).pop();
    }
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1D),
        title: const Text(
          'Oyundan Çık',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Oyundan çıkarsanız otomatik olarak kaybedersiniz. Emin misiniz?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              final viewModel = context.read<MultiplayerGameViewModel>();
              viewModel.leaveGame();
              widget.onBack?.call();
              Navigator.of(context).pop();
            },
            child: const Text(
              'Çık',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

/// 🎮 Multiplayer oyun sayfası wrapper'ı
/// 
/// Bu widget, ViewModel'i provide eder ve sayfa navigation'ını yönetir
class MultiplayerGameWrapper extends StatelessWidget {
  final VoidCallback? onBack;

  const MultiplayerGameWrapper({
    Key? key,
    this.onBack,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MultiplayerGameViewModel(),
      child: MultiplayerGamePage(onBack: onBack),
    );
  }
} 