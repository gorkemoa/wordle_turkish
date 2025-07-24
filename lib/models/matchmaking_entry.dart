enum MatchmakingStatus {
  waiting,
  matched,
  expired,
  cancelled,
}

class MatchmakingEntry {
  final String playerId; // userId yerine playerId kullan
  final String playerName;
  final String avatar;
  final DateTime createdAt;
  final MatchmakingStatus status;
  final String? gameId;
  final int skillLevel;

  MatchmakingEntry({
    required this.playerId,
    required this.playerName,
    required this.avatar,
    required this.createdAt,
    required this.status,
    this.gameId,
    this.skillLevel = 1,
  });

  factory MatchmakingEntry.fromMap(Map<String, dynamic> map) {
    return MatchmakingEntry(
      playerId: map['playerId'] ?? map['userId'] ?? '', // Backward compatibility
      playerName: map['playerName'] ?? '',
      avatar: map['avatar'] ?? '🎮',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      status: MatchmakingStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => MatchmakingStatus.waiting,
      ),
      gameId: map['gameId'],
      skillLevel: map['skillLevel'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'playerId': playerId,
      'playerName': playerName,
      'avatar': avatar,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'status': status.name,
      'gameId': gameId,
      'skillLevel': skillLevel,
    };
  }

  bool get isWaiting => status == MatchmakingStatus.waiting;
  bool get isMatched => status == MatchmakingStatus.matched;
  bool get isExpired => status == MatchmakingStatus.expired;
  bool get isCancelled => status == MatchmakingStatus.cancelled;

  bool isCompatibleWith(MatchmakingEntry other) {
    if (playerId == other.playerId) return false;
    return (skillLevel - other.skillLevel).abs() <= 1;
  }

  bool get hasExceededMaxWaitTime {
    return DateTime.now().difference(createdAt).inMinutes > 5;
  }

  MatchmakingEntry copyWith({
    String? playerId,
    String? playerName,
    String? avatar,
    DateTime? createdAt,
    MatchmakingStatus? status,
    String? gameId,
    int? skillLevel,
  }) {
    return MatchmakingEntry(
      playerId: playerId ?? this.playerId,
      playerName: playerName ?? this.playerName,
      avatar: avatar ?? this.avatar,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      gameId: gameId ?? this.gameId,
      skillLevel: skillLevel ?? this.skillLevel,
    );
  }
}

/// Matchmaking sonucu
class MatchmakingResult {
  final bool success;
  final String? gameId;
  final String? errorMessage;
  final MatchmakingEntry? opponentEntry;

  const MatchmakingResult({
    required this.success,
    this.gameId,
    this.errorMessage,
    this.opponentEntry,
  });

  /// Başarılı matchmaking sonucu
  factory MatchmakingResult.success({
    required String gameId,
    required MatchmakingEntry opponentEntry,
  }) {
    return MatchmakingResult(
      success: true,
      gameId: gameId,
      opponentEntry: opponentEntry,
    );
  }

  /// Başarısız matchmaking sonucu
  factory MatchmakingResult.failure(String errorMessage) {
    return MatchmakingResult(
      success: false,
      errorMessage: errorMessage,
    );
  }

  @override
  String toString() {
    if (success) {
      return 'MatchmakingResult.success(gameId: $gameId, opponent: ${opponentEntry?.playerName})';
    } else {
      return 'MatchmakingResult.failure(error: $errorMessage)';
    }
  }
} 