import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/wordle_viewmodel.dart';
import '../widgets/shake_widget.dart';
import '../widgets/keyboard_widget.dart';

class TimeRushPage extends StatefulWidget {
  final VoidCallback toggleTheme;

  const TimeRushPage({Key? key, required this.toggleTheme}) : super(key: key);

  @override
  State<TimeRushPage> createState() => _TimeRushPageState();
}

class _TimeRushPageState extends State<TimeRushPage> {
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
          _showTimeRushResultDialog(_viewModel);
        });
      }
    };
    _viewModel.addListener(_listener);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.resetGame(mode: GameMode.timeRush);
    });
  }

  @override
  void dispose() {
    _viewModel.removeListener(_listener);
    super.dispose();
  }

  void _showTimeRushResultDialog(WordleViewModel viewModel) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: const Color(0xFFE74C3C), width: 2),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFFE74C3C), const Color(0xFFC0392B)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.timer, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Text('Süre Doldu!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2A2A2A),
                  const Color(0xFF1A1A1D),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '🎯 ${viewModel.wordsGuessedCount} kelime buldunuz!',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  '⭐ Toplam Skor: ${viewModel.timeRushScore}',
                  style: TextStyle(color: Colors.amber.shade400, fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  '🪙 ${viewModel.wordsGuessedCount} jeton kazandınız!',
                  style: TextStyle(color: Colors.orange.shade400, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Ana sayfaya dön
              },
              child: const Text('Ana Sayfa', style: TextStyle(color: Colors.grey, fontSize: 16)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _hasShownDialog = false;
                });
                _viewModel.resetGame(mode: GameMode.timeRush);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE74C3C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Yeniden Oyna', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTimeRushHeader(WordleViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFE74C3C),
            const Color(0xFFC0392B),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('⏰', '${viewModel.timeRushSeconds}s', 'Kalan Süre'),
          _buildStatItem('🎯', '${viewModel.wordsGuessedCount}', 'Bulunan'),
          _buildStatItem('⭐', '${viewModel.timeRushScore}', 'Skor'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String emoji, String value, String label) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildGuessGrid(WordleViewModel viewModel, double screenWidth) {
    double boxSize = (screenWidth - 80) / viewModel.currentWordLength;
    if (boxSize > 60) boxSize = 60;

    return Column(
      children: List.generate(
        WordleViewModel.maxAttempts,
        (rowIndex) => Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              viewModel.currentWordLength,
              (colIndex) => Container(
                width: boxSize,
                height: boxSize,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: viewModel.getBoxColor(rowIndex, colIndex),
                  border: Border.all(
                    color: Colors.grey.shade600,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    viewModel.guesses[rowIndex][colIndex],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WordleViewModel>(
      builder: (context, viewModel, child) {
        final screenWidth = MediaQuery.of(context).size.width;

        return Scaffold(
          backgroundColor: const Color(0xFF0A0A0A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1A1A1A),
            title: Row(
              children: [
                const Icon(Icons.timer, color: Color(0xFFE74C3C)),
                const SizedBox(width: 8),
                const Text(
                  'Zamana Karşı',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  setState(() {
                    _hasShownDialog = false;
                  });
                  _viewModel.resetGame(mode: GameMode.timeRush);
                },
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildTimeRushHeader(viewModel),
                  const SizedBox(height: 20),
                  ShakeWidget(
                    shake: viewModel.needsShake,
                    onShakeComplete: () {
                      viewModel.resetShake();
                    },
                    child: _buildGuessGrid(viewModel, screenWidth),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: const KeyboardWidget(),
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