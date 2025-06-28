import 'package:flutter/material.dart';
import '../viewmodels/wordle_viewmodel.dart';

class GameStats extends StatelessWidget {
  final WordleViewModel viewModel;
  
  const GameStats({Key? key, required this.viewModel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            Text(
              'Seviye: ${viewModel.currentLevel} / ${viewModel.maxLevel}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ],
          if (viewModel.gameMode == GameMode.timeRush) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Kelime Sayısı: ${viewModel.wordsGuessedCount}'),
                Text('Puan: ${viewModel.timeRushScore}'),
              ],
            ),
          ],
          if (viewModel.gameMode == GameMode.themed) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${viewModel.themeEmoji} ${viewModel.themeName}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}";
  }
} 