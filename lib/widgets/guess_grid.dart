import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/wordle_viewmodel.dart';

class GuessGrid extends StatefulWidget {
  final double screenWidth;
  
  const GuessGrid({Key? key, required this.screenWidth}) : super(key: key);

  @override
  State<GuessGrid> createState() => _GuessGridState();
}

class _GuessGridState extends State<GuessGrid> with TickerProviderStateMixin {
  late AnimationController _borderController;
  late Animation<double> _borderAnimation;
  bool _shouldShowRedBorder = false;

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _borderController.dispose();
    super.dispose();
  }

  void _checkForInvalidWord(WordleViewModel viewModel) {
    // Geçersiz kelime durumunda kırmızı border animasyonunu başlat
    if (viewModel.needsShake && !_shouldShowRedBorder) {
      setState(() {
        _shouldShowRedBorder = true;
      });
      
      // Yanıp sönme animasyonu (3 kez)
      _borderController.repeat(reverse: true);
      
      // 1.5 saniye sonra animasyonu durdur
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

  @override
  Widget build(BuildContext context) {
    return Consumer<WordleViewModel>(
      builder: (context, viewModel, child) {
        // Geçersiz kelime kontrolü
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkForInvalidWord(viewModel);
        });

        // Toplam horizontal padding ve margin hesaplama
        double totalHorizontalPadding = 10.0 * 2; // Sol ve sağ padding
        double totalBoxMargin = 4.0 * viewModel.currentWordLength; // Her kutu için 4px margin (2px her taraf)
        
        // Kullanılabilir genişliği hesaplama (extra güvenlik marjı)
        double availableWidth = widget.screenWidth - totalHorizontalPadding - totalBoxMargin - 8.0;
        
        // Kutucuk genişliğini hesaplama (8 harfli kelimeler için optimizasyon)
        double boxSize = availableWidth / viewModel.currentWordLength;
        
        // Kelime uzunluğuna göre dinamik boyut sınırları
        if (viewModel.currentWordLength <= 5) {
          boxSize = boxSize.clamp(40.0, 55.0);
        } else if (viewModel.currentWordLength <= 6) {
          boxSize = boxSize.clamp(35.0, 50.0);
        } else {
          boxSize = boxSize.clamp(25.0, 40.0);
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            mainAxisSize: MainAxisSize.min,
            children: List.generate(WordleViewModel.maxAttempts, (row) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 0.5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(viewModel.currentWordLength, (col) {
                    // Geçersiz kelime durumunda border rengini belirle
                    Color borderColor = Colors.grey.shade400;
                    double borderWidth = 1.5;
                    
                    if (_shouldShowRedBorder && row == viewModel.currentAttempt) {
                      return AnimatedBuilder(
                        animation: _borderAnimation,
                        builder: (context, child) {
                          final animatedBorderColor = Color.lerp(
                            Colors.grey.shade400,
                            Colors.red.shade400,
                            _borderAnimation.value,
                          )!;
                          
                          return Container(
                            margin: const EdgeInsets.all(2),
                            width: boxSize,
                            height: boxSize,
                            decoration: BoxDecoration(
                              color: viewModel.getBoxColor(row, col),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: animatedBorderColor,
                                width: 2.0 + (_borderAnimation.value * 1.0), // 2-3px arası
                              ),
                              boxShadow: _borderAnimation.value > 0.5 ? [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.4),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ] : null,
                            ),
                            alignment: Alignment.center,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Text(
                                    viewModel.guesses[row][col],
                                    style: TextStyle(
                                      fontSize: boxSize * 0.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  // İpucu harfini göster
                                  if (viewModel.guesses[row][col].isEmpty && 
                                      row == viewModel.currentAttempt && 
                                      viewModel.isHintRevealed(col))
                                    Text(
                                      viewModel.getHintLetter(col),
                                      style: TextStyle(
                                        fontSize: boxSize * 0.4,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber.withOpacity(0.7),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }

                    // Normal kutular
                    return Container(
                      margin: const EdgeInsets.all(2),
                      width: boxSize,
                      height: boxSize,
                      decoration: BoxDecoration(
                        color: viewModel.getBoxColor(row, col),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor, width: borderWidth),
                      ),
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              viewModel.guesses[row][col],
                              style: TextStyle(
                                fontSize: boxSize * 0.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            // İpucu harfini göster
                            if (viewModel.guesses[row][col].isEmpty && 
                                row == viewModel.currentAttempt && 
                                viewModel.isHintRevealed(col))
                              Text(
                                viewModel.getHintLetter(col),
                                style: TextStyle(
                                  fontSize: boxSize * 0.4,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.withOpacity(0.7),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
        );
      },
    );
  }
} 