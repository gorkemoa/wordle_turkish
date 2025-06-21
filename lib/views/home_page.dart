// lib/views/home_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import 'wordle_page.dart';
import 'duel_page.dart';

class HomePage extends StatefulWidget {
  final VoidCallback? toggleTheme;

  const HomePage({Key? key, this.toggleTheme}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Dinamik veriler
  Map<String, dynamic>? userStats;
  Map<String, dynamic>? dailyTasks;
  List<Map<String, dynamic>> recentGames = [];
  List<Map<String, dynamic>> friendActivities = [];
  int unreadNotificationCount = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      // Mevcut kullanıcı için verileri başlat
      await FirebaseService.initializeUserDataIfNeeded(user.uid);

      // Paralel olarak tüm verileri çek
      final results = await Future.wait([
        FirebaseService.getUserStats(user.uid),
        FirebaseService.getDailyTasks(user.uid),
        FirebaseService.getRecentGames(user.uid, limit: 5),
        FirebaseService.getFriendActivities(user.uid, limit: 3),
        FirebaseService.getUnreadNotificationCount(user.uid),
      ]);

      if (mounted) {
        setState(() {
          userStats = results[0] as Map<String, dynamic>?;
          dailyTasks = results[1] as Map<String, dynamic>?;
          recentGames = results[2] as List<Map<String, dynamic>>;
          friendActivities = results[3] as List<Map<String, dynamic>>;
          unreadNotificationCount = results[4] as int;
          isLoading = false;
        });
      }

      // Artık sahte veri oluşturmuyoruz - sadece gerçek veriler gösterilecek
    } catch (e) {
      print('Veri yükleme hatası: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }



  void _showFeatureComingSoon(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.info_outline, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          content: const Text(
            'Bu özellik henüz hazır değil.\nYakında sizlerle buluşacak! 🚀',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF666666),
              height: 1.5,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4285F4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Anladım',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showUserProfile(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Profil Bilgileri',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFF4285F4),
                backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                child: user.photoURL == null
                    ? const Icon(Icons.person, size: 40, color: Colors.white)
                    : null,
              ),
              const SizedBox(height: 24),
              
              _buildProfileInfo('İsim', user.displayName ?? 'Belirtilmemiş'),
              const SizedBox(height: 16),
              _buildProfileInfo('E-posta', user.email ?? 'Belirtilmemiş'),
              const SizedBox(height: 16),
              _buildProfileInfo('Hesap Türü', user.isAnonymous ? 'Misafir' : 'Kayıtlı'),
              if (userStats != null) ...[
                const SizedBox(height: 16),
                _buildProfileInfo('Seviye', userStats!['level'].toString()),
                const SizedBox(height: 16),
                _buildProfileInfo('Toplam Oyun', userStats!['gamesPlayed'].toString()),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Kapat',
                style: TextStyle(
                  color: Color(0xFF666666),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _signOut(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53E3E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Çıkış Yap',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileInfo(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF666666),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Color(0xFF333333),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _signOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Çıkış Yap',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          content: const Text(
            'Çıkış yapmak istediğinizden emin misiniz?\n\nOyun ilerlemeniz kaydedilecektir.',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF666666),
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'İptal',
                style: TextStyle(
                  color: Color(0xFF666666),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await FirebaseService.signOut();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53E3E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Çıkış Yap',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToWordle(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WordlePage(toggleTheme: widget.toggleTheme ?? () {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF4285F4),
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Kelime Bul',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF4285F4),
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Bildirim butonu
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: () => _showFeatureComingSoon(context, 'Bildirimler'),
              icon: Stack(
                children: [
                  const Icon(Icons.notifications_outlined, color: Color(0xFF666666), size: 28),
                  if (unreadNotificationCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE53E3E),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Profil butonu
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => _showUserProfile(context),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF4285F4),
                backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                child: user?.photoURL == null
                    ? const Icon(Icons.person, color: Colors.white, size: 20)
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFF4285F4),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hoş geldin bölümü
              _buildWelcomeSection(user),
              
              const SizedBox(height: 24),
              
              // İstatistikler
              _buildStatsSection(),
              
              const SizedBox(height: 32),
              
              // Oyun Modları
              _buildGameModesSection(context),
              
              const SizedBox(height: 32),
              
              // Günlük Görevler
              _buildDailyTasksSection(),
              
              const SizedBox(height: 32),
              
              // Son Oyunlar
              _buildRecentGamesSection(),
              
              const SizedBox(height: 32),
              
              // Arkadaş Aktiviteleri
              _buildFriendActivitiesSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(User? user) {
    final streakDays = userStats?['streak'] ?? 1;
    
    return Row(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: const Color(0xFF4285F4),
          backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
          child: user?.photoURL == null
              ? const Icon(Icons.person, color: Colors.white, size: 25)
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Merhaba, ${user?.displayName ?? 'Oyuncu'}!',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.local_fire_department, color: Color(0xFFFF9500), size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$streakDays günlük seri',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    final level = userStats?['level'] ?? 1;
    final tokens = userStats?['tokens'] ?? 100;
    final points = userStats?['points'] ?? 150;
    
    return Row(
      children: [
        Expanded(
          child: _buildStatCard('🏆', 'Seviye', level.toString()),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard('🪙', 'Jeton', tokens.toString()),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard('⭐', 'Puan', points.toString()),
        ),
      ],
    );
  }

  Widget _buildStatCard(String emoji, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF666666),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameModesSection(BuildContext context) {
    final gamesPlayed = userStats?['gamesPlayed'] ?? 0;
    final gamesWon = userStats?['gamesWon'] ?? 0;
    final winRate = gamesPlayed > 0 ? (gamesWon / gamesPlayed * 100).toInt() : 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Oyun Modları',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
          children: [
            _buildGameModeCard(
              'Duello Modu',
              'Online rekabet! Kazanma oranın: %$winRate',
              const Color(0xFF4285F4),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DuelPage()),
              ),
            ),
            _buildGameModeCard(
              'Zamana Karşı Yarış',
              'Hızını test et! En iyi skoru yakalamaya çalış.',
              const Color(0xFFFF9500),
              () => _showFeatureComingSoon(context, 'Zamana Karşı Yarış'),
            ),
            _buildGameModeCard(
              'Tema Modu',
              'Belirli konularda kelime bul. Bilgini göster!',
              const Color(0xFF9C27B0),
              () => _showFeatureComingSoon(context, 'Tema Modu'),
            ),
            _buildGameModeCard(
              'Günlük Mücadele',
              'Her gün yeni kelime! Serini ${ userStats?['streak'] ?? 1} günde tut.',
              const Color(0xFF34A853),
              () => _navigateToWordle(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGameModeCard(
    String title,
    String description,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Dairesel ikon container
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color,
                    color.withOpacity(0.8),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(
                Icons.psychology,
                color: Colors.white,
                size: 40,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Başlık
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 8),
            
            // Açıklama
            Expanded(
              child: Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF666666),
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTasksSection() {
    if (dailyTasks == null || dailyTasks!['tasks'] == null) {
      return const SizedBox.shrink();
    }

    final tasks = List<Map<String, dynamic>>.from(dailyTasks!['tasks']);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Günlük Görevler',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 16),
        ...tasks.map((task) => Column(
          children: [
            _buildTaskCard(
              task['title'] ?? '',
              task['reward'] ?? '',
              task['current'] ?? 0,
              task['target'] ?? 1,
              _getTaskColor(task['rewardType'] ?? 'points'),
            ),
            const SizedBox(height: 12),
          ],
        )),
      ],
    );
  }

  Color _getTaskColor(String rewardType) {
    switch (rewardType) {
      case 'points':
        return const Color(0xFF4285F4);
      case 'tokens':
        return const Color(0xFF34A853);
      default:
        return const Color(0xFF9C27B0);
    }
  }

  Widget _buildTaskCard(String title, String reward, int current, int target, Color color) {
    double progress = current / target;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
              Text(
                reward,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9ECEF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$current/$target',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF666666),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentGamesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Son Oyunlar',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 16),
        if (recentGames.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'Henüz oyun oynamadınız.\nİlk oyununuzu oynamak için yukarıdaki oyun modlarından birini seçin! 🎮',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                  height: 1.5,
                ),
              ),
            ),
          )
        else
          ...recentGames.map((game) => Column(
            children: [
              _buildRecentGameCard(game),
              const SizedBox(height: 12),
            ],
          )),
      ],
    );
  }

  Widget _buildRecentGameCard(Map<String, dynamic> game) {
    final gameType = game['gameType'] ?? 'Bilinmeyen';
    final score = game['score']?.toString() ?? '0';
    final isWon = game['isWon'] ?? false;
    final duration = game['duration']?.toString() ?? '0:00';
    final finishedAt = game['finishedAt'];
    
    String dateStr = 'Bugün';
    if (finishedAt != null && finishedAt is DateTime) {
      final now = DateTime.now();
      final difference = now.difference(finishedAt).inDays;
      if (difference == 1) {
        dateStr = 'Dün';
      } else if (difference > 1) {
        dateStr = '${finishedAt.day} ${_getMonthName(finishedAt.month)}';
      }
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gameType,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (isWon)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF34A853).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Kazandın',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF34A853),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      const Icon(Icons.star, color: Color(0xFFFF9500), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '$score puan',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF333333),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.access_time,
                      color: Color(0xFF4285F4),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      duration,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            dateStr,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      '', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'
    ];
    return months[month];
  }

  Widget _buildFriendActivitiesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Arkadaş Aktiviteleri',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 16),
        if (friendActivities.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'Henüz arkadaş aktivitesi yok.\nArkadaşlarınızla oyun oynayın ve rekabet edin! 👥',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                  height: 1.5,
                ),
              ),
            ),
          )
        else
          ...friendActivities.map((activity) => Column(
            children: [
              _buildFriendActivityCard(context, activity),
              const SizedBox(height: 12),
            ],
          )),
      ],
    );
  }

  Widget _buildFriendActivityCard(BuildContext context, Map<String, dynamic> activity) {
    final fromUserName = activity['data']?['fromUserName'] ?? 'Bilinmeyen';
    final activityType = activity['activityType'] ?? '';
    final activityData = activity['data'] ?? {};
    
    String activityText = '';
    String actionText = '';
    Color actionColor = const Color(0xFF4285F4);
    
    switch (activityType) {
      case 'new_record':
        final score = activityData['score'] ?? 0;
        activityText = 'Yeni rekor: $score puan';
        actionText = 'Tebrik Et';
        actionColor = const Color(0xFF4285F4);
        break;
      case 'duel_invitation':
        activityText = 'Seni duelloya davet etti';
        actionText = 'Kabul Et';
        actionColor = const Color(0xFF34A853);
        break;
      case 'challenge_completed':
        final challengeName = activityData['challengeName'] ?? 'görevi';
        activityText = '$challengeName tamamladı';
        actionText = 'Tebrik Et';
        actionColor = const Color(0xFF9C27B0);
        break;
      default:
        activityText = 'Bir aktivite gerçekleştirdi';
        actionText = 'Görüntüle';
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF4285F4),
            child: Text(
              fromUserName.isNotEmpty ? fromUserName[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fromUserName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activityText,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _showFeatureComingSoon(context, actionText),
            style: ElevatedButton.styleFrom(
              backgroundColor: actionColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              actionText,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}