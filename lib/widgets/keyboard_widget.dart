// lib/widgets/keyboard_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/wordle_viewmodel.dart';
import '../viewmodels/duel_viewmodel.dart';

class KeyboardWidget extends StatelessWidget {
  final bool isDuelMode;
  
  const KeyboardWidget({Key? key, this.isDuelMode = false}) : super(key: key);

  // Türkçe harfleri içeren klavye satırları
  final List<List<String>> keyboardRows = const [
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', 'Ğ', 'Ü'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'Ş', 'İ'],
    ['Z', 'X', 'C', 'V', 'B', 'N', 'M', 'Ö', 'Ç', 'CLEAR', 'BACK'],
  ];

  @override
  Widget build(BuildContext context) {
    if (isDuelMode) {
      return _buildDuelKeyboard(context);
    } else {
      return _buildWordleKeyboard(context);
    }
  }

  Widget _buildWordleKeyboard(BuildContext context) {
    final viewModel = Provider.of<WordleViewModel>(context);
    final keyboardColors = viewModel.keyboardColors;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: keyboardRows.map((row) {
            return Flexible(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: row.map((key) {
                  if (key == 'BACK') {
                    return _buildSpecialKey(
                      context,
                      icon: Icons.backspace_rounded,
                      onTap: () {
                        if (viewModel.gameOver) return;
                        viewModel.onBackspace();
                      },
                      color: Colors.redAccent,
                    );
                  } else if (key == 'CLEAR') {
                    return _buildSpecialKey(
                      context,
                      icon: Icons.close_rounded,
                      onTap: () {
                        if (viewModel.gameOver) return;
                        for (int i = 0; i < viewModel.currentColumn; i++) {
                          viewModel.onBackspace();
                        }
                      },
                      color: Colors.orange.shade700,
                    );
                  } else {
                    return _buildLetterKey(context, key, keyboardColors[key] ?? Colors.grey.shade800, () {
                      if (viewModel.gameOver) return;
                      viewModel.onKeyTap(key);
                    });
                  }
                }).toList(),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildDuelKeyboard(BuildContext context) {
    final viewModel = Provider.of<DuelViewModel>(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // İlk satır
            Flexible(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: keyboardRows[0].map((key) {
                  return _buildLetterKey(context, key, Colors.grey.shade800, () {
                    if (viewModel.isGameFinished) return;
                    viewModel.addLetter(key);
                    if (viewModel.currentGuess.length == 5) {
                      viewModel.submitGuess();
                    }
                  });
                }).toList(),
              ),
            ),
            // İkinci satır
            Flexible(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: keyboardRows[1].map((key) {
                  return _buildLetterKey(context, key, Colors.grey.shade800, () {
                    if (viewModel.isGameFinished) return;
                    viewModel.addLetter(key);
                    if (viewModel.currentGuess.length == 5) {
                      viewModel.submitGuess();
                    }
                  });
                }).toList(),
              ),
            ),
            // Üçüncü satır - harfler, CLEAR, BACK
            Flexible(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Harfler (CLEAR ve BACK hariç)
                  ...keyboardRows[2].where((key) => key != 'BACK' && key != 'CLEAR').map((key) {
                    return _buildLetterKey(context, key, Colors.grey.shade800, () {
                      if (viewModel.isGameFinished) return;
                      viewModel.addLetter(key);
                      if (viewModel.currentGuess.length == 5) {
                        viewModel.submitGuess();
                      }
                    });
                  }),
                  // CLEAR butonu
                  _buildSpecialKey(
                    context,
                    icon: Icons.close_rounded,
                    onTap: () {
                      if (viewModel.isGameFinished) return;
                      while (viewModel.currentGuess.isNotEmpty) {
                        viewModel.removeLetter();
                      }
                    },
                    color: Colors.orange.shade700,
                    flex: 2,
                  ),
                  // BACK butonu
                  _buildSpecialKey(
                    context,
                    icon: Icons.backspace_rounded,
                    onTap: () {
                      if (viewModel.isGameFinished) return;
                      viewModel.removeLetter();
                    },
                    color: Colors.redAccent,
                    flex: 2,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLetterKey(BuildContext context, String key, Color color, VoidCallback onTap) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3.0),
              border: Border.all(color: Colors.grey.shade600),
            ),
            alignment: Alignment.center,
            child: Text(
              key,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialKey(BuildContext context, {String? label, IconData? icon, required VoidCallback onTap, Color? color, int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: color ?? Colors.grey.shade800,
              borderRadius: BorderRadius.circular(3.0),
              border: Border.all(color: Colors.grey.shade600),
            ),
            alignment: Alignment.center,
            child: label != null
                ? Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      height: 1.4,
                    ),
                  )
                : Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}