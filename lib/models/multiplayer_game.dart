// lib/models/multiplayer_game.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// 🎯 Multiplayer oyun durumları
enum MultiplayerGameStatus {
  waiting,     // Oyuncular bekleniyor
  active,      // Oyun aktif
  finished,    // Oyun bitti
  abandoned    // Oyun terk edildi
}

/// 👤 Oyuncu durumları
enum PlayerStatus {
  waiting,      // Oyunu bekliyor
  ready,        // Hazır
  playing,      // Oyunu oynuyor
  finished,     // Oyunu bitirdi
  disconnected  // Bağlantı kesildi
}

/// 🎲 Hamle sonuç durumları
enum LetterStatus {
  correct,  // Doğru pozisyon
  present,  // Kelimede var ama yanlış pozisyon
  absent    // Kelimede yok
}

/// 🔄 Oyun olayları
enum GameEventType {
  playerJoined,
  playerLeft,
  gameStarted,
  moveMade,
  gameFinished,
  playerDisconnected
}

/// 📊 Oyun kazanma türleri
enum WinType {
  solved,        // Kelimeyi buldu
  time,          // Zaman avantajı
  opponentQuit   // Rakip oyundan çıktı
}

/// 🎮 Multiplayer oyun eşleşmesi
class MultiplayerMatch {
  final String matchId;
  final String gameMode;
  final String secretWord;
  final int wordLength;
  final MultiplayerGameStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? winner;
  final int maxAttempts;
  final String? currentTurn;
  final DateTime? turnTimeout;
  final Map<String, MultiplayerPlayer> players;

  MultiplayerMatch({
    required this.matchId,
    required this.gameMode,
    required this.secretWord,
    required this.wordLength,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
    this.winner,
    this.maxAttempts = 6,
    this.currentTurn,
    this.turnTimeout,
    required this.players,
  });

  /// Firebase'den MultiplayerMatch oluştur
  factory MultiplayerMatch.fromFirebase(Map<String, dynamic> data) {
    final playersData = data['players'] as Map<String, dynamic>? ?? {};
    final players = <String, MultiplayerPlayer>{};
    
    for (final entry in playersData.entries) {
      players[entry.key] = MultiplayerPlayer.fromFirebase(
        entry.value as Map<String, dynamic>,
      );
    }

    return MultiplayerMatch(
      matchId: data['matchId'] ?? '',
      gameMode: data['gameMode'] ?? 'multiplayer',
      secretWord: data['secretWord'] ?? '',
      wordLength: data['wordLength'] ?? 5,
      status: _parseGameStatus(data['status']),
      createdAt: _parseTimestamp(data['createdAt']),
      startedAt: _parseTimestamp(data['startedAt']),
      finishedAt: _parseTimestamp(data['finishedAt']),
      winner: data['winner'],
      maxAttempts: data['maxAttempts'] ?? 6,
      currentTurn: data['currentTurn'],
      turnTimeout: _parseTimestamp(data['turnTimeout']),
      players: players,
    );
  }

  /// Firebase'e kaydetmek için Map'e dönüştür
  Map<String, dynamic> toFirebase() {
    final playersData = <String, dynamic>{};
    for (final entry in players.entries) {
      playersData[entry.key] = entry.value.toFirebase();
    }

    return {
      'matchId': matchId,
      'gameMode': gameMode,
      'secretWord': secretWord,
      'wordLength': wordLength,
      'status': status.name,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'startedAt': startedAt?.millisecondsSinceEpoch,
      'finishedAt': finishedAt?.millisecondsSinceEpoch,
      'winner': winner,
      'maxAttempts': maxAttempts,
      'currentTurn': currentTurn,
      'turnTimeout': turnTimeout?.millisecondsSinceEpoch,
      'players': playersData,
    };
  }

  /// Oyuncuyu ID'ye göre bul
  MultiplayerPlayer? getPlayer(String playerId) {
    return players[playerId];
  }

  /// Rakip oyuncuyu bul
  MultiplayerPlayer? getOpponent(String playerId) {
    try {
      return players.values
          .firstWhere((player) => player.uid != playerId);
    } catch (e) {
      return null;
    }
  }

  /// Oyun aktif mi?
  bool get isActive => status == MultiplayerGameStatus.active;

  /// Oyun bitmiş mi?
  bool get isFinished => status == MultiplayerGameStatus.finished;

  /// Oyun terk edilmiş mi?
  bool get isAbandoned => status == MultiplayerGameStatus.abandoned;

  /// Kopya oluştur
  MultiplayerMatch copyWith({
    String? matchId,
    String? gameMode,
    String? secretWord,
    int? wordLength,
    MultiplayerGameStatus? status,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? finishedAt,
    String? winner,
    int? maxAttempts,
    String? currentTurn,
    DateTime? turnTimeout,
    Map<String, MultiplayerPlayer>? players,
  }) {
    return MultiplayerMatch(
      matchId: matchId ?? this.matchId,
      gameMode: gameMode ?? this.gameMode,
      secretWord: secretWord ?? this.secretWord,
      wordLength: wordLength ?? this.wordLength,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      winner: winner ?? this.winner,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      currentTurn: currentTurn ?? this.currentTurn,
      turnTimeout: turnTimeout ?? this.turnTimeout,
      players: players ?? this.players,
    );
  }

  /// Oyuncuların durumlarını güncelle
  MultiplayerMatch updatePlayer(String playerId, MultiplayerPlayer updatedPlayer) {
    final newPlayers = Map<String, MultiplayerPlayer>.from(players);
    newPlayers[playerId] = updatedPlayer;
    return copyWith(players: newPlayers);
  }

  /// Oyun başlatılabilir mi?
  bool get canStart {
    return players.length == 2 && 
           players.values.every((player) => player.status == PlayerStatus.ready);
  }

  /// Oyuncu sayısı
  int get playerCount => players.length;

  /// Aktif oyuncuların sayısı
  int get activePlayerCount => players.values
      .where((player) => player.status != PlayerStatus.disconnected)
      .length;

  static MultiplayerGameStatus _parseGameStatus(String? status) {
    switch (status) {
      case 'waiting':
        return MultiplayerGameStatus.waiting;
      case 'active':
        return MultiplayerGameStatus.active;
      case 'finished':
        return MultiplayerGameStatus.finished;
      case 'abandoned':
        return MultiplayerGameStatus.abandoned;
      default:
        return MultiplayerGameStatus.waiting;
    }
  }

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }
    return DateTime.now();
  }
}

/// 👤 Multiplayer oyuncusu
class MultiplayerPlayer {
  final String uid;
  final String displayName;
  final String avatar;
  final PlayerStatus status;
  final DateTime joinedAt;
  final DateTime lastActionAt;
  final int currentAttempt;
  final bool isFinished;
  final DateTime? finishedAt;
  final int attempts;
  final int score;
  final String connectionStatus;

  MultiplayerPlayer({
    required this.uid,
    required this.displayName,
    required this.avatar,
    required this.status,
    required this.joinedAt,
    required this.lastActionAt,
    this.currentAttempt = 0,
    this.isFinished = false,
    this.finishedAt,
    this.attempts = 0,
    this.score = 0,
    this.connectionStatus = 'online',
  });

  /// Firebase'den MultiplayerPlayer oluştur
  factory MultiplayerPlayer.fromFirebase(Map<String, dynamic> data) {
    return MultiplayerPlayer(
      uid: data['uid'] ?? '',
      displayName: data['displayName'] ?? 'Oyuncu',
      avatar: data['avatar'] ?? '🎮',
      status: _parsePlayerStatus(data['status']),
      joinedAt: _parseTimestamp(data['joinedAt']),
      lastActionAt: _parseTimestamp(data['lastActionAt']),
      currentAttempt: data['currentAttempt'] ?? 0,
      isFinished: data['isFinished'] ?? false,
      finishedAt: _parseTimestamp(data['finishedAt']),
      attempts: data['attempts'] ?? 0,
      score: data['score'] ?? 0,
      connectionStatus: data['connectionStatus'] ?? 'online',
    );
  }

  /// Firebase'e kaydetmek için Map'e dönüştür
  Map<String, dynamic> toFirebase() {
    return {
      'uid': uid,
      'displayName': displayName,
      'avatar': avatar,
      'status': status.name,
      'joinedAt': joinedAt.millisecondsSinceEpoch,
      'lastActionAt': lastActionAt.millisecondsSinceEpoch,
      'currentAttempt': currentAttempt,
      'isFinished': isFinished,
      'finishedAt': finishedAt?.millisecondsSinceEpoch,
      'attempts': attempts,
      'score': score,
      'connectionStatus': connectionStatus,
    };
  }

  /// Kopya oluştur
  MultiplayerPlayer copyWith({
    String? uid,
    String? displayName,
    String? avatar,
    PlayerStatus? status,
    DateTime? joinedAt,
    DateTime? lastActionAt,
    int? currentAttempt,
    bool? isFinished,
    DateTime? finishedAt,
    int? attempts,
    int? score,
    String? connectionStatus,
  }) {
    return MultiplayerPlayer(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      avatar: avatar ?? this.avatar,
      status: status ?? this.status,
      joinedAt: joinedAt ?? this.joinedAt,
      lastActionAt: lastActionAt ?? this.lastActionAt,
      currentAttempt: currentAttempt ?? this.currentAttempt,
      isFinished: isFinished ?? this.isFinished,
      finishedAt: finishedAt ?? this.finishedAt,
      attempts: attempts ?? this.attempts,
      score: score ?? this.score,
      connectionStatus: connectionStatus ?? this.connectionStatus,
    );
  }

  /// Oyuncu online mi?
  bool get isOnline => connectionStatus == 'online';

  /// Oyuncu oynuyor mu?
  bool get isPlaying => status == PlayerStatus.playing;

  /// Oyuncu hazır mı?
  bool get isReady => status == PlayerStatus.ready;

  /// Oyuncu bağlantısı kesildi mi?
  bool get isDisconnected => status == PlayerStatus.disconnected;

  static PlayerStatus _parsePlayerStatus(String? status) {
    switch (status) {
      case 'waiting':
        return PlayerStatus.waiting;
      case 'ready':
        return PlayerStatus.ready;
      case 'playing':
        return PlayerStatus.playing;
      case 'finished':
        return PlayerStatus.finished;
      case 'disconnected':
        return PlayerStatus.disconnected;
      default:
        return PlayerStatus.waiting;
    }
  }

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }
    return DateTime.now();
  }
}

/// 🎯 Oyun hamlesi
class GameMove {
  final String moveId;
  final String playerId;
  final int attempt;
  final String guess;
  final List<LetterResult> result;
  final DateTime timestamp;
  final int duration; // milliseconds

  GameMove({
    required this.moveId,
    required this.playerId,
    required this.attempt,
    required this.guess,
    required this.result,
    required this.timestamp,
    required this.duration,
  });

  /// Firebase'den GameMove oluştur
  factory GameMove.fromFirebase(Map<String, dynamic> data) {
    final resultData = data['result'] as List<dynamic>? ?? [];
    final result = resultData
        .map((item) => LetterResult.fromFirebase(item as Map<String, dynamic>))
        .toList();

    return GameMove(
      moveId: data['moveId'] ?? '',
      playerId: data['playerId'] ?? '',
      attempt: data['attempt'] ?? 0,
      guess: data['guess'] ?? '',
      result: result,
      timestamp: _parseTimestamp(data['timestamp']),
      duration: data['duration'] ?? 0,
    );
  }

  /// Firebase'e kaydetmek için Map'e dönüştür
  Map<String, dynamic> toFirebase() {
    return {
      'moveId': moveId,
      'playerId': playerId,
      'attempt': attempt,
      'guess': guess,
      'result': result.map((r) => r.toFirebase()).toList(),
      'timestamp': timestamp.millisecondsSinceEpoch,
      'duration': duration,
    };
  }

  /// Hamle başarılı mı? (tüm harfler doğru)
  bool get isSuccessful => result.every((r) => r.status == LetterStatus.correct);

  /// Doğru harf sayısı
  int get correctCount => result.where((r) => r.status == LetterStatus.correct).length;

  /// Yerinde olmayan harf sayısı
  int get presentCount => result.where((r) => r.status == LetterStatus.present).length;

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }
    return DateTime.now();
  }
}

/// 🔤 Harf sonucu
class LetterResult {
  final String letter;
  final LetterStatus status;
  final int position;

  LetterResult({
    required this.letter,
    required this.status,
    required this.position,
  });

  /// Firebase'den LetterResult oluştur
  factory LetterResult.fromFirebase(Map<String, dynamic> data) {
    return LetterResult(
      letter: data['letter'] ?? '',
      status: _parseLetterStatus(data['status']),
      position: data['position'] ?? 0,
    );
  }

  /// Firebase'e kaydetmek için Map'e dönüştür
  Map<String, dynamic> toFirebase() {
    return {
      'letter': letter,
      'status': status.name,
      'position': position,
    };
  }

  static LetterStatus _parseLetterStatus(String? status) {
    switch (status) {
      case 'correct':
        return LetterStatus.correct;
      case 'present':
        return LetterStatus.present;
      case 'absent':
        return LetterStatus.absent;
      default:
        return LetterStatus.absent;
    }
  }
}

/// 🎪 Oyun olayı
class GameEvent {
  final String eventId;
  final GameEventType type;
  final String playerId;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  GameEvent({
    required this.eventId,
    required this.type,
    required this.playerId,
    required this.timestamp,
    required this.data,
  });

  /// Firebase'den GameEvent oluştur
  factory GameEvent.fromFirebase(Map<String, dynamic> data) {
    return GameEvent(
      eventId: data['eventId'] ?? '',
      type: _parseEventType(data['type']),
      playerId: data['playerId'] ?? '',
      timestamp: _parseTimestamp(data['timestamp']),
      data: data['data'] ?? {},
    );
  }

  /// Firebase'e kaydetmek için Map'e dönüştür
  Map<String, dynamic> toFirebase() {
    return {
      'eventId': eventId,
      'type': type.name,
      'playerId': playerId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'data': data,
    };
  }

  static GameEventType _parseEventType(String? type) {
    switch (type) {
      case 'playerJoined':
        return GameEventType.playerJoined;
      case 'playerLeft':
        return GameEventType.playerLeft;
      case 'gameStarted':
        return GameEventType.gameStarted;
      case 'moveMade':
        return GameEventType.moveMade;
      case 'gameFinished':
        return GameEventType.gameFinished;
      case 'playerDisconnected':
        return GameEventType.playerDisconnected;
      default:
        return GameEventType.playerJoined;
    }
  }

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }
    return DateTime.now();
  }
}

/// 🏆 Oyun sonucu
class GameResult {
  final String? winner;
  final WinType winType;
  final Map<String, int> finalScores;
  final int duration; // seconds
  final int totalMoves;
  final double averageResponseTime;

  GameResult({
    this.winner,
    required this.winType,
    required this.finalScores,
    required this.duration,
    required this.totalMoves,
    required this.averageResponseTime,
  });

  /// Firebase'den GameResult oluştur
  factory GameResult.fromFirebase(Map<String, dynamic> data) {
    final scoresData = data['finalScores'] as Map<String, dynamic>? ?? {};
    final finalScores = <String, int>{};
    for (final entry in scoresData.entries) {
      finalScores[entry.key] = entry.value as int;
    }

    return GameResult(
      winner: data['winner'],
      winType: _parseWinType(data['winType']),
      finalScores: finalScores,
      duration: data['duration'] ?? 0,
      totalMoves: data['totalMoves'] ?? 0,
      averageResponseTime: (data['averageResponseTime'] ?? 0.0).toDouble(),
    );
  }

  /// Firebase'e kaydetmek için Map'e dönüştür
  Map<String, dynamic> toFirebase() {
    return {
      'winner': winner,
      'winType': winType.name,
      'finalScores': finalScores,
      'duration': duration,
      'totalMoves': totalMoves,
      'averageResponseTime': averageResponseTime,
    };
  }

  /// Beraberlik mi?
  bool get isDraw => winner == null;

  /// Kazanan skoru
  int get winnerScore => winner != null ? (finalScores[winner!] ?? 0) : 0;

  static WinType _parseWinType(String? type) {
    switch (type) {
      case 'solved':
        return WinType.solved;
      case 'time':
        return WinType.time;
      case 'opponentQuit':
        return WinType.opponentQuit;
      default:
        return WinType.solved;
    }
  }
}

/// 🎮 Bekleme odası kullanıcısı
class WaitingRoomUser {
  final String uid;
  final String displayName;
  final String avatar;
  final DateTime joinedAt;
  final DateTime lastSeen;
  final String gameMode;
  final int preferredWordLength;
  final int level;
  final String status;

  WaitingRoomUser({
    required this.uid,
    required this.displayName,
    required this.avatar,
    required this.joinedAt,
    required this.lastSeen,
    required this.gameMode,
    required this.preferredWordLength,
    required this.level,
    required this.status,
  });

  /// Firebase'den WaitingRoomUser oluştur
  factory WaitingRoomUser.fromFirebase(Map<String, dynamic> data) {
    return WaitingRoomUser(
      uid: data['uid'] ?? '',
      displayName: data['displayName'] ?? 'Oyuncu',
      avatar: data['avatar'] ?? '🎮',
      joinedAt: _parseTimestamp(data['joinedAt']),
      lastSeen: _parseTimestamp(data['lastSeen']),
      gameMode: data['gameMode'] ?? 'multiplayer',
      preferredWordLength: data['preferredWordLength'] ?? 5,
      level: data['level'] ?? 1,
      status: data['status'] ?? 'waiting',
    );
  }

  /// Firebase'e kaydetmek için Map'e dönüştür
  Map<String, dynamic> toFirebase() {
    return {
      'uid': uid,
      'displayName': displayName,
      'avatar': avatar,
      'joinedAt': joinedAt.millisecondsSinceEpoch,
      'lastSeen': lastSeen.millisecondsSinceEpoch,
      'gameMode': gameMode,
      'preferredWordLength': preferredWordLength,
      'level': level,
      'status': status,
    };
  }

  /// Kullanıcı aktif mi?
  bool get isActive => status == 'waiting' || status == 'searching';

  /// Kullanıcı eşleşmiş mi?
  bool get isMatched => status == 'matched';

  /// Kullanıcının bekleme süresi
  Duration get waitingTime => DateTime.now().difference(joinedAt);

  /// Kopya oluştur
  WaitingRoomUser copyWith({
    String? uid,
    String? displayName,
    String? avatar,
    DateTime? joinedAt,
    DateTime? lastSeen,
    String? gameMode,
    int? preferredWordLength,
    int? level,
    String? status,
  }) {
    return WaitingRoomUser(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      avatar: avatar ?? this.avatar,
      joinedAt: joinedAt ?? this.joinedAt,
      lastSeen: lastSeen ?? this.lastSeen,
      gameMode: gameMode ?? this.gameMode,
      preferredWordLength: preferredWordLength ?? this.preferredWordLength,
      level: level ?? this.level,
      status: status ?? this.status,
    );
  }

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }
    return DateTime.now();
  }
} 