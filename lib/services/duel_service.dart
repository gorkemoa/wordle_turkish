import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/duel_game.dart';
import '../models/matchmaking_entry.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/turkish_case_extension.dart';

class DuelService {
  static final DatabaseReference _database = FirebaseDatabase.instance.ref();
  static final Random _random = Random();

  // Reference paths
  static const String _matchmakingPath = 'matchmaking_queue';
  static const String _duelGamesPath = 'duel_games';
  static const String _activeUsersPath = 'active_duel_users';

  // Geçerli kelimeler cache
  static Set<String> _validWords = {};

  // Background matchmaking timer
  static Timer? _matchmakingTimer;
  static bool _isMatchmakingActive = false;

  // Connection status
  static StreamSubscription? _connectionSubscription;
  static bool _isConnected = true;

  /// Servisi başlat
  static Future<void> initialize() async {
    try {
      await _loadWordList();
      _startConnectionMonitoring();
      _startBackgroundMatchmaking();
      print('✅ DuelService başlatıldı');
    } catch (e) {
      print('❌ DuelService başlatma hatası: $e');
      throw Exception('DuelService başlatılamadı: $e');
    }
  }

  /// Servisi temizle
  static void dispose() {
    _matchmakingTimer?.cancel();
    _connectionSubscription?.cancel();
    _isMatchmakingActive = false;
  }

  /// Kelime listesini yükle
  static Future<void> _loadWordList() async {
    try {
      final String data = await rootBundle.loadString('assets/kelimeler.json');
      final List<dynamic> words = json.decode(data);

      // Sadece 5 harfli kelimeleri filtrele ve yükle
      _validWords = words
          .map((word) => word.toString().toUpperCase())
          .where((word) => word.length == 5)
          .toSet();

      print('✅ ${_validWords.length} adet 5 harfli kelime yüklendi');

      if (_validWords.isEmpty) {
        throw Exception('Hiç 5 harfli kelime bulunamadı');
      }
    } catch (e) {
      print('❌ Kelime listesi yükleme hatası: $e');
      throw Exception('Kelime listesi yüklenemedi: $e');
    }
  }

  /// Bağlantı durumunu izle
  static void _startConnectionMonitoring() {
    _connectionSubscription =
        _database.child('.info/connected').onValue.listen((event) {
      final isConnected = event.snapshot.value == true;
      if (isConnected != _isConnected) {
        _isConnected = isConnected;
        if (isConnected) {
          _startBackgroundMatchmaking();
        } else {
          _stopBackgroundMatchmaking();
        }
      }
    });
  }

  /// Background matchmaking başlat
  static void _startBackgroundMatchmaking() {
    if (_isMatchmakingActive) return;

    _isMatchmakingActive = true;
    _matchmakingTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _processMatchmaking(),
    );
    print('🤖 Background matchmaking başlatıldı');
  }

  /// Background matchmaking durdur
  static void _stopBackgroundMatchmaking() {
    _matchmakingTimer?.cancel();
    _isMatchmakingActive = false;
    print('🛑 Background matchmaking durduruldu');
  }

  /// Bağlantı durumunu kontrol et
  static Future<bool> checkConnection() async {
    try {
      final result = await _database.child('test').get();
      return result.exists;
    } catch (e) {
      print('❌ Bağlantı kontrolü hatası: $e');
      return false;
    }
  }

  /// Joker kullan
  static Future<void> useJoker(String gameId, String jokerType) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('Kullanıcı girişi bulunamadı');

      await _database.child('$_duelGamesPath/$gameId/jokers/$userId').set({
        'type': jokerType,
        'usedAt': DateTime.now().millisecondsSinceEpoch,
      });

      print('✅ Joker kullanıldı: $jokerType');
    } catch (e) {
      print('❌ Joker kullanma hatası: $e');
      throw e;
    }
  }

  /// Kullanıcının jetonunu azalt
  static Future<bool> decrementTokens(int amount) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return false;
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (!doc.exists) return false;
      final data = doc.data()!;
      int tokens = data['tokens'] ?? 0;
      if (tokens < amount) return false;
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'tokens': FieldValue.increment(-amount),
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('❌ Jeton azaltma hatası: $e');
      return false;
    }
  }

  /// Kullanıcının güncel jeton bakiyesini oku
  static Future<int> getTokens() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return 0;
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (!doc.exists) return 0;
      final data = doc.data()!;
      return data['tokens'] ?? 0;
    } catch (e) {
      print('❌ Jeton okuma hatası: $e');
      return 0;
    }
  }

  /// Oyunu terk et (Ana metod)
  static Future<void> leaveGame(String gameId, String playerId) async {
    try {
      // Oyun durumunu güncelle
      await _database.child('$_duelGamesPath/$gameId').update({
        'status': 'abandoned',
        'abandonedBy': playerId,
        'abandonedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Matchmaking kuyruğundan çıkar ve aktif kullanıcı listesinden kaldır
      await leaveMatchmakingQueue(playerId);
      await setUserActiveInDuel(playerId, false);

      print('✅ Oyun terk edildi: $gameId');
    } catch (e) {
      print('❌ Oyun terk etme hatası: $e');
      rethrow;
    }
  }

  /// Oyunu terk et (Yeni metod - tek parametre)
  static Future<void> leaveGameNew(String gameId) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('Kullanıcı girişi bulunamadı');

      await leaveGame(gameId, userId);
    } catch (e) {
      print('❌ Oyun terk etme hatası: $e');
      rethrow;
    }
  }

  /// Matchmaking kuyruğuna katıl
  static Future<void> joinMatchmakingQueue(
      String userId, String playerName) async {
    try {
      final entry = MatchmakingEntry(
        playerId: userId,
        playerName: playerName,
        avatar: '🎮',
        createdAt: DateTime.now(),
        status: MatchmakingStatus.waiting,
      );

      await _database.child('$_matchmakingPath/$userId').set(entry.toMap());
      await setUserActiveInDuel(userId, true);

      print('✅ Matchmaking kuyruğuna katılındı: $userId');
    } catch (e) {
      print('❌ Matchmaking katılma hatası: $e');
      rethrow;
    }
  }

  /// Matchmaking kuyruğundan çık
  static Future<void> leaveMatchmakingQueue(String userId) async {
    try {
      await _database.child('$_matchmakingPath/$userId').remove();
      print('✅ Matchmaking kuyruğundan çıkıldı: $userId');
    } catch (e) {
      print('❌ Matchmaking çıkma hatası: $e');
      // Hata olsa bile devam et
    }
  }

  /// Kullanıcının düello durumunu ayarla
  static Future<void> setUserActiveInDuel(String userId, bool isActive) async {
    try {
      if (isActive) {
        await _database.child('$_activeUsersPath/$userId').set({
          'isActive': true,
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        await _database.child('$_activeUsersPath/$userId').remove();
      }
    } catch (e) {
      print('❌ Aktif kullanıcı durumu güncellenemedi: $e');
    }
  }

  /// Matchmaking işleme
  static Future<void> _processMatchmaking() async {
    if (!_isConnected) return;

    try {
      print('🔍 Matchmaking işleniyor...');

      // Bekleyen oyuncuları al
      final snapshot = await _database.child(_matchmakingPath).get();
      if (!snapshot.exists) return;

      final waitingPlayers = <MatchmakingEntry>[];
      final data = snapshot.value as Map<dynamic, dynamic>;

      for (final entry in data.entries) {
        try {
          final player = MatchmakingEntry.fromMap(
              Map<String, dynamic>.from(entry.value as Map));
          if (player.status == MatchmakingStatus.waiting) {
            waitingPlayers.add(player);
          }
        } catch (e) {
          print('❌ Oyuncu verisi parse edilemedi: $e');
        }
      }

      print('📊 Bekleyen oyuncu sayısı: ${waitingPlayers.length}');

      // En az 2 oyuncu gerekli
      if (waitingPlayers.length < 2) return;

      // İlk iki oyuncuyu eşleştir
      final player1 = waitingPlayers[0];
      final player2 = waitingPlayers[1];

      print(
          '🎯 Eşleştirme bulundu: ${player1.playerName} vs ${player2.playerName}');
      await _createDuelGame(player1, player2);
    } catch (e) {
      print('❌ Matchmaking işleme hatası: $e');
    }
  }

  /// Düello oyunu oluştur
  static Future<void> _createDuelGame(
      MatchmakingEntry player1, MatchmakingEntry player2) async {
    try {
      final gameId = 'duel_${DateTime.now().millisecondsSinceEpoch}';
      final secretWord = _getRandomWord();

      print('🎯 Oyun oluşturuluyor:');
      print('  - GameId: $gameId');
      print('  - Secret Word: $secretWord');
      print('  - Player1: ${player1.playerName} (${player1.playerId})');
      print('  - Player2: ${player2.playerName} (${player2.playerId})');

      final duelPlayer1 = DuelPlayer(
        playerId: player1.playerId,
        playerName: player1.playerName,
        avatar: player1.avatar,
        guesses: [],
        joinedAt: DateTime.now(),
      );

      final duelPlayer2 = DuelPlayer(
        playerId: player2.playerId,
        playerName: player2.playerName,
        avatar: player2.avatar,
        guesses: [],
        joinedAt: DateTime.now(),
      );

      final game = DuelGame(
        gameId: gameId,
        secretWord: secretWord,
        players: [duelPlayer1, duelPlayer2],
        status: GameStatus.active,
        currentTurn: player1.playerId,
        createdAt: DateTime.now(),
      );

      // Oyunu kaydet
      await _database.child('$_duelGamesPath/$gameId').set(game.toMap());

      // Oyuncuların matchmaking entry'lerini güncelle (gameId ve matched status)
      await _database.child('$_matchmakingPath/${player1.playerId}').update({
        'gameId': gameId,
        'status': 'matched',
      });
      await _database.child('$_matchmakingPath/${player2.playerId}').update({
        'gameId': gameId,
        'status': 'matched',
      });

      // Oyuncuları matchmaking kuyruğundan kaldır (eşleştirildiler)
      // await _database.child('$_matchmakingPath/${player1.playerId}').remove();
      // await _database.child('$_matchmakingPath/${player2.playerId}').remove();

      print('✅ Düello oyunu oluşturuldu: $gameId');
      print(
          '👥 Oyuncular eşleştirildi: ${player1.playerName} vs ${player2.playerName}');
    } catch (e) {
      print('❌ Oyun oluşturma hatası: $e');
    }
  }

  /// Rastgele kelime seç
  static String _getRandomWord() {
    if (_validWords.isEmpty) {
      return 'KELIME';
    }
    final words = _validWords.toList();
    return words[_random.nextInt(words.length)];
  }

  /// Oyun stream'ini al
  static Stream<DuelGame?> getDuelGameStream(String gameId) {
    return _database.child('$_duelGamesPath/$gameId').onValue.map((event) {
      if (!event.snapshot.exists) return null;

      try {
        final rawData = event.snapshot.value;
        if (rawData is! Map) return null;

        final data = <String, dynamic>{};
        for (final entry in rawData.entries) {
          data[entry.key.toString()] = entry.value;
        }

        return DuelGame.fromMap(data);
      } catch (e) {
        print('❌ Oyun verisi parse hatası: $e');
        return null;
      }
    });
  }

  /// Matchmaking entry stream'ini al
  static Stream<MatchmakingEntry?> getMatchmakingEntryStream(String userId) {
    return _database.child('$_matchmakingPath/$userId').onValue.map((event) {
      if (!event.snapshot.exists) return null;

      try {
        final rawData = event.snapshot.value;
        if (rawData is! Map) return null;

        final data = <String, dynamic>{};
        for (final entry in rawData.entries) {
          data[entry.key.toString()] = entry.value;
        }

        return MatchmakingEntry.fromMap(data);
      } catch (e) {
        print('❌ Matchmaking entry parse hatası: $e');
        return null;
      }
    });
  }

  /// Tahmin gönder
  static Future<void> submitGuess(
      String gameId, String playerId, List<String> guess) async {
    try {
      final gameSnapshot =
          await _database.child('$_duelGamesPath/$gameId').get();
      if (!gameSnapshot.exists) throw Exception('Oyun bulunamadı');

      final gameData = Map<String, dynamic>.from(gameSnapshot.value as Map);
      final game = DuelGame.fromMap(gameData);

      print('submitGuess çağrıldı: gameId=$gameId, playerId=$playerId');
      print('Oyun oyuncuları: ${game.players.map((p) => p.playerId).toList()}');

      if (game.status != GameStatus.active) {
        throw Exception('Oyun aktif değil');
      }

      // Oyuncunun tahmini güncelle
      // Büyük/küçük harf duyarsız arama
      final playerIndex = game.players.indexWhere(
          (p) => p.playerId.toLowerCase() == playerId.toLowerCase());
      if (playerIndex == -1) {
        print(
            'Oyuncu bulunamadı! playerId: $playerId, oyuncular: ${game.players.map((p) => p.playerId).toList()}');
        throw Exception('Oyuncu bulunamadı');
      }

      final player = game.players[playerIndex];
      final updatedGuesses = List<List<String>>.from(player.guesses);
      updatedGuesses.add(guess);

      // Kazanma kontrolü
      final guessWord = guess.join('').toTurkishUpperCase();
      final secretWordUpper = game.secretWord.toTurkishUpperCase();
      final isWinner = guessWord == secretWordUpper;
      
      print('🎯 Kazanma kontrolü:');
      print('  - Tahmin: $guessWord');
      print('  - Gizli kelime: $secretWordUpper');
      print('  - Kazandı mı: $isWinner');
      print('  - Oyuncu: $playerId');

      await _database
          .child('$_duelGamesPath/$gameId/players/$playerIndex')
          .update({
        'guesses': updatedGuesses,
        'currentAttempt': updatedGuesses.length,
        'isWinner': isWinner,
      });

      if (isWinner) {
        print('🏆 KAZANAN BULUNDU: $playerId');
        await _database.child('$_duelGamesPath/$gameId').update({
          'status': GameStatus.finished.name,
          'finishedAt': DateTime.now().millisecondsSinceEpoch,
          'winnerId': playerId,
        });
        
        // Oyuncuları matchmaking kuyruğundan çıkar ve aktif durumlarını kapat
        for (final p in game.players) {
          await leaveMatchmakingQueue(p.playerId);
          await setUserActiveInDuel(p.playerId, false);
        }
        
        print('✅ Oyun bitti, kazanan: $playerId');
        return;
      }

      // Deneme hakkı bitti mi kontrolü (kaybeden)
      if (updatedGuesses.length >= 6) {
        // Diğer oyuncunun da hakkı bittiyse oyun biter
        final updatedGameSnapshot =
            await _database.child('$_duelGamesPath/$gameId').get();
        final updatedGameData =
            Map<String, dynamic>.from(updatedGameSnapshot.value as Map);
        final updatedGame = DuelGame.fromMap(updatedGameData);
        final allFinished = updatedGame.players
            .every((p) => p.isWinner || p.guesses.length >= 6);
        if (allFinished) {
          // Kazanan var mı kontrol et
          final winner = updatedGame.players.firstWhere(
            (p) => p.isWinner,
            orElse: () => DuelPlayer(
              playerId: '',
              playerName: '',
              avatar: '',
              guesses: [],
              joinedAt: DateTime.now(),
            ),
          );
          
          final winnerId = winner.playerId.isNotEmpty ? winner.playerId : null;
          
          print('🏁 Oyun bitti - Tüm denemeler tükendi:');
          print('  - Kazanan: ${winnerId ?? "Kimse kazanmadı"}');
          
          await _database.child('$_duelGamesPath/$gameId').update({
            'status': GameStatus.finished.name,
            'finishedAt': DateTime.now().millisecondsSinceEpoch,
            'winnerId': winnerId,
          });
          
          // Oyuncuları matchmaking kuyruğundan çıkar ve aktif durumlarını kapat
          for (final p in updatedGame.players) {
            await leaveMatchmakingQueue(p.playerId);
            await setUserActiveInDuel(p.playerId, false);
          }
        }
      } else {
        // Sırayı değiştir
        final nextPlayerId =
            game.players.firstWhere((p) => p.playerId != playerId).playerId;
        await _database.child('$_duelGamesPath/$gameId').update({
          'currentTurn': nextPlayerId,
        });
      }

      print('✅ Tahmin gönderildi: ${guess.join()}');
    } catch (e) {
      print('❌ Tahmin gönderme hatası: $e');
      rethrow;
    }
  }

  /// Oyun odasını sil
  static Future<void> deleteGame(String gameId) async {
    try {
      await _database.child('$_duelGamesPath/$gameId').remove();
      print('✅ Oyun odası silindi: $gameId');
    } catch (e) {
      print('❌ Oyun odası silme hatası: $e');
    }
  }

  // ============= TEST VE GELİŞTİRME =============

  /// Test oyunu oluştur
  static Future<String> createTestGame(String userId, String playerName) async {
    try {
      final gameId = 'test_${DateTime.now().millisecondsSinceEpoch}';
      final secretWord = _getRandomWord();

      print('🎯 Test oyunu oluşturuluyor:');
      print('  - GameId: $gameId');
      print('  - Secret Word: $secretWord');
      print('  - Player: $playerName ($userId)');

      final testPlayer = DuelPlayer(
        playerId: userId,
        playerName: playerName,
        avatar: '🎮',
        guesses: [],
        joinedAt: DateTime.now(),
      );

      final botPlayer = DuelPlayer(
        playerId: 'bot_${_random.nextInt(1000)}',
        playerName: 'Bot Rakip',
        avatar: '🤖',
        guesses: [],
        joinedAt: DateTime.now(),
      );

      final game = DuelGame(
        gameId: gameId,
        secretWord: secretWord,
        players: [testPlayer, botPlayer],
        status: GameStatus.active,
        currentTurn: userId,
        createdAt: DateTime.now(),
      );

      // Oyunu Firebase'e kaydet
      await _database.child('$_duelGamesPath/$gameId').set(game.toMap());

      // Kullanıcıyı aktif olarak işaretle
      await setUserActiveInDuel(userId, true);

      print('✅ Test oyunu oluşturuldu: $gameId');
      print('👥 Oyuncular: $playerName vs Bot Rakip');

      return gameId;
    } catch (e) {
      print('❌ Test oyunu oluşturma hatası: $e');
      rethrow;
    }
  }

  /// Matchmaking durumunu al
  static Future<Map<String, dynamic>> getMatchmakingStats() async {
    try {
      final snapshot = await _database.child(_matchmakingPath).get();
      final waitingCount = snapshot.exists ? (snapshot.value as Map).length : 0;

      return {
        'waitingPlayers': waitingCount,
        'averageWaitTime': 15, // Demo değer
        'isMatchmakingActive': _isMatchmakingActive,
      };
    } catch (e) {
      print('❌ Matchmaking istatistik hatası: $e');
      return {
        'waitingPlayers': 0,
        'averageWaitTime': 15,
        'isMatchmakingActive': false,
      };
    }
  }
}
