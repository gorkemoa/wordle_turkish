// lib/widgets/multiplayer_game_grid.dart

import 'package:flutter/material.dart';
import '../models/multiplayer_game.dart';

/// 🎮 Multiplayer oyun grid'i
/// 
/// Bu widget şu özellikleri sağlar:
/// - Dinamik kelime uzunluğu desteği
/// - Renk kodlaması (doğru, mevcut, yok)
/// - Animasyonlu hücre güncellemeleri
/// - Mevcut deneme göstergesi
/// - Tıklama olayları (opsiyonel)
class MultiplayerGameGrid extends StatelessWidget {
  final List<List<String>> guesses;
  final List<List<LetterStatus>> guessColors;
  final int currentAttempt;
  final int currentColumn;
  final int wordLength;
  final Function(int row, int col)? onCellTap;

  const MultiplayerGameGrid({
    Key? key,
    required this.guesses,
    required this.guessColors,
    required this.currentAttempt,
    required this.currentColumn,
    required this.wordLength,
    this.onCellTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Grid
          ...List.generate(6, (row) => _buildRow(row)),
          
          const SizedBox(height: 16),
          
          // Deneme göstergesi
          _buildAttemptIndicator(),
        ],
      ),
    );
  }

  Widget _buildRow(int row) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(wordLength, (col) => _buildCell(row, col)),
      ),
    );
  }

  Widget _buildCell(int row, int col) {
    final isCurrentCell = row == currentAttempt && col == currentColumn - 1;
    final letter = row < guesses.length && col < guesses[row].length 
        ? guesses[row][col] 
        : '';
    final color = _getCellColor(row, col);
    final borderColor = _getCellBorderColor(row, col);

    return GestureDetector(
      onTap: onCellTap != null ? () => onCellTap!(row, col) : null,
      child: Container(
        width: _getCellSize(),
        height: _getCellSize(),
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(
            color: borderColor,
            width: isCurrentCell ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            letter,
            style: TextStyle(
              color: _getTextColor(row, col),
              fontSize: _getFontSize(),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttemptIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.edit,
          color: Colors.white70,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          'Deneme: ${currentAttempt + 1}/6',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Color _getCellColor(int row, int col) {
    // Geçmiş tahminler
    if (row < currentAttempt && 
        row < guessColors.length && 
        col < guessColors[row].length) {
      return _getLetterStatusColor(guessColors[row][col]);
    }
    
    // Mevcut tahmin
    if (row == currentAttempt) {
      final hasLetter = row < guesses.length && 
                       col < guesses[row].length && 
                       guesses[row][col].isNotEmpty;
      return hasLetter ? const Color(0xFF3A3A3C) : const Color(0xFF2A2A2D);
    }
    
    // Gelecek tahminler
    return const Color(0xFF1A1A1D);
  }

  Color _getCellBorderColor(int row, int col) {
    // Mevcut hücre
    if (row == currentAttempt && col == currentColumn - 1) {
      return const Color(0xFF538D4E);
    }
    
    // Geçmiş tahminler
    if (row < currentAttempt && 
        row < guessColors.length && 
        col < guessColors[row].length) {
      return _getLetterStatusColor(guessColors[row][col]);
    }
    
    // Mevcut tahmin satırı
    if (row == currentAttempt) {
      final hasLetter = row < guesses.length && 
                       col < guesses[row].length && 
                       guesses[row][col].isNotEmpty;
      return hasLetter ? const Color(0xFF5A5A5C) : const Color(0xFF3A3A3C);
    }
    
    // Varsayılan
    return const Color(0xFF3A3A3C);
  }

  Color _getTextColor(int row, int col) {
    // Geçmiş tahminler
    if (row < currentAttempt && 
        row < guessColors.length && 
        col < guessColors[row].length) {
      return Colors.white;
    }
    
    // Mevcut ve gelecek tahminler
    return Colors.white;
  }

  Color _getLetterStatusColor(LetterStatus status) {
    switch (status) {
      case LetterStatus.correct:
        return const Color(0xFF538D4E);
      case LetterStatus.present:
        return const Color(0xFFC9B458);
      case LetterStatus.absent:
        return const Color(0xFF787C7E);
    }
  }

  double _getCellSize() {
    // Kelime uzunluğuna göre dinamik boyutlandırma
    switch (wordLength) {
      case 4:
        return 60.0;
      case 5:
        return 50.0;
      case 6:
        return 45.0;
      case 7:
        return 40.0;
      case 8:
        return 35.0;
      default:
        return 50.0;
    }
  }

  double _getFontSize() {
    // Kelime uzunluğuna göre dinamik font boyutu
    switch (wordLength) {
      case 4:
        return 24.0;
      case 5:
        return 20.0;
      case 6:
        return 18.0;
      case 7:
        return 16.0;
      case 8:
        return 14.0;
      default:
        return 20.0;
    }
  }
} 