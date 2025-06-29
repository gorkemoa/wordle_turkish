import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import '../services/ad_service.dart';
import 'dart:async';

// Sadeleştirilmiş Jeton Dükkanı Sayfası

class TokenShopPage extends StatefulWidget {
  const TokenShopPage({Key? key}) : super(key: key);

  @override
  State<TokenShopPage> createState() => _TokenShopPageState();
}

class _TokenShopPageState extends State<TokenShopPage> {
  int _userTokens = 0;
  bool _isLoading = true;
  bool _isWatchingAd = false;
  bool _isClaimingBonus = false;

  Map<String, dynamic> _dailyBonusInfo = {};
  Timer? _countdownTimer;
  String _timeUntilNext = '';

  final List<Map<String, dynamic>> _tokenPackages = [
    {
      'id': 'small_pack',
      'tokens': 50,
      'price': '₺9.99',
      'priceUsd': 0.99,
      'bonus': 0,
      'title': 'Başlangıç Paketi',
      'icon': Icons.favorite_border,
    },
    {
      'id': 'medium_pack',
      'tokens': 150,
      'price': '₺24.99',
      'priceUsd': 2.99,
      'bonus': 25,
      'title': 'Popüler Paket',
      'icon': Icons.star_border,
      'popular': true,
    },
    {
      'id': 'large_pack',
      'tokens': 500,
      'price': '₺69.99',
      'priceUsd': 7.99,
      'bonus': 100,
      'title': 'Süper Paket',
      'icon': Icons.diamond_outlined,
    },
    {
      'id': 'mega_pack',
      'tokens': 1000,
      'price': '₺129.99',
      'priceUsd': 14.99,
      'bonus': 300,
      'title': 'Mega Paket',
      'icon': Icons.auto_awesome_outlined,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final tokens = await FirebaseService.getUserTokens(user.uid);
      final dailyInfo = await FirebaseService.getDailyBonusInfo(user.uid);

      if (mounted) {
        setState(() {
          _userTokens = tokens;
          _dailyBonusInfo = dailyInfo;
          _isLoading = false;
        });
      }
    } else {
      setState(() {
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
            _loadUserData();
          } else {
            if (mounted) {
              setState(() {
                _timeUntilNext = _formatDuration(remainingTime);
              });
            }
          }
        }
      }
    });
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _watchAdForTokens() async {
    if (_isWatchingAd) return;

    setState(() {
      _isWatchingAd = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnackBar('Lütfen önce giriş yapın.', Colors.red);
        return;
      }

      if (!AdService.isRewardedAdReady()) {
        _showSnackBar('🎥 Reklam şu anda hazır değil. Lütfen biraz bekleyin.', Colors.orange);
        return;
      }

      bool success = await AdService.showRewardedAd(user.uid);
      if (success) {
        _showSnackBar('🎉 Tebrikler! 2 jeton kazandınız!', Colors.green);
        await _loadUserData();
      } else {
        _showSnackBar('❌ Reklam tamamlanamadı. Tekrar deneyin.', Colors.red);
      }
    } catch (e) {
      _showSnackBar('⚠️ Bir hata oluştu: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isWatchingAd = false;
        });
      }
    }
  }

  Future<void> _claimDailyBonus() async {
    if (_isClaimingBonus) return;

    setState(() {
      _isClaimingBonus = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnackBar('Lütfen önce giriş yapın.', Colors.red);
        return;
      }

      bool success = await FirebaseService.earnDailyBonus(user.uid);
      if (success) {
        final bonusAmount = _dailyBonusInfo['bonusAmount'] as int;
        _showSnackBar('🎁 Muhteşem! $bonusAmount jeton günlük bonus kazandınız!', Colors.purple);
        await _loadUserData();
      } else {
        _showSnackBar('⏰ Günlük bonus zaten alınmış. Yarın tekrar gelin!', Colors.orange);
      }
    } catch (e) {
      _showSnackBar('⚠️ Bir hata oluştu: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isClaimingBonus = false;
        });
      }
    }
  }

  Future<void> _purchaseTokens(Map<String, dynamic> package) async {
    _showSnackBar('💳 Satın alma özelliği yakında eklenecek!', Colors.blue);
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: _isLoading ? _buildLoadingState() : _buildMainContent(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text(
            'Jeton Dükkânı Yükleniyor...',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: const Text('Jeton Dükkânı', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.grey[900],
          centerTitle: true,
          pinned: true,
          floating: true,
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16.0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildTokenBalance(),
              const SizedBox(height: 24),
              _buildSectionTitle('Ücretsiz Jetonlar', Icons.card_giftcard),
              _buildDailyBonusCard(),
              const SizedBox(height: 12),
              _buildAdWatchCard(),
              const SizedBox(height: 12),
              _buildGameRewardCard(),
              const SizedBox(height: 24),
              _buildSectionTitle('Jeton Paketleri', Icons.diamond_outlined),
              ..._tokenPackages.map((package) => _buildPackageCard(package)).toList(),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildTokenBalance() {
    return Card(
      color: Colors.grey[850],
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.monetization_on, color: Colors.amber, size: 40),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mevcut Bakiyeniz',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                Text(
                  '$_userTokens jeton',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyBonusCard() {
    final canClaim = _dailyBonusInfo['canClaim'] as bool? ?? false;
    final bonusAmount = _dailyBonusInfo['bonusAmount'] as int? ?? 1;

    return Card(
      color: Colors.grey[850],
      child: ListTile(
        leading: Icon(
          Icons.calendar_today,
          color: canClaim ? Colors.green : Colors.grey,
        ),
        title: Text(
          'Günlük Bonus',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          canClaim ? 'Bugünkü $bonusAmount jeton ödülünü al!' : 'Sonraki bonus: $_timeUntilNext',
          style: TextStyle(color: Colors.white70),
        ),
        trailing: ElevatedButton(
          onPressed: canClaim && !_isClaimingBonus ? _claimDailyBonus : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: canClaim ? Colors.green : Colors.grey[700],
          ),
          child: _isClaimingBonus
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(canClaim ? 'AL' : 'ALINDI'),
        ),
      ),
    );
  }

  Widget _buildAdWatchCard() {
    return Card(
      color: Colors.grey[850],
      child: ListTile(
        leading: const Icon(Icons.movie, color: Colors.lightBlue),
        title: const Text(
          'Reklam İzle',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: const Text(
          'Video izleyerek 2 jeton kazan',
          style: TextStyle(color: Colors.white70),
        ),
        trailing: ElevatedButton(
          onPressed: !_isWatchingAd ? _watchAdForTokens : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.lightBlue,
          ),
          child: _isWatchingAd
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('İZLE', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildGameRewardCard() {
    return Card(
      color: Colors.grey[850],
      child: const ListTile(
        leading: Icon(Icons.emoji_events, color: Colors.orange),
        title: Text(
          'Oyunları Kazan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Her galibiyet +1 jeton kazandırır',
          style: TextStyle(color: Colors.white70),
        ),
        trailing: Icon(Icons.info_outline, color: Colors.white54),
      ),
    );
  }

  Widget _buildPackageCard(Map<String, dynamic> package) {
    bool isPopular = package['popular'] ?? false;
    return Card(
      color: isPopular ? Colors.amber[800] : Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isPopular
            ? const BorderSide(color: Colors.amber, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(package['icon'] as IconData, color: Colors.white, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    package['title'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '${package['tokens']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (package['bonus'] > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(
                            '+${package['bonus']} Bonus',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _purchaseTokens(package),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text(package['price'] as String),
            ),
          ],
        ),
      ),
    );
  }
}
