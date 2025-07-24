import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/matchmaking_viewmodel.dart';
import 'duel_game_page.dart';
import 'dart:math' as math;

class DuelMatchmakingPage extends StatefulWidget {
  const DuelMatchmakingPage({Key? key}) : super(key: key);

  @override
  State<DuelMatchmakingPage> createState() => _DuelMatchmakingPageState();
}

class _DuelMatchmakingPageState extends State<DuelMatchmakingPage>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnimation;

  // Animasyonlar için ek controllerlar
  late AnimationController _titleController;
  late AnimationController _iconSpinController;
  late AnimationController _statsFadeController;
  late Animation<double> _titleAnimation;
  late Animation<double> _iconSpinAnimation;
  late Animation<double> _statsFadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _iconSpinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), // Daha hızlı döndür
    )..repeat();
    _statsFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _titleAnimation = CurvedAnimation(
      parent: _titleController,
      curve: Curves.elasticOut,
    );
    _iconSpinAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _iconSpinController, curve: Curves.linear),
    );
    _statsFadeAnimation = CurvedAnimation(
      parent: _statsFadeController,
      curve: Curves.easeOut,
    );
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _progressController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    _titleController.dispose();
    _iconSpinController.dispose();
    _statsFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MatchmakingViewModel>(
      builder: (context, viewModel, child) {
        // Eşleştirme durumunda oyun sayfasına yönlendir
        if (viewModel.isMatched && viewModel.gameId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => DuelGamePage(gameId: viewModel.gameId!),
              ),
            );
          });
        }
        return Scaffold(
          backgroundColor: const Color(0xFF0A0A0A), // Ana sayfa ile aynı koyu arka plan
          body: Stack(
            children: [
              // Arka plan grid animasyonu
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _GridPainter(_pulseAnimation.value),
                    size: Size.infinite,
                  );
                },
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildAnimatedGameTitle(),
                      const SizedBox(height: 24),
                      Expanded(
                        child: _buildMatchmakingArea(viewModel),
                      ),
                      _buildBottomActions(viewModel),
                    ],
                  ),
                ),
              ),
            ],
          ),
          appBar: _buildWordleStyleAppBar(viewModel),
        );
      },
    );
  }

  Widget _buildAnimatedGameTitle() {
    const word = 'DÜELLO';
    final colors = [
      const Color(0xFF538D4E),
      const Color(0xFFC9B458),
      const Color(0xFF787C7E),
      const Color(0xFF538D4E),
      const Color(0xFFC9B458),
      const Color(0xFF787C7E),
    ];
    return AnimatedBuilder(
      animation: _titleAnimation,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(word.length, (index) {
            final delay = index * 0.08;
            final animValue = (_titleAnimation.value - delay).clamp(0.0, 1.0);
            return Opacity(
              opacity: animValue,
              child: Transform.scale(
                scale: animValue,
                child: Container(
                  width: 38,
                  height: 38,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colors[index % colors.length],
                        colors[index % colors.length].withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: colors[index % colors.length].withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    word[index],
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  PreferredSizeWidget _buildWordleStyleAppBar(MatchmakingViewModel viewModel) {
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
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  Widget _buildMatchmakingArea(MatchmakingViewModel viewModel) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ana ikon ve animasyon
          _buildMatchmakingIcon(viewModel),
          
          const SizedBox(height: 24),
          
          // Durum metni
          _buildStatusText(viewModel),
          
          const SizedBox(height: 20),
          
          // İlerleme çubuğu
          _buildProgressBar(viewModel),
          
          const SizedBox(height: 24),
          
          // İstatistikler
          _buildMatchmakingStats(viewModel),
        ],
      ),
    );
  }

  Widget _buildMatchmakingIcon(MatchmakingViewModel viewModel) {
    return AnimatedBuilder(
      animation: viewModel.isSearching ? _iconSpinAnimation : _pulseAnimation,
      builder: (context, child) {
        final iconWidget = Icon(
          viewModel.isSearching 
            ? Icons.search 
            : Icons.sports_kabaddi,
          size: 40,
          color: Colors.white,
        );
        return Transform.scale(
          scale: viewModel.isSearching ? _pulseAnimation.value : 1.0,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: viewModel.isSearching 
                ? const Color(0xFF6AAA64) 
                : const Color(0xFF232323),
              border: Border.all(
                color: viewModel.isSearching 
                  ? const Color(0xFF538D4E)
                  : const Color(0xFF787C7E),
                width: 2,
              ),
              boxShadow: viewModel.isSearching
                ? [
                    BoxShadow(
                      color: const Color(0xFF6AAA64).withOpacity(0.6),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
            ),
            child: viewModel.isSearching
              ? Transform.rotate(
                  angle: _iconSpinAnimation.value,
                  child: iconWidget,
                )
              : iconWidget,
          ),
        );
      },
    );
  }

  Widget _buildStatusText(MatchmakingViewModel viewModel) {
    String title = '';
    String subtitle = '';
    Color titleColor = Colors.white;

    if (viewModel.isSearching) {
      title = 'Rakip Aranıyor';
      subtitle = 'Sana uygun bir oyuncu buluyoruz';
      titleColor = const Color(0xFF6AAA64);
    } else if (viewModel.hasError) {
      title = 'Bağlantı Hatası';
      subtitle = 'Tekrar deneyin veya bağlantınızı kontrol edin';
      titleColor = Colors.red;
    } else {
      title = 'Düello Oyna';
      subtitle = 'Gerçek oyuncularla 1vs1 kelime yarışması';
      titleColor = Colors.white;
    }

    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color: titleColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF787C7E),
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildProgressBar(MatchmakingViewModel viewModel) {
    if (!viewModel.isSearching) return const SizedBox();

    return Column(
      children: [
        // İlerleme çubuğu
        Container(
          width: double.infinity,
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFF3A3A3C),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: viewModel.searchProgress / 100,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6AAA64)),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Süre göstergesi
        Text(
          'Tahmini süre: ${viewModel.estimatedWaitTime} saniye',
          style: const TextStyle(
            color: Color(0xFF787C7E),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildMatchmakingStats(MatchmakingViewModel viewModel) {
    return FadeTransition(
      opacity: _statsFadeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(_statsFadeAnimation),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2A2A2D), Color(0xFF1A1A1D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF538D4E), width: 1.2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatCard(
                'Bekleyen',
                '${viewModel.waitingPlayersCount}',
                Icons.people_outline,
              ),
              Container(
                width: 1,
                height: 36,
                color: const Color(0xFF232323),
              ),
              _buildStatCard(
                'Ortalama',
                '${viewModel.averageMatchTime}s',
                Icons.timer_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: const Color(0xFF6AAA64),
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF787C7E),
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildBottomActions(MatchmakingViewModel viewModel) {
    return Column(
      children: [
        if (viewModel.isSearching) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => viewModel.cancelMatchmaking(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                elevation: 0,
              ),
              child: const Text(
                'İptal Et',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ] else ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => viewModel.startMatchmaking(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6AAA64),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                elevation: 0,
              ),
              child: Text(
                viewModel.hasError ? 'Tekrar Dene' : 'Rakip Ara',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => viewModel.startTestMode(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF232323)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                'Test Modu (Bot ile Oyna)',
                style: TextStyle(
                  color: Color(0xFF787C7E),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _buildInfoSection(),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A2A2D), Color(0xFF1A1A1D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF538D4E), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kurallar',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          _buildRuleItem('• Her iki oyuncu da aynı kelimeyi tahmin eder'),
          _buildRuleItem('• 6 deneme hakkınız vardır'),
          _buildRuleItem('• İlk doğru bilen kazanır'),
          _buildRuleItem('• Jokerler oyun sırasında kullanılabilir'),
        ],
      ),
    );
  }

  Widget _buildRuleItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF787C7E),
          fontSize: 12,
        ),
      ),
    );
  }
} 

// Grid painter (arka plan için)
class _GridPainter extends CustomPainter {
  final double animationValue;
  _GridPainter(this.animationValue);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF232323).withOpacity(0.18 + animationValue * 0.08)
      ..strokeWidth = 1;
    for (double i = 0; i < size.width; i += 60) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 60) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 