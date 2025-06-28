import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../services/ad_service.dart';

// Jeton dükkânı sayfası

class TokenShopPage extends StatefulWidget {
  const TokenShopPage({Key? key}) : super(key: key);

  @override
  State<TokenShopPage> createState() => _TokenShopPageState();
}

class _TokenShopPageState extends State<TokenShopPage> {
  int _userTokens = 0;
  bool _isLoading = true;
  bool _isWatchingAd = false;
  bool _canEarnDailyBonus = false;
  bool _isClaimingBonus = false;

  @override
  void initState() {
    super.initState();
    _loadUserTokens();
  }

  Future<void> _loadUserTokens() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final tokens = await FirebaseService.getUserTokens(user.uid);
      final canEarnBonus = await FirebaseService.canEarnDailyBonus(user.uid);
      setState(() {
        _userTokens = tokens;
        _canEarnDailyBonus = canEarnBonus;
        _isLoading = false;
      });
    }
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
        _showSnackBar('Reklam şu anda mevcut değil. Lütfen daha sonra tekrar deneyin.', Colors.orange);
        return;
      }

      bool success = await AdService.showRewardedAd(user.uid);
      if (success) {
        _showSnackBar('🎉 1 jeton kazandınız!', Colors.green);
        await _loadUserTokens(); // Jeton sayısını yenile
      } else {
        _showSnackBar('Reklam izlenemedi. Lütfen tekrar deneyin.', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Bir hata oluştu: $e', Colors.red);
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
        _showSnackBar('🎉 Günlük bonus kazandınız!', Colors.green);
        await _loadUserTokens(); // Jeton sayısını yenile
      } else {
        _showSnackBar('Günlük bonus zaten alınmış.', Colors.orange);
      }
    } catch (e) {
      _showSnackBar('Bir hata oluştu: $e', Colors.red);
    } finally {
      setState(() {
        _isClaimingBonus = false;
      });
    }
  }

  Future<void> _addTestTokens() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 10 test jetonu ekle
      await FirebaseService.earnTokens(user.uid, 10, 'Test Jetonu');
      _showSnackBar('🧪 10 test jetonu eklendi!', Colors.pink);
      await _loadUserTokens(); // Jeton sayısını yenile
    } catch (e) {
      _showSnackBar('Bir hata oluştu: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          'Jeton Dükkânı',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.amber),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Jeton bakiyesi
                  _buildTokenBalance(),
                  const SizedBox(height: 24),
                  
                  // Jeton kazanma yolları
                  const Text(
                    'Jeton Kazan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Günlük bonus kartı
                  _buildDailyBonusCard(),
                  const SizedBox(height: 16),
                  
                  // Reklam izle kartı
                  _buildAdWatchCard(),
                  const SizedBox(height: 16),
                  
                  // Test butonu - geliştirme için
                  _buildTestTokenCard(),
                  const SizedBox(height: 16),
                  
                  // Oyun kazanma kartı
                  _buildGameWinCard(),
                  const SizedBox(height: 24),
                  
                  // Jeton kullanım alanları
                  const Text(
                    'Jeton Kullanım Alanları',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // İpucu kartı
                  _buildHintCard(),
                  const SizedBox(height: 24),
                  
                  // Jeton geçmişi
                  const Text(
                    'Son İşlemler',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildTokenHistory(),
                ],
              ),
            ),
    );
  }

  Widget _buildTokenBalance() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.account_balance_wallet,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            'Mevcut Jetonlar',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.monetization_on,
                color: Colors.amber,
                size: 32,
              ),
              const SizedBox(width: 8),
              Text(
                '$_userTokens',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyBonusCard() {
    return Card(
      color: const Color(0xFF2A2A2A),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.card_giftcard,
                color: Colors.purple,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Günlük Bonus',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _canEarnDailyBonus 
                        ? 'Günlük ücretsiz jeton al' 
                        : 'Yarın tekrar gel',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      const Text(
                        '+1',
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
              onPressed: _canEarnDailyBonus && !_isClaimingBonus ? _claimDailyBonus : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _canEarnDailyBonus ? Colors.purple : Colors.grey,
                foregroundColor: Colors.white,
              ),
              child: _isClaimingBonus
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(_canEarnDailyBonus ? 'Al' : 'Alındı'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdWatchCard() {
    return Card(
      color: const Color(0xFF2A2A2A),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.play_circle_fill,
                color: Colors.green,
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
                    '30 saniyelik reklam izleyerek 1 jeton kazan',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      const Text(
                        '+1',
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
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: _isWatchingAd
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('İzle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestTokenCard() {
    return Card(
      color: const Color(0xFF2A2A2A),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.pink.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.bug_report,
                color: Colors.pink,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Test Jetonu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Geliştirme için 10 jeton ekle (sadece test)',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      const Text(
                        '+10',
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
              onPressed: _addTestTokens,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                foregroundColor: Colors.white,
              ),
              child: const Text('Test Al'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameWinCard() {
    return Card(
      color: const Color(0xFF2A2A2A),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.emoji_events,
                color: Colors.blue,
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
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      const Text(
                        '+1',
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
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHintCard() {
    return Card(
      color: const Color(0xFF2A2A2A),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.lightbulb,
                color: Colors.orange,
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
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.red, size: 16),
                      const SizedBox(width: 4),
                      const Text(
                        '-1',
                        style: TextStyle(
                          color: Colors.red,
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
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenHistory() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Card(
        color: Color(0xFF2A2A2A),
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Giriş yapmanız gerekiyor',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('token_transactions')
          .where('uid', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            color: Color(0xFF2A2A2A),
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(color: Colors.amber),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Card(
            color: Color(0xFF2A2A2A),
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Henüz işlem geçmişi yok',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return Card(
          color: const Color(0xFF2A2A2A),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final amount = data['amount'] ?? 0;
                final reason = data['reason'] ?? 'Bilinmeyen';
                final timestamp = data['timestamp'] as Timestamp?;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Icon(
                        amount > 0 ? Icons.add_circle : Icons.remove_circle,
                        color: amount > 0 ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          reason,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      Text(
                        '${amount > 0 ? '+' : ''}$amount',
                        style: TextStyle(
                          color: amount > 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (timestamp != null)
                        Text(
                          _formatDate(timestamp.toDate()),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays > 0) {
      return '${diff.inDays}g önce';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}s önce';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}dk önce';
    } else {
      return 'Az önce';
    }
  }
} 