// lib/widgets/keyboard_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/wordle_viewmodel.dart';

class KeyboardWidget extends StatelessWidget {
  const KeyboardWidget({Key? key}) : super(key: key);

  // Türkçe harfleri içeren klavye satırları
  final List<List<String>> keyboardRows = const [
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', 'Ğ', 'Ü'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'Ş', 'İ'],
    ['Z', 'X', 'C', 'V', 'B', 'N', 'M', 'Ö', 'Ç', 'BACK'],
  ];

  @override
  Widget build(BuildContext context) {
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
                  } else if (key == 'SUBMIT') {
                    return _buildSpecialKey(
                      context,
                      label: 'SUBMIT',
                      onTap: () {
                        if (viewModel.gameOver) return;
                        viewModel.onEnter();
                      },
                      color: Colors.blue.shade700,
                      flex: 2, // Submit butonu genişletildi
                    );
                  } else {
                    return _buildLetterKey(context, key, keyboardColors[key] ?? Colors.grey.shade800);
                  }
                }).toList(),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildLetterKey(BuildContext context, String key, Color color) {
    final viewModel = Provider.of<WordleViewModel>(context, listen: false);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
        child: GestureDetector(
          onTap: () {
            if (viewModel.gameOver) return;
            viewModel.onKeyTap(key);
          },
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  )
                : Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}