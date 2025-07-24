import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/duel_viewmodel.dart';
import '../services/haptic_service.dart';
import '../widgets/keyboard_widget.dart';
import '../widgets/shake_widget.dart';
import '../views/duel_result_page.dart'; // Sonuç ekranına yönlendirmek için eklendi
import '../services/duel_service.dart'; // Oyun silmek için eklendi

class DuelGamePage extends StatefulWidget {
  final String gameId;
  final VoidCallback? toggleTheme;

  const DuelGamePage({
    Key? key,
    required this.gameId,
    this.toggleTheme,
  }) : super(key: key);

  @override
  State<DuelGamePage> createState() => _DuelGamePageState();
}

class _DuelGamePageState extends State<DuelGamePage> {
  late DuelViewModel _viewModel;
  late VoidCallback _listener;

  @override
  void initState() {
    super.initState();
    _viewModel = Provider.of<DuelViewModel>(context, listen: false);
    
    _listener = () {
      if (_viewModel.isGameFinished) {
        _navigateToResultPage();
      }
    };
    _viewModel.addListener(_listener);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.startGame(widget.gameId);
    });
  }

  @override
  void dispose() {
    _viewModel.removeListener(_listener);
    super.dispose();
  }

  // Sonuç ekranına yönlendirme fonksiyonu
  Future<void> _navigateToResultPage() async {
    try {
      // Sonuç sayfasına hemen git
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DuelResultPage(
              isWinner: (_viewModel.currentPlayer?.isWinner == true) || (_viewModel.currentGame?.winnerId == _viewModel.currentPlayerId),
              secretWord: _viewModel.secretWord,
              myAttempts: _viewModel.currentAttempt,
              opponentAttempts: _viewModel.opponentPlayer?.guesses.length,
              elapsedSeconds: _viewModel.elapsedSeconds,
            ),
          ),
        );
      }
      // Temizlik işlemlerini beklemeden başlat
      _viewModel.leaveGame();
      DuelService.deleteGame(widget.gameId);
      // await Future.delayed(const Duration(milliseconds: 200)); // Artık gerek yok
    } catch (e) {
      print('❌ Sonuç sayfasına yönlendirme hatası: $e');
      // Hata olsa bile sonuç sayfasına git
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DuelResultPage(
              isWinner: false,
              secretWord: _viewModel.secretWord,
              myAttempts: _viewModel.currentAttempt,
              opponentAttempts: 0,
              elapsedSeconds: _viewModel.elapsedSeconds,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DuelViewModel>(
      builder: (context, viewModel, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF121213),
          appBar: _buildAppBar(viewModel),
          body: SafeArea(
            child: Column(
              children: [
                // Ana oyun alanı - İki taraf yan yana
                Expanded(
                  flex: 4,
                  child: _buildDuelGameArea(viewModel),
                ),
                
                // Joker paneli - Küçük butonlar
                _buildCompactJokerPanel(viewModel),
                
                // Klavye
                Expanded(
                  flex: 2,
                  child: _buildKeyboardArea(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(DuelViewModel viewModel) {
    return AppBar(
      title: const Text(
        'DÜELLO',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          letterSpacing: 0.5,
        ),
      ),
      centerTitle: true,
      backgroundColor: const Color(0xFF121213),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, size: 20),
        onPressed: () => _showLeaveDialog(viewModel),
      ),
      actions: [
        // Jeton bakiyesi
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF23232A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
              const SizedBox(width: 4),
              Text(
                viewModel.tokens.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDuelGameArea(DuelViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          // Başlıklar
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2C),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '👤 Sen',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2C),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '🤖 Rakip',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Grid'ler yan yana
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sol taraf - Benim grid'im
                Expanded(
                  child: ShakeWidget(
                    shake: viewModel.showShakeAnimation,
                    onShakeComplete: () => viewModel.resetShake(),
                    child: _buildPlayerGrid(true, viewModel),
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Sağ taraf - Rakip grid'i
                Expanded(
                  child: Consumer<DuelViewModel>(
                    builder: (context, duelViewModel, _) => _buildPlayerGrid(false, duelViewModel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerGrid(bool isMyGrid, DuelViewModel viewModel) {
    Widget grid = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMyGrid ? const Color(0xFF4A9EFF) : const Color(0xFFFF6B6B),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(6, (row) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: List.generate(5, (col) {
                return Expanded(
                  child: Container(
                    height: 32,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: _getTileColor(row, col, isMyGrid, viewModel),
                      border: Border.all(
                        color: _getTileBorderColor(row, col, isMyGrid, viewModel),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        _getTileLetter(row, col, isMyGrid, viewModel),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );

    return grid;
  }

  // Klasik Wordle renk algoritması: tekrar eden harflerde doğru çalışır
  List<Color> _getWordleColors(List<String> guess, String secretWord) {
    final int length = guess.length;
    final List<Color> colors = List.filled(length, const Color(0xFF787C7E)); // Gri
    final List<String> secret = secretWord.split('');
    final List<bool> secretUsed = List.filled(length, false);

    // 1. Geçiş: Doğru yerdeki harfler (yeşil)
    for (int i = 0; i < length; i++) {
      if (guess[i] == secret[i]) {
        colors[i] = const Color(0xFF6AAA64); // Yeşil
        secretUsed[i] = true;
      }
    }
    // 2. Geçiş: Yanlış yerdeki harfler (sarı)
    for (int i = 0; i < length; i++) {
      if (colors[i] == const Color(0xFF6AAA64)) continue;
      for (int j = 0; j < length; j++) {
        if (!secretUsed[j] && guess[i] == secret[j]) {
          colors[i] = const Color(0xFFC9B458); // Sarı
          secretUsed[j] = true;
          break;
        }
      }
    }
    return colors;
  }

  Color _getTileColor(int row, int col, bool isMyGrid, DuelViewModel viewModel) {
    if (isMyGrid) {
      // Benim grid'im
      if (row == viewModel.currentAttempt) {
        // Aktif satır - şu an yazılan kelime
        if (col < viewModel.currentLetters.length) {
          return const Color(0xFF3A3A3C); // Yazılan harfler
        }
        return const Color(0xFF121213); // Boş kutucuklar
      } else if (row < viewModel.currentAttempt) {
        // Geçmiş tahminler - renk kodlaması
        final player = viewModel.currentPlayer;
        if (player != null && row < player.guesses.length) {
          final guess = player.guesses[row];
          if (guess.length == 5) {
            final colors = _getWordleColors(guess, viewModel.secretWord);
            return colors[col];
          }
        }
        return const Color(0xFF121213); // Boş
      }
    } else {
      // Rakip grid'i
      final player = viewModel.opponentPlayer;
      if (player != null && row < player.guesses.length) {
        final guess = player.guesses[row];
        if (guess.length == 5) {
          final colors = _getWordleColors(guess, viewModel.secretWord);
          return colors[col];
        }
      }
    }
    return const Color(0xFF121213); // Boş kutucuk
  }

  Color _getTileBorderColor(int row, int col, bool isMyGrid, DuelViewModel viewModel) {
    if (isMyGrid && row == viewModel.currentAttempt) {
      if (col < viewModel.currentLetters.length) {
        return const Color(0xFF565758); // Aktif harf kenarı
      }
      return const Color(0xFF3A3A3C); // Aktif satır kenarı
    }
    return Colors.transparent;
  }

  String _getTileLetter(int row, int col, bool isMyGrid, DuelViewModel viewModel) {
    if (isMyGrid) {
      // Benim grid'im
      if (row == viewModel.currentAttempt) {
        // Şu an yazılan kelime
        if (col < viewModel.currentLetters.length) {
          return viewModel.currentLetters[col];
        }
        return '';
      } else if (row < viewModel.currentAttempt) {
        // Geçmiş tahminler
        final player = viewModel.currentPlayer;
        if (player != null && row < player.guesses.length) {
          final guess = player.guesses[row];
          if (col < guess.length) {
            return guess[col];
          }
        }
      }
    } else {
      // Rakip grid'i
      if (!viewModel.isOpponentRevealed) {
        // Joker kullanılmadıysa her kutuda ? göster
        return '?';
      }
      final player = viewModel.opponentPlayer;
      if (player != null && row < player.guesses.length) {
        final guess = player.guesses[row];
        if (col < guess.length) {
          return guess[col];
        }
      }
    }
    return '';
  }

  Widget _buildCompactJokerPanel(DuelViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFF3A3A3C), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildJokerButton(
            emoji: '🎯',
            cost: '10💰',
            onTap: () async {
              final confirmed = await _showJokerConfirmDialog(
                context,
                '🎯 Harf Jokeri',
                'Kelimedeki rastgele bir doğru harfi açmak için 10 jeton harcanacak. Emin misin?',
                '10💰',
              );
              if (confirmed == true) {
                final revealed = await viewModel.useJoker('letter_hint');
                if (revealed == null) {
                  if (viewModel.letterHintUsedCount >= viewModel.maxLetterHint) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color(0xFF23232A),
                        title: const Text('Joker Limiti', style: TextStyle(color: Colors.white)),
                        content: const Text('Bu jokeri en fazla 3 kez kullanabilirsin.', style: TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Tamam'),
                          ),
                        ],
                      ),
                    );
                  } else {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color(0xFF23232A),
                        title: const Text('Yetersiz Jeton', style: TextStyle(color: Colors.white)),
                        content: const Text('Bu jokeri kullanmak için yeterli jetonun yok.', style: TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Tamam'),
                          ),
                        ],
                      ),
                    );
                  }
                } else {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF23232A),
                      title: const Text('Açılan Harf', style: TextStyle(color: Colors.white)),
                      content: Text('Açılan harf: $revealed', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Tamam'),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
            extra: 'x${viewModel.maxLetterHint - viewModel.letterHintUsedCount}',
          ),
          _buildJokerButton(
            emoji: '👀',
            cost: '20💰',
            onTap: () async {
              final confirmed = await _showJokerConfirmDialog(
                context,
                '👀 Rakip Jokeri',
                'Rakibin doğru bildiği kelimeleri görmek için 20 jeton harcanacak. Emin misin?',
                '20💰',
              );
              if (confirmed == true) {
                final result = await viewModel.useJoker('opponent_words');
                if (result == null && viewModel.isOpponentRevealed == false) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF23232A),
                      title: const Text('Yetersiz Jeton', style: TextStyle(color: Colors.white)),
                      content: const Text('Bu jokeri kullanmak için yeterli jetonun yok.', style: TextStyle(color: Colors.white70)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Tamam'),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
          ),
          _buildJokerButton(
            emoji: '🔍',
            cost: '8💰',
            onTap: () async {
              final confirmed = await _showJokerConfirmDialog(
                context,
                '🔍 İlk Tahmin Jokeri',
                'Rakibin ilk tahminini görmek için 8 jeton harcanacak. Emin misin?',
                '8💰',
              );
              if (confirmed == true) {
                final result = await viewModel.useJoker('first_guess');
                if (result == null) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF23232A),
                      title: const Text('Yetersiz Jeton', style: TextStyle(color: Colors.white)),
                      content: const Text('Bu jokeri kullanmak için yeterli jetonun yok.', style: TextStyle(color: Colors.white70)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Tamam'),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildJokerButton({
    required String emoji,
    required String cost,
    required VoidCallback onTap,
    String? extra,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF3A3A3C),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 16),
            ),
            if (extra != null) ...[
              const SizedBox(width: 4),
              Text(
                extra,
                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
            const SizedBox(width: 4),
            Text(
              cost,
              style: const TextStyle(
                color: Color(0xFFCEB458),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyboardArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: const KeyboardWidget(isDuelMode: true),
    );
  }

  void _useJoker(String jokerType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1F23),
        title: const Text(
          'Joker Kullan',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          _getJokerDescription(jokerType),
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              HapticService.triggerMediumHaptic();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6AAA64)),
            child: const Text(
              'Kullan',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String _getJokerDescription(String jokerType) {
    switch (jokerType) {
      case 'letter_hint':
        return '🎯 Kelimedeki rastgele bir doğru harfi gösterir.';
      case 'opponent_words':
        return '👀 Rakibin doğru bildiği kelimeleri gösterir.';
      case 'first_guess':
        return '🔍 Rakibin ilk tahminini gösterir.';
      default:
        return '';
    }
  }

  void _showLeaveDialog(DuelViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1F23),
        title: const Text(
          'Oyundan Çık',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Oyundan çıkarsan kaybetmiş sayılacaksın.\nEmin misin?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await viewModel.leaveGame();
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Çık',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showJokerConfirmDialog(BuildContext context, String title, String content, String cost) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF23232A),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(content, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6AAA64)),
            child: Text('Evet, Kullan ($cost)', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
} 