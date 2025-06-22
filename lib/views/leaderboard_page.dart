import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/leaderboard_viewmodel.dart';
import '../models/leaderboard.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({Key? key}) : super(key: key);

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeaderboardViewModel>().loadLeaderboard();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Başarı Tablosu',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF4285F4),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Toplam Puan'),
            Tab(text: 'Kazanma Oranı'),
            Tab(text: 'En İyi Süre'),
            Tab(text: 'En Az Deneme'),
          ],
          onTap: (index) {
            final leaderboardType = LeaderboardType.values[index];
            context.read<LeaderboardViewModel>().loadLeaderboard(type: leaderboardType);
          },
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF4285F4),
              Color(0xFFF8F9FA),
            ],
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: const [
            LeaderboardTab(),
            LeaderboardTab(),
            LeaderboardTab(),
            LeaderboardTab(),
          ],
        ),
      ),
    );
  }
}

class LeaderboardTab extends StatelessWidget {
  const LeaderboardTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<LeaderboardViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.isLoading) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF4285F4),
            ),
          );
        }

        if (viewModel.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFF666666),
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  viewModel.error!,
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => viewModel.loadLeaderboard(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4285F4),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => viewModel.loadLeaderboard(),
          child: CustomScrollView(
            slivers: [
              // Kullanıcının kendi durumu
              if (viewModel.currentUserStats != null) ...[
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    child: _buildCurrentUserCard(context, viewModel),
                  ),
                ),
              ],
              
              // Başarı tablosu
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index >= viewModel.leaderboard.length) return null;
                    
                    final stats = viewModel.leaderboard[index];
                    final rank = index + 1;
                    
                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: _buildLeaderboardItem(
                        context,
                        stats,
                        rank,
                        viewModel.currentType,
                        viewModel,
                      ),
                    );
                  },
                  childCount: viewModel.leaderboard.length,
                ),
              ),
              
              // Alt boşluk
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrentUserCard(BuildContext context, LeaderboardViewModel viewModel) {
    final stats = viewModel.currentUserStats!;
    final rank = viewModel.getCurrentUserRank();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF4285F4),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.person,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Senin Durumun',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stats.playerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rank > 0 ? '#$rank sırada' : 'Sıralama dışı',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getValueText(stats, viewModel.currentType, viewModel),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardItem(
    BuildContext context,
    LeaderboardStats stats,
    int rank,
    LeaderboardType type,
    LeaderboardViewModel viewModel,
  ) {
    Color? rankColor;
    IconData? rankIcon;
    
         if (rank == 1) {
       rankColor = const Color(0xFFFFD700).withOpacity(0.2);
       rankIcon = Icons.emoji_events;
    } else if (rank == 2) {
      rankColor = Colors.grey.withOpacity(0.2);
      rankIcon = Icons.military_tech;
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32).withOpacity(0.2);
      rankIcon = Icons.workspace_premium;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: rankColor != null ? Border.all(color: rankColor, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Sıralama
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: rank <= 3 ? const Color(0xFF4285F4) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: rankIcon != null
                  ? Icon(
                      rankIcon,
                      color: Colors.white,
                      size: 20,
                    )
                  : Text(
                      rank.toString(),
                      style: TextStyle(
                        color: rank <= 3 ? Colors.white : Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Oyuncu bilgileri
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stats.playerName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${stats.gamesPlayed} oyun • ${stats.gamesWon} galibiyet',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
          
          // Değer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF4285F4).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getValueText(stats, type, viewModel),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4285F4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getValueText(LeaderboardStats stats, LeaderboardType type, LeaderboardViewModel viewModel) {
    switch (type) {
      case LeaderboardType.totalScore:
        return stats.totalScore.toString();
      case LeaderboardType.winRate:
        return viewModel.formatWinRate(stats.winRate);
      case LeaderboardType.bestTime:
        return stats.bestTime < 9999 ? viewModel.formatTime(stats.bestTime) : '--';
      case LeaderboardType.bestAttempts:
        return stats.bestAttempts < 999 ? stats.bestAttempts.toString() : '--';
    }
  }
}