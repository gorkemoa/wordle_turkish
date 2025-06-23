import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

enum GameStatus { waiting, active, finished }
enum PlayerStatus { waiting, ready, playing, won, lost, disconnected }

class DuelGame {
  final String gameId;
  final String secretWord;
  final GameStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? winnerId;
  final Map<String, DuelPlayer> players;

  DuelGame({
    required this.gameId,
    required this.secretWord,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
    this.winnerId,
    required this.players,
  });

  factory DuelGame.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    Map<String, DuelPlayer> players = {};
    if (data['players'] != null) {
      (data['players'] as Map<String, dynamic>).forEach((key, value) {
        players[key] = DuelPlayer.fromMap(value);
      });
    }

    return DuelGame(
      gameId: doc.id,
      secretWord: data['secretWord'] ?? '',
      status: GameStatus.values.byName(data['status'] ?? 'waiting'),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      startedAt: data['startedAt'] != null ? (data['startedAt'] as Timestamp).toDate() : null,
      finishedAt: data['finishedAt'] != null ? (data['finishedAt'] as Timestamp).toDate() : null,
      winnerId: data['winnerId'],
      players: players,
    );
  }

  factory DuelGame.fromRealtimeDatabase(Map<dynamic, dynamic> data) {
    Map<String, DuelPlayer> players = {};
    if (data['players'] != null) {
      (data['players'] as Map<dynamic, dynamic>).forEach((key, value) {
        players[key.toString()] = DuelPlayer.fromRealtimeMap(value);
      });
    }

    return DuelGame(
      gameId: data['gameId'] ?? '',
      secretWord: data['secretWord'] ?? '',
      status: GameStatus.values.byName(data['status'] ?? 'waiting'),
      createdAt: data['createdAt'] != null 
        ? DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int)
        : DateTime.now(),
      startedAt: data['startedAt'] != null 
        ? DateTime.fromMillisecondsSinceEpoch(data['startedAt'] as int)
        : null,
      finishedAt: data['finishedAt'] != null 
        ? DateTime.fromMillisecondsSinceEpoch(data['finishedAt'] as int)
        : null,
      winnerId: data['winnerId'],
      players: players,
    );
  }

  Map<String, dynamic> toFirestore() {
    Map<String, dynamic> playersMap = {};
    players.forEach((key, value) {
      playersMap[key] = value.toMap();
    });

    return {
      'secretWord': secretWord,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'finishedAt': finishedAt != null ? Timestamp.fromDate(finishedAt!) : null,
      'winnerId': winnerId,
      'players': playersMap,
    };
  }
}

class DuelPlayer {
  final String playerId;
  final String playerName;
  final PlayerStatus status;
  final List<List<String>> guesses;
  final List<List<String>> guessColors; // 'green', 'orange', 'grey'
  final int currentAttempt;
  final DateTime? finishedAt;
  final int score; // Doğru tahmin + kalan süre bonusu
  final String? avatar; // Avatar bilgisi

  DuelPlayer({
    required this.playerId,
    required this.playerName,
    required this.status,
    required this.guesses,
    required this.guessColors,
    required this.currentAttempt,
    this.finishedAt,
    required this.score,
    this.avatar,
  });

  factory DuelPlayer.fromMap(Map<String, dynamic> data) {
    // guesses ve guessColors'ı JSON string'den veya doğrudan listeden parse et
    List<List<String>> parseList(dynamic fieldData) {
      if (fieldData is String) {
        final decoded = jsonDecode(fieldData);
        return List<List<String>>.from(decoded.map((x) => List<String>.from(x.map((e) => e.toString()))));
      }
      if (fieldData is List) {
        return List<List<String>>.from(fieldData.map((x) => List<String>.from(x.map((e) => e.toString()))));
      }
      return [];
    }

    final guessesList = parseList(data['guesses']);
    final guessColorsList = parseList(data['guessColors']);

    return DuelPlayer(
      playerId: data['playerId'] ?? '',
      playerName: data['playerName'] ?? '',
      status: PlayerStatus.values.byName(data['status'] ?? 'waiting'),
      guesses: guessesList.isNotEmpty ? guessesList : List.generate(6, (_) => List.filled(5, '_')),
      guessColors: guessColorsList.isNotEmpty ? guessColorsList : List.generate(6, (_) => List.filled(5, 'empty')),
      currentAttempt: data['currentAttempt'] ?? 0,
      finishedAt: data['finishedAt'] != null ? (data['finishedAt'] as Timestamp).toDate() : null,
      score: data['score'] ?? 0,
      avatar: data['avatar'],
    );
  }

  factory DuelPlayer.fromRealtimeMap(Map<dynamic, dynamic> data) {
    // Realtime Database'den gelen veriyi parse et
    List<List<String>> parseList(dynamic fieldData) {
      if (fieldData is List) {
        return List<List<String>>.from(fieldData.map((x) => List<String>.from(x.map((e) => e.toString()))));
      }
      return [];
    }

    final guessesList = parseList(data['guesses']);
    final guessColorsList = parseList(data['guessColors']);

    return DuelPlayer(
      playerId: data['playerId']?.toString() ?? '',
      playerName: data['playerName']?.toString() ?? '',
      status: PlayerStatus.values.byName(data['status']?.toString() ?? 'waiting'),
      guesses: guessesList.isNotEmpty ? guessesList : List.generate(6, (_) => List.filled(5, '_')),
      guessColors: guessColorsList.isNotEmpty ? guessColorsList : List.generate(6, (_) => List.filled(5, 'empty')),
      currentAttempt: data['currentAttempt'] ?? 0,
      finishedAt: data['finishedAt'] != null 
        ? DateTime.fromMillisecondsSinceEpoch(data['finishedAt'] as int)
        : null,
      score: data['score'] ?? 0,
      avatar: data['avatar']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'playerId': playerId,
      'playerName': playerName,
      'status': status.name,
      'guesses': jsonEncode(guesses), // JSON string olarak serialize et
      'guessColors': jsonEncode(guessColors), // JSON string olarak serialize et
      'currentAttempt': currentAttempt,
      'finishedAt': finishedAt != null ? Timestamp.fromDate(finishedAt!) : null,
      'score': score,
      'avatar': avatar,
    };
  }
} 