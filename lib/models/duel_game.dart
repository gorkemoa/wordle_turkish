enum GameStatus {
  waiting,
  active,
  finished,
  abandoned,
}

class DuelGame {
  final String gameId;
  final String secretWord;
  final List<DuelPlayer> players;
  final GameStatus status;
  final String? currentTurn;
  final DateTime createdAt;
  final DateTime? finishedAt;
  final String? winnerId;
  final int maxAttempts;

  DuelGame({
    required this.gameId,
    required this.secretWord,
    required this.players,
    required this.status,
    this.currentTurn,
    required this.createdAt,
    this.finishedAt,
    this.winnerId,
    this.maxAttempts = 6,
  });

  factory DuelGame.fromMap(Map<String, dynamic> map) {
    // Players verisi Firebase'de Map veya List formatında gelebilir
    List<DuelPlayer> players = [];
    final playersData = map['players'];
    if (playersData is Map) {
      players = playersData.entries.map((entry) {
        final playerData = entry.value;
        if (playerData is Map) {
          final playerMap = <String, dynamic>{};
          for (final e in playerData.entries) {
            playerMap[e.key.toString()] = e.value;
          }
          return DuelPlayer.fromMap(playerMap);
        }
        return DuelPlayer(
          playerId: entry.key.toString(),
          playerName: 'Oyuncu',
          avatar: '🎮',
          guesses: [],
          joinedAt: DateTime.now(),
        );
      }).toList();
    } else if (playersData is List) {
      players = playersData
          .where((playerData) => playerData != null)
          .map((playerData) {
            if (playerData is Map) {
              return DuelPlayer.fromMap(Map<String, dynamic>.from(playerData));
            }
            return DuelPlayer(
              playerId: '',
              playerName: 'Oyuncu',
              avatar: '🎮',
              guesses: [],
              joinedAt: DateTime.now(),
            );
          })
          .toList();
    }

    return DuelGame(
      gameId: map['gameId'] ?? '',
      secretWord: map['secretWord'] ?? '',
      players: players,
      status: GameStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => GameStatus.waiting,
      ),
      currentTurn: map['currentTurn'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      finishedAt: map['finishedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['finishedAt'])
          : null,
      winnerId: map['winnerId'],
      maxAttempts: map['maxAttempts'] ?? 6,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'gameId': gameId,
      'secretWord': secretWord,
      'players': players.map((p) => p.toMap()).toList(),
      'status': status.name,
      'currentTurn': currentTurn,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'finishedAt': finishedAt?.millisecondsSinceEpoch,
      'winnerId': winnerId,
      'maxAttempts': maxAttempts,
    };
  }
}

class DuelPlayer {
  final String playerId;
  final String playerName;
  final String avatar;
  final List<List<String>> guesses;
  final int currentAttempt;
  final bool isWinner;
  final String currentGuess;
  final DateTime joinedAt;

  DuelPlayer({
    required this.playerId,
    required this.playerName,
    required this.avatar,
    required this.guesses,
    this.currentAttempt = 0,
    this.isWinner = false,
    this.currentGuess = '',
    required this.joinedAt,
  });

  factory DuelPlayer.fromMap(Map<String, dynamic> map) {
    final isWinner = map['isWinner'] ?? false;
    print('🎮 DuelPlayer.fromMap - ${map['playerName']}: isWinner = $isWinner');
    
    return DuelPlayer(
      playerId: map['playerId'] ?? '',
      playerName: map['playerName'] ?? '',
      avatar: map['avatar'] ?? '🎮',
      guesses: (map['guesses'] as List<dynamic>?)
          ?.map((g) => (g as List<dynamic>).cast<String>())
          .toList() ?? [],
      currentAttempt: map['currentAttempt'] ?? 0,
      isWinner: isWinner,
      currentGuess: map['currentGuess'] ?? '',
      joinedAt: DateTime.fromMillisecondsSinceEpoch(map['joinedAt'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'playerId': playerId,
      'playerName': playerName,
      'avatar': avatar,
      'guesses': guesses,
      'currentAttempt': currentAttempt,
      'isWinner': isWinner,
      'currentGuess': currentGuess,
      'joinedAt': joinedAt.millisecondsSinceEpoch,
    };
  }

  DuelPlayer copyWith({
    String? playerId,
    String? playerName,
    String? avatar,
    List<List<String>>? guesses,
    int? currentAttempt,
    bool? isWinner,
    String? currentGuess,
    DateTime? joinedAt,
  }) {
    return DuelPlayer(
      playerId: playerId ?? this.playerId,
      playerName: playerName ?? this.playerName,
      avatar: avatar ?? this.avatar,
      guesses: guesses ?? this.guesses,
      currentAttempt: currentAttempt ?? this.currentAttempt,
      isWinner: isWinner ?? this.isWinner,
      currentGuess: currentGuess ?? this.currentGuess,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
} 