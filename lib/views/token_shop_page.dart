import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import '../services/ad_service.dart';
import 'dart:async';

// Jeton dükkânı sayfası

class TokenShopPage extends StatefulWidget {
  const TokenShopPage({Key? key}) : super(key: key);

  @override
  State<TokenShopPage> createState() => _TokenShopPageState();
}

class _TokenShopPageState extends State<TokenShopPage> 
    with TickerProviderStateMixin {
  int _userTokens = 0;
  bool _isLoading = true;
  bool _isWatchingAd = false;
  bool _isClaimingBonus = false;
  
  // Günlük bonus bilgileri
  Map<String, dynamic> _dailyBonusInfo = {};
  Timer? _countdownTimer;
  String _timeUntilNext = '';
  
  // Animasyon
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadUserData();
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final tokens = await FirebaseService.getUserTokens(user.uid);
      final dailyInfo = await FirebaseService.getDailyBonusInfo(user.uid);
      
      setState(() {
        _userTokens = tokens;
        _dailyBonusInfo = dailyInfo;
        _isLoading = false;
      });
    }
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_dailyBonusInfo.isNotEmpty) {
        final timeUntil = _dailyBonusInfo['timeUntilNext'] as Duration?;
        if (timeUntil != null) {
          final remainingTime = timeUntil - Duration(seconds: timer.tick);
          if (remainingTime.isNegative) {
            // Bonus artık alınabilir, verileri yenile
            _loadUserData();
          } else {
            setState(() {
              _timeUntilNext = _formatDuration(remainingTime);
            });
          }
        }
      }
    });
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _watchAdForTokens() async {
    if (_isWatchingAd) return;
    
    setState(() {
      _isWatchingAd = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      if (!AdService.isRewardedAdReady()) {
        _showSnackBar('🎥 Reklam şu anda mevcut değil. Lütfen daha sonra tekrar deneyin.', Colors.orange);
        return;
      }

      bool success = await AdService.showRewardedAd(user.uid);
      if (success) {
        _showSnackBar('🎉 1 jeton kazandınız!', Colors.green);
        await _loadUserData();
      } else {
        _showSnackBar('❌ Reklam izlenemedi. Lütfen tekrar deneyin.', Colors.red);
      }
    } catch (e) {
      _showSnackBar('⚠️ Bir hata oluştu: $e', Colors.red);
    } finally {
      setState(() {
        _isWatchingAd = false;
      });
    }
  }

  Future<void> _claimDailyBonus() async {
    if (_isClaimingBonus) return;
    
    setState(() {
      _isClaimingBonus = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      bool success = await FirebaseService.earnDailyBonus(user.uid);
      if (success) {
        final bonusAmount = _dailyBonusInfo['bonusAmount'] as int;
        _showSnackBar('🎁 $bonusAmount jeton günlük bonus kazandınız!', Colors.green);
        await _loadUserData();
      } else {
        _showSnackBar('⏰ Günlük bonus zaten alınmış.', Colors.orange);
      }
    } catch (e) {
      _showSnackBar('⚠️ Bir hata oluştu: $e', Colors.red);
    } finally {
      setState(() {
        _isClaimingBonus = false;
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: _isLoading ? _buildLoadingState() : _buildMainContent(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Colors.amber,
            strokeWidth: 3,
          ),
          SizedBox(height: 16),
          Text(
            'Jeton dükkânı yükleniyor...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return CustomScrollView(
      slivers: [
        _buildAppBar(),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildTokenBalance(),
              const SizedBox(height: 24),
              _buildDailyBonusSection(),
              const SizedBox(height: 24),
              _buildEarnTokensSection(),
              const SizedBox(height: 24),
                             _buildSpendTokensSection(),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF0A0A0A),
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Jeton Dükkânı',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1A1A2E),
                Color(0xFF16213E),
                Color(0xFF0A0A0A),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTokenBalance() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF667eea),
            Color(0xFF764ba2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mevcut Bakiye',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.monetization_on,
                        color: Colors.amber,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_userTokens',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        ' jeton',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyBonusSection() {
    final canClaim = _dailyBonusInfo['canClaim'] as bool? ?? false;
    final currentStreak = _dailyBonusInfo['currentStreak'] as int? ?? 0;
    final bonusAmount = _dailyBonusInfo['bonusAmount'] as int? ?? 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🎁 Günlük Bonus',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: canClaim 
                ? [const Color(0xFF833ab4), const Color(0xFFfd1d1d), const Color(0xFFfcb045)]
                : [const Color(0xFF2C2C2C), const Color(0xFF1A1A1A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: canClaim
                ? Border.all(color: Colors.amber.withOpacity(0.5), width: 2)
                : null,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: canClaim ? _pulseAnimation.value : 1.0,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: canClaim 
                                ? Colors.amber.withOpacity(0.2)
                                : Colors.grey.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.card_giftcard,
                            color: canClaim ? Colors.amber : Colors.grey,
                            size: 32,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Günlük Bonus ',
                              style: TextStyle(
                                color: canClaim ? Colors.white : Colors.grey,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${currentStreak + 1}. gün',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          canClaim 
                              ? '$bonusAmount jeton kazanabilirsin!' 
                              : 'Sonraki bonus: $_timeUntilNext',
                          style: TextStyle(
                            color: canClaim ? Colors.white70 : Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.monetization_on, 
                              color: canClaim ? Colors.amber : Colors.grey,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '+$bonusAmount',
                              style: TextStyle(
                                color: canClaim ? Colors.amber : Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: canClaim && !_isClaimingBonus ? _claimDailyBonus : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canClaim ? Colors.amber : Colors.grey,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: _isClaimingBonus
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            canClaim ? 'Al' : 'Alındı',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
              if (currentStreak > 0) ...[
                const SizedBox(height: 16),
                _buildStreakIndicator(currentStreak),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStreakIndicator(int streak) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            'Günlük Seri',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(15, (index) {
                final day = index + 1;
                final isCompleted = day <= streak;
                final isCurrent = day == streak + 1;
                final tokenAmount = day.clamp(1, 15);
                
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isCompleted 
                        ? Colors.amber 
                        : isCurrent 
                            ? Colors.amber.withOpacity(0.3)
                            : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: isCurrent 
                        ? Border.all(color: Colors.amber, width: 2)
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          color: isCompleted ? Colors.black : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$tokenAmount',
                        style: TextStyle(
                          color: isCompleted ? Colors.black : Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarnTokensSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '💰 Jeton Kazan',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildAdWatchCard(),
        const SizedBox(height: 12),
        _buildGameWinCard(),
      ],
    );
  }

  Widget _buildAdWatchCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF11998e).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.play_circle_fill,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reklam İzle',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '30 saniyelik video izleyerek jeton kazan',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                    SizedBox(width: 4),
                    Text(
                      '+1 jeton',
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _isWatchingAd ? null : _watchAdForTokens,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF11998e),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: _isWatchingAd
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Color(0xFF11998e),
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'İzle',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameWinCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.emoji_events,
              color: Colors.amber,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Oyun Kazan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Kelime oyunlarını kazanarak jeton kazan',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                    SizedBox(width: 4),
                    Text(
                      '+1 jeton',
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(
            Icons.info_outline,
            color: Colors.white70,
          ),
        ],
      ),
    );
  }

  Widget _buildSpendTokensSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🛒 Jeton Kullan',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildHintCard(),
      ],
    );
  }

  Widget _buildHintCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.lightbulb,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Harf İpucu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Oyun sırasında bir harfi açığa çıkar',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.monetization_on, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      '3 jeton',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(
            Icons.info_outline,
            color: Colors.white70,
          ),
        ],
      ),
    );
  }

  

} 