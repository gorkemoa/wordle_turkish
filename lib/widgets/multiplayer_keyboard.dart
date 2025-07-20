import 'package:flutter/material.dart';

class MultiplayerKeyboard extends StatelessWidget {
  final Map<String, Color> keyboardColors;
  final ValueChanged<String>? onKeyPressed;
  final VoidCallback? onDeletePressed;
  final VoidCallback? onEnterPressed;
  final bool enabled;

  const MultiplayerKeyboard({
    Key? key,
    required this.keyboardColors,
    this.onKeyPressed,
    this.onDeletePressed,
    this.onEnterPressed,
    this.enabled = true,
  }) : super(key: key);

  static const List<List<String>> _keyboardRows = [
    ['E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
    ['Z', 'C', 'V', 'B', 'N', 'M'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ..._keyboardRows.map((row) => _buildRow(row)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildActionKey('DEL', onDeletePressed, enabled),
            const SizedBox(width: 8),
            _buildActionKey('ENTER', onEnterPressed, enabled),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(List<String> keys) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: keys.map((key) => _buildKey(key)).toList(),
      ),
    );
  }

  Widget _buildKey(String key) {
    final color = keyboardColors[key] ?? Colors.grey[800]!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ElevatedButton(
        onPressed: enabled && onKeyPressed != null ? () => onKeyPressed!(key) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size(36, 48),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildActionKey(String label, VoidCallback? onPressed, bool enabled) {
    return ElevatedButton(
      onPressed: enabled && onPressed != null ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueGrey[700],
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 48),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
} 