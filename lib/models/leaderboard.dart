class LeaderboardEntry {
  final String playerId;
  final String playerName;
  final int totalScore;
  final int gamesPlayed;
  final int gamesWon;
  final int bestTime;
  final int bestAttempts;
  final int averageAttempts;
  final double winRate;
  final DateTime lastPlayedAt;

  LeaderboardEntry({
    required this.playerId,
    required this.playerName,
    required this.totalScore,
    required this.gamesPlayed,
    required this.gamesWon,
    required this.bestTime,
    required this.bestAttempts,
    required this.averageAttempts,
    required this.winRate,
    required this.lastPlayedAt,
  });

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map) {
    return LeaderboardEntry(
      playerId: map['playerId'] ?? '',
      playerName: map['playerName'] ?? 'Anonim Oyuncu',
      totalScore: map['totalScore'] ?? 0,
      gamesPlayed: map['gamesPlayed'] ?? 0,
      gamesWon: map['gamesWon'] ?? 0,
      bestTime: map['bestTime'] ?? 9999,
      bestAttempts: map['bestAttempts'] ?? 999,
      averageAttempts: map['averageAttempts'] ?? 0,
      winRate: (map['winRate'] ?? 0.0).toDouble(),
      lastPlayedAt: map['lastPlayedAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'playerId': playerId,
      'playerName': playerName,
      'totalScore': totalScore,
      'gamesPlayed': gamesPlayed,
      'gamesWon': gamesWon,
      'bestTime': bestTime,
      'bestAttempts': bestAttempts,
      'averageAttempts': averageAttempts,
      'winRate': winRate,
      'lastPlayedAt': lastPlayedAt,
    };
  }
}

enum LeaderboardType {
  totalScore,
  winRate,
  bestTime,
  bestAttempts,
}

class LeaderboardStats {
  final String playerId;
  final String playerName;
  final String avatar;
  final int totalScore;
  final int gamesPlayed;
  final int gamesWon;
  final int bestTime;
  final int bestAttempts;
  final int totalAttempts;
  final DateTime lastPlayedAt;
  final DateTime createdAt;

  LeaderboardStats({
    required this.playerId,
    required this.playerName,
    required this.avatar,
    required this.totalScore,
    required this.gamesPlayed,
    required this.gamesWon,
    required this.bestTime,
    required this.bestAttempts,
    required this.totalAttempts,
    required this.lastPlayedAt,
    required this.createdAt,
  });

  double get winRate => gamesPlayed > 0 ? (gamesWon / gamesPlayed) * 100 : 0.0;
  double get averageAttempts => gamesPlayed > 0 ? totalAttempts / gamesPlayed : 0.0;

  factory LeaderboardStats.fromFirestore(Map<String, dynamic> data) {
    return LeaderboardStats(
      playerId: data['playerId'] ?? '',
      playerName: data['playerName'] ?? 'Anonim Oyuncu',
      avatar: data['avatar'] ?? '🎮',
      totalScore: data['totalScore'] ?? 0,
      gamesPlayed: data['gamesPlayed'] ?? 0,
      gamesWon: data['gamesWon'] ?? 0,
      bestTime: data['bestTime'] ?? 9999,
      bestAttempts: data['bestAttempts'] ?? 999,
      totalAttempts: data['totalAttempts'] ?? 0,
      lastPlayedAt: data['lastPlayedAt']?.toDate() ?? DateTime.now(),
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'playerId': playerId,
      'playerName': playerName,
      'avatar': avatar,
      'totalScore': totalScore,
      'gamesPlayed': gamesPlayed,
      'gamesWon': gamesWon,
      'bestTime': bestTime,
      'bestAttempts': bestAttempts,
      'totalAttempts': totalAttempts,
      'lastPlayedAt': lastPlayedAt,
      'createdAt': createdAt,
    };
  }
} 