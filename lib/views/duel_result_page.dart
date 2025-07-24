import 'package:flutter/material.dart';
import 'home_page.dart';

class DuelResultPage extends StatelessWidget {
  final bool isWinner;
  final String secretWord;
  final int myAttempts;
  final int? opponentAttempts;
  final int elapsedSeconds;

  const DuelResultPage({
    Key? key,
    required this.isWinner,
    required this.secretWord,
    required this.myAttempts,
    this.opponentAttempts,
    required this.elapsedSeconds,
  }) : super(key: key);

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes}:${secs.toString().padLeft(2, '0')}' ;
  }

  @override
  Widget build(BuildContext context) {
    final Color mainColor = isWinner ? const Color(0xFF6AAA64) : const Color(0xFFFF6B6B);
    final String title = isWinner ? 'Kazandın' : 'Kaybettin';
    final String emoji = isWinner ? '🎉' : '😔';
    final double width = MediaQuery.of(context).size.width;
    final double statBoxWidth = width > 400 ? 340 : width * 0.85;
    final double statIconSize = 22;
    final double statFontSize = 16;
    final double statLabelFontSize = 14;

    return Scaffold(
      backgroundColor: const Color(0xFF121213),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Başlık
                Text(
                  title,
                  style: TextStyle(
                    color: mainColor,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Emoji
                Text(
                  emoji,
                  style: const TextStyle(fontSize: 40),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                // İstatistikler
                _buildStatCard(
                  icon: Icons.vpn_key,
                  label: 'Gizli kelime',
                  value: secretWord,
                  width: statBoxWidth,
                  iconSize: statIconSize,
                  fontSize: statFontSize,
                  labelFontSize: statLabelFontSize,
                ),
                const SizedBox(height: 12),
                _buildStatCard(
                  icon: Icons.person,
                  label: 'Senin deneme',
                  value: myAttempts.toString(),
                  width: statBoxWidth,
                  iconSize: statIconSize,
                  fontSize: statFontSize,
                  labelFontSize: statLabelFontSize,
                ),
                const SizedBox(height: 12),
                _buildStatCard(
                  icon: Icons.person_outline,
                  label: 'Rakip deneme',
                  value: opponentAttempts != null ? opponentAttempts.toString() : '-',
                  width: statBoxWidth,
                  iconSize: statIconSize,
                  fontSize: statFontSize,
                  labelFontSize: statLabelFontSize,
                ),
                const SizedBox(height: 12),
                // Süre
                _buildStatCard(
                  icon: Icons.timer,
                  label: 'Süre',
                  value: _formatDuration(elapsedSeconds),
                  width: statBoxWidth,
                  iconSize: statIconSize,
                  fontSize: statFontSize,
                  labelFontSize: statLabelFontSize,
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => HomePage()),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mainColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Ana Menüye Dön',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required double width,
    required double iconSize,
    required double fontSize,
    required double labelFontSize,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF23232A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: iconSize),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.white70, fontSize: labelFontSize),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
} 