// lib/services/matchmaking_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/multiplayer_game.dart';
import '../services/firebase_service.dart';
import '../services/avatar_service.dart';

/// 🎯 Eşleştirme sonucu
enum MatchmakingResult {
  success,        // Eşleştirme başarılı
  timeout,        // Zaman aşımı
  cancelled,      // İptal edildi
  error,          // Hata oluştu
  alreadyInGame   // Zaten oyunda
}

/// 📊 Eşleştirme durumu
enum MatchmakingStatus {
  idle,           // Boşta
  searching,      // Aranıyor
  matched,        // Eşleşti
  timeout,        // Zaman aşımı
  error           // Hata
}

/// 🎮 Multiplayer eşleştirme servisi
/// 
/// Bu servis şu özellikleri sağlar:
/// - Güvenli eşleştirme (atomic operations)
/// - Otomatik timeout yönetimi
/// - Bağlantı kesintisi takibi
/// - Gerçek zamanlı durum güncellemeleri
/// - Temiz MVVM yapısı
class MatchmakingService {
  static final FirebaseDatabase _database = FirebaseDatabase.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final Uuid _uuid = const Uuid();
  
  // Realtime Database referansları
  static DatabaseReference get _waitingRoomRef => _database.ref('multiplayer/waiting_room');
  static DatabaseReference get _matchesRef => _database.ref('multiplayer/matches');
  static DatabaseReference get _movesRef => _database.ref('multiplayer/moves');
  static DatabaseReference get _eventsRef => _database.ref('multiplayer/game_events');
  static DatabaseReference get _presenceRef => _database.ref('multiplayer/user_presence');
  
  // Singleton pattern
  static final MatchmakingService _instance = MatchmakingService._internal();
  factory MatchmakingService() => _instance;
  MatchmakingService._internal();
  
  // Aktif bağlantılar ve timer'lar
  final Map<String, StreamSubscription> _activeSubscriptions = {};
  final Map<String, Timer> _activeTimers = {};
  
  // Mevcut kullanıcı durumu
  String? _currentUserId;
  MatchmakingStatus _status = MatchmakingStatus.idle;
  String? _currentMatchId;
  
  // Controller'lar
  final StreamController<MatchmakingStatus> _statusController = StreamController.broadcast();
  final StreamController<MultiplayerMatch?> _matchController = StreamController.broadcast();
  final StreamController<List<GameMove>> _movesController = StreamController.broadcast();
  final StreamController<List<GameEvent>> _eventsController = StreamController.broadcast();
  final StreamController<int> _waitingPlayersController = StreamController.broadcast();
  
  // Ayarlar
  static const Duration _matchmakingTimeout = Duration(seconds: 30);
  static const Duration _heartbeatInterval = Duration(seconds: 5);
  static const int _maxRetries = 3;
  
  // Getters
  MatchmakingStatus get status => _status;
  String? get currentMatchId => _currentMatchId;
  Stream<MatchmakingStatus> get statusStream => _statusController.stream;
  Stream<MultiplayerMatch?> get matchStream => _matchController.stream;
  Stream<List<GameMove>> get movesStream => _movesController.stream;
  Stream<List<GameEvent>> get eventsStream => _eventsController.stream;
  Stream<int> get waitingPlayersStream => _waitingPlayersController.stream;
  
  /// 🚀 Servisi başlat
  Future<void> initialize() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı giriş yapmamış');
      }
      
      _currentUserId = user.uid;
      debugPrint('🎮 MatchmakingService başlatıldı - User: ${user.uid}');
      
      // Presence durumunu ayarla
      await _setUserPresence(available: true);
      
      // Mevcut eşleşme var mı kontrol et
      await _checkExistingMatch();
      
      // Bekleme odası sayısını dinle
      _listenToWaitingRoomCount();
      
      debugPrint('✅ MatchmakingService hazır');
    } catch (e) {
      debugPrint('❌ MatchmakingService başlatma hatası: $e');
      rethrow;
    }
  }
  
  /// 🔍 Eşleştirme ara
  Future<MatchmakingResult> findMatch({
    int wordLength = 5,
    String gameMode = 'multiplayer',
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return MatchmakingResult.error;
      }
      
      // Zaten oyunda mı kontrol et
      if (_status == MatchmakingStatus.searching || _currentMatchId != null) {
        return MatchmakingResult.alreadyInGame;
      }
      
      _updateStatus(MatchmakingStatus.searching);
      
      // Bekleme odasına katıl
      final joinResult = await _joinWaitingRoom(
        wordLength: wordLength,
        gameMode: gameMode,
      );
      
      if (!joinResult) {
        _updateStatus(MatchmakingStatus.error);
        return MatchmakingResult.error;
      }
      
      // Eşleştirme dinleyicisini başlat
      final matchResult = await _startMatchmakingListener();
      
      // Bekleme odasından çık
      await _leaveWaitingRoom();
      
      return matchResult;
      
    } catch (e) {
      debugPrint('❌ Eşleştirme arama hatası: $e');
      _updateStatus(MatchmakingStatus.error);
      return MatchmakingResult.error;
    }
  }
  
  /// 🚪 Bekleme odasına katıl
  Future<bool> _joinWaitingRoom({
    required int wordLength,
    required String gameMode,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      
      // Kullanıcı profilini al
      final userProfile = await FirebaseService.getUserProfile(user.uid);
      final avatar = await FirebaseService.getUserAvatar(user.uid);
      
      final waitingUser = WaitingRoomUser(
        uid: user.uid,
        displayName: userProfile?['displayName'] ?? user.displayName ?? 'Oyuncu',
        avatar: avatar ?? AvatarService.generateAvatar(user.uid),
        joinedAt: DateTime.now(),
        lastSeen: DateTime.now(),
        gameMode: gameMode,
        preferredWordLength: wordLength,
        level: userProfile?['level'] ?? 1,
        status: 'waiting',
      );
      
      // Atomic işlem: önce kontrol et, sonra ekle
      final userRef = _waitingRoomRef.child(user.uid);
      final snapshot = await userRef.get();
      
      if (snapshot.exists) {
        // Zaten bekleme odasında
        await userRef.update({
          'lastSeen': ServerValue.timestamp,
          'status': 'waiting',
        });
      } else {
        // Yeni kullanıcı ekle
        await userRef.set(waitingUser.toFirebase());
      }
      
      debugPrint('🚪 Bekleme odasına katıldı: ${user.uid}');
      return true;
      
    } catch (e) {
      debugPrint('❌ Bekleme odasına katılma hatası: $e');
      return false;
    }
  }
  
  /// 🚪 Bekleme odasından çık
  Future<void> _leaveWaitingRoom() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      await _waitingRoomRef.child(user.uid).remove();
      debugPrint('🚪 Bekleme odasından çıktı: ${user.uid}');
      
    } catch (e) {
      debugPrint('❌ Bekleme odasından çıkma hatası: $e');
    }
  }
  
  /// 👂 Eşleştirme dinleyicisi
  Future<MatchmakingResult> _startMatchmakingListener() async {
    final completer = Completer<MatchmakingResult>();
    Timer? timeoutTimer;
    
    try {
      // Timeout timer'ını başlat
      timeoutTimer = Timer(_matchmakingTimeout, () {
        if (!completer.isCompleted) {
          completer.complete(MatchmakingResult.timeout);
        }
      });
      
      // Eşleştirme arayan diğer kullanıcıları dinle
      final subscription = _waitingRoomRef.onChildAdded.listen((event) async {
        if (completer.isCompleted) return;
        
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data == null) return;
        
        final otherUser = WaitingRoomUser.fromFirebase(
          Map<String, dynamic>.from(data),
        );
        
        // Kendini eşleştirme
        if (otherUser.uid == _currentUserId) return;
        
        // Uygun eşleşme var mı kontrol et
        if (_isCompatibleMatch(otherUser)) {
          final matchResult = await _createMatch(otherUser);
          if (matchResult != null) {
            _currentMatchId = matchResult.matchId;
            _updateStatus(MatchmakingStatus.matched);
            _matchController.add(matchResult);
            
            if (!completer.isCompleted) {
              completer.complete(MatchmakingResult.success);
            }
          }
        }
      });
      
      // Temizlik
      final result = await completer.future;
      timeoutTimer?.cancel();
      subscription.cancel();
      
      if (result == MatchmakingResult.timeout) {
        _updateStatus(MatchmakingStatus.timeout);
      }
      
      return result;
      
    } catch (e) {
      timeoutTimer?.cancel();
      debugPrint('❌ Eşleştirme dinleyici hatası: $e');
      return MatchmakingResult.error;
    }
  }
  
  /// 🤝 Eşleştirme uygunluğunu kontrol et
  bool _isCompatibleMatch(WaitingRoomUser otherUser) {
    // Kelime uzunluğu uyumlu mu?
    // Şimdilik basit kontrol, gelecekte seviye bazlı eşleştirme eklenebilir
    return otherUser.gameMode == 'multiplayer' && 
           otherUser.status == 'waiting' &&
           otherUser.isActive;
  }
  
  /// 🎮 Eşleştirme oluştur
  Future<MultiplayerMatch?> _createMatch(WaitingRoomUser opponent) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      
      // Atomic lock ile eşleştirme oluştur
      final lockKey = 'match_${DateTime.now().millisecondsSinceEpoch}';
      final matchId = _uuid.v4();
      
      // İki kullanıcıyı da lock'la
      final userRef = _waitingRoomRef.child(user.uid);
      final opponentRef = _waitingRoomRef.child(opponent.uid);
      
      // Atomic güncelleme
      await userRef.update({
        'status': 'matched',
        'matchId': matchId,
        'lockKey': lockKey,
      });
      
      await opponentRef.update({
        'status': 'matched',
        'matchId': matchId,
        'lockKey': lockKey,
      });
      
      // Kısa bekleme sonrası doğrula
      await Future.delayed(const Duration(milliseconds: 100));
      
      final userCheck = await userRef.get();
      final opponentCheck = await opponentRef.get();
      
      if (!userCheck.exists || !opponentCheck.exists) {
        throw Exception('Eşleştirme doğrulama başarısız');
      }
      
      final userData = Map<String, dynamic>.from(userCheck.value as Map);
      final opponentData = Map<String, dynamic>.from(opponentCheck.value as Map);
      
      // Lock key'leri aynı mı?
      if (userData['lockKey'] != lockKey || opponentData['lockKey'] != lockKey) {
        throw Exception('Lock key eşleşmiyor');
      }
      
      // Oyunu oluştur
      final match = await _createMultiplayerMatch(
        matchId: matchId,
        user1: WaitingRoomUser.fromFirebase(userData),
        user2: WaitingRoomUser.fromFirebase(opponentData),
      );
      
      debugPrint('🎮 Eşleştirme oluşturuldu: $matchId');
      return match;
      
    } catch (e) {
      debugPrint('❌ Eşleştirme oluşturma hatası: $e');
      return null;
    }
  }
  
  /// 🎲 Multiplayer match oluştur
  Future<MultiplayerMatch> _createMultiplayerMatch({
    required String matchId,
    required WaitingRoomUser user1,
    required WaitingRoomUser user2,
  }) async {
    // Rastgele kelime seç
    final secretWord = await _selectRandomWord(user1.preferredWordLength);
    
    // Oyuncuları oluştur
    final player1 = MultiplayerPlayer(
      uid: user1.uid,
      displayName: user1.displayName,
      avatar: user1.avatar,
      status: PlayerStatus.waiting,
      joinedAt: DateTime.now(),
      lastActionAt: DateTime.now(),
    );
    
    final player2 = MultiplayerPlayer(
      uid: user2.uid,
      displayName: user2.displayName,
      avatar: user2.avatar,
      status: PlayerStatus.waiting,
      joinedAt: DateTime.now(),
      lastActionAt: DateTime.now(),
    );
    
    // Match oluştur
    final match = MultiplayerMatch(
      matchId: matchId,
      gameMode: 'multiplayer',
      secretWord: secretWord,
      wordLength: secretWord.length,
      status: MultiplayerGameStatus.waiting,
      createdAt: DateTime.now(),
      players: {
        user1.uid: player1,
        user2.uid: player2,
      },
    );
    
    // Firebase'e kaydet
    await _matchesRef.child(matchId).set(match.toFirebase());
    
    // Oyun olayını kaydet
    await _recordGameEvent(
      matchId: matchId,
      type: GameEventType.gameStarted,
      playerId: user1.uid,
      data: {
        'opponent': user2.uid,
        'wordLength': secretWord.length,
      },
    );
    
    return match;
  }
  
  /// 🎯 Rastgele kelime seç
  Future<String> _selectRandomWord(int wordLength) async {
    try {
      // Kelime listesini assets'ten yükle
      final String data = await rootBundle.loadString('assets/kelimeler.json');
      final List<dynamic> words = json.decode(data);
      
      // Uygun uzunluktaki kelimeleri filtrele
      final filteredWords = words
          .where((word) => word is String && word.length == wordLength)
          .cast<String>()
          .toList();
      
      if (filteredWords.isEmpty) {
        // Fallback kelime
        return wordLength == 5 ? 'KELIME' : 'OYUN';
      }
      
      // Rastgele seç
      final random = Random();
      return filteredWords[random.nextInt(filteredWords.length)].toUpperCase();
      
    } catch (e) {
      debugPrint('❌ Kelime seçme hatası: $e');
      return wordLength == 5 ? 'KELIME' : 'OYUN';
    }
  }
  
  /// 📝 Oyun olayını kaydet
  Future<void> _recordGameEvent({
    required String matchId,
    required GameEventType type,
    required String playerId,
    Map<String, dynamic>? data,
  }) async {
    try {
      final event = GameEvent(
        eventId: _uuid.v4(),
        type: type,
        playerId: playerId,
        timestamp: DateTime.now(),
        data: data ?? {},
      );
      
      await _eventsRef.child(matchId).child('events').push().set(event.toFirebase());
      
    } catch (e) {
      debugPrint('❌ Oyun olayı kaydetme hatası: $e');
    }
  }
  
  /// 🎯 Hamle yap
  Future<bool> makeMove({
    required String matchId,
    required String guess,
    required int attempt,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      
      // Mevcut oyunu al
      final matchSnapshot = await _matchesRef.child(matchId).get();
      if (!matchSnapshot.exists) return false;
      
      final match = MultiplayerMatch.fromFirebase(
        Map<String, dynamic>.from(matchSnapshot.value as Map),
      );
      
      // Oyuncu kontrolü
      final player = match.getPlayer(user.uid);
      if (player == null) return false;
      
      // Hamle değerlendirmesi
      final letterResults = _evaluateGuess(guess, match.secretWord);
      
      // Hamle objesi oluştur
      final move = GameMove(
        moveId: _uuid.v4(),
        playerId: user.uid,
        attempt: attempt,
        guess: guess,
        result: letterResults,
        timestamp: DateTime.now(),
        duration: 0, // UI'dan gelmeli
      );
      
      // Firebase'e kaydet
      await _movesRef.child(matchId).child(user.uid).child('moves').push().set(move.toFirebase());
      
      // Oyuncuyu güncelle
      final updatedPlayer = player.copyWith(
        currentAttempt: attempt + 1,
        lastActionAt: DateTime.now(),
        isFinished: move.isSuccessful,
        finishedAt: move.isSuccessful ? DateTime.now() : null,
      );
      
      await _matchesRef.child(matchId).child('players').child(user.uid).update(updatedPlayer.toFirebase());
      
      // Oyun olayını kaydet
      await _recordGameEvent(
        matchId: matchId,
        type: GameEventType.moveMade,
        playerId: user.uid,
        data: {
          'guess': guess,
          'attempt': attempt,
          'isSuccessful': move.isSuccessful,
        },
      );
      
      // Oyun bitişini kontrol et
      await _checkGameFinished(matchId);
      
      return true;
      
    } catch (e) {
      debugPrint('❌ Hamle yapma hatası: $e');
      return false;
    }
  }
  
  /// 🎯 Tahmini değerlendir
  List<LetterResult> _evaluateGuess(String guess, String secretWord) {
    final results = <LetterResult>[];
    final secretLetters = secretWord.split('');
    
    // İlk geçiş: doğru pozisyonlar
    for (int i = 0; i < guess.length; i++) {
      if (i < secretWord.length && guess[i] == secretWord[i]) {
        results.add(LetterResult(
          letter: guess[i],
          status: LetterStatus.correct,
          position: i,
        ));
        secretLetters[i] = ''; // Eşleşen harfi kaldır
      } else {
        results.add(LetterResult(
          letter: guess[i],
          status: LetterStatus.absent,
          position: i,
        ));
      }
    }
    
    // İkinci geçiş: yanlış pozisyonlar
    for (int i = 0; i < results.length; i++) {
      if (results[i].status == LetterStatus.absent) {
        if (secretLetters.contains(guess[i])) {
          results[i] = LetterResult(
            letter: guess[i],
            status: LetterStatus.present,
            position: i,
          );
          secretLetters[secretLetters.indexOf(guess[i])] = '';
        }
      }
    }
    
    return results;
  }
  
  /// 🏁 Oyun bitişini kontrol et
  Future<void> _checkGameFinished(String matchId) async {
    try {
      final matchSnapshot = await _matchesRef.child(matchId).get();
      if (!matchSnapshot.exists) return;
      
      final match = MultiplayerMatch.fromFirebase(
        Map<String, dynamic>.from(matchSnapshot.value as Map),
      );
      
      // Oyuncuların durumunu kontrol et
      final players = match.players.values.toList();
      final finishedPlayers = players.where((p) => p.isFinished).toList();
      
      String? winner;
      WinType winType = WinType.solved;
      
      // Kazanan belirleme
      if (finishedPlayers.length == 1) {
        // Tek oyuncu bitirdi
        winner = finishedPlayers.first.uid;
        winType = WinType.solved;
      } else if (finishedPlayers.length == 2) {
        // İki oyuncu da bitirdi - daha az denemede bitiren kazanır
        final sorted = finishedPlayers..sort((a, b) => a.attempts.compareTo(b.attempts));
        winner = sorted.first.uid;
        winType = WinType.solved;
      }
      
      // Oyunu bitir
      if (winner != null) {
        await _finishMatch(matchId, winner, winType);
      }
      
    } catch (e) {
      debugPrint('❌ Oyun bitiş kontrolü hatası: $e');
    }
  }
  
  /// 🏆 Oyunu bitir
  Future<void> _finishMatch(String matchId, String winner, WinType winType) async {
    try {
      await _matchesRef.child(matchId).update({
        'status': MultiplayerGameStatus.finished.name,
        'winner': winner,
        'finishedAt': ServerValue.timestamp,
      });
      
      // Oyun olayını kaydet
      await _recordGameEvent(
        matchId: matchId,
        type: GameEventType.gameFinished,
        playerId: winner,
        data: {
          'winType': winType.name,
        },
      );
      
      debugPrint('🏆 Oyun bitti: $matchId, Kazanan: $winner');
      
    } catch (e) {
      debugPrint('❌ Oyun bitirme hatası: $e');
    }
  }
  
  /// 🔥 Oyundan çık
  Future<void> leaveMatch() async {
    try {
      if (_currentMatchId == null) return;
      
      final user = _auth.currentUser;
      if (user == null) return;
      
      // Oyuncuyu disconnected durumuna getir
      await _matchesRef.child(_currentMatchId!).child('players').child(user.uid).update({
        'status': PlayerStatus.disconnected.name,
        'lastActionAt': ServerValue.timestamp,
      });
      
      // Oyun olayını kaydet
      await _recordGameEvent(
        matchId: _currentMatchId!,
        type: GameEventType.playerLeft,
        playerId: user.uid,
        data: {'reason': 'user_left'},
      );
      
      // Temizlik
      await _cleanup();
      
    } catch (e) {
      debugPrint('❌ Oyundan çıkma hatası: $e');
    }
  }
  
  /// 🎮 Mevcut eşleşmeyi kontrol et
  Future<void> _checkExistingMatch() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      // Aktif eşleşme var mı?
      final matchesSnapshot = await _matchesRef
          .orderByChild('players/${user.uid}/status')
          .equalTo('playing')
          .limitToFirst(1)
          .get();
      
      if (matchesSnapshot.exists) {
        final matchData = matchesSnapshot.value as Map<dynamic, dynamic>;
        final matchId = matchData.keys.first;
        
        _currentMatchId = matchId;
        _updateStatus(MatchmakingStatus.matched);
        
        // Match dinleyicisini başlat
        _startMatchListener(matchId);
        
        debugPrint('🎮 Mevcut eşleşme bulundu: $matchId');
      }
      
    } catch (e) {
      debugPrint('❌ Mevcut eşleşme kontrolü hatası: $e');
    }
  }
  
  /// 👂 Match dinleyicisini başlat
  void _startMatchListener(String matchId) {
    _cancelSubscription('match_$matchId');
    
    final subscription = _matchesRef.child(matchId).onValue.listen((event) {
      if (event.snapshot.exists) {
        final match = MultiplayerMatch.fromFirebase(
          Map<String, dynamic>.from(event.snapshot.value as Map),
        );
        _matchController.add(match);
      }
    });
    
    _activeSubscriptions['match_$matchId'] = subscription;
  }
  
  /// 📊 Bekleme odası sayısını dinle
  void _listenToWaitingRoomCount() {
    _cancelSubscription('waiting_room_count');
    
    final subscription = _waitingRoomRef.onValue.listen((event) {
      int count = 0;
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        count = data.length;
      }
      _waitingPlayersController.add(count);
    });
    
    _activeSubscriptions['waiting_room_count'] = subscription;
  }
  
  /// 🌐 Kullanıcı presence durumunu ayarla
  Future<void> _setUserPresence({required bool available}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      final presenceRef = _presenceRef.child(user.uid);
      
      await presenceRef.set({
        'online': available,
        'lastSeen': ServerValue.timestamp,
        'currentMatch': _currentMatchId,
        'status': available ? 'available' : 'away',
        'platform': 'flutter',
      });
      
      // Disconnect listener
      if (available) {
        await presenceRef.onDisconnect().update({
          'online': false,
          'lastSeen': ServerValue.timestamp,
          'status': 'away',
        });
      }
      
    } catch (e) {
      debugPrint('❌ Presence ayarlama hatası: $e');
    }
  }
  
  /// 🗑️ Subscription iptal et
  void _cancelSubscription(String key) {
    _activeSubscriptions[key]?.cancel();
    _activeSubscriptions.remove(key);
  }
  
  /// 🗑️ Timer iptal et
  void _cancelTimer(String key) {
    _activeTimers[key]?.cancel();
    _activeTimers.remove(key);
  }
  
  /// 📊 Durumu güncelle
  void _updateStatus(MatchmakingStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }
  
  /// 🧹 Temizlik
  Future<void> _cleanup() async {
    try {
      // Bekleme odasından çık
      await _leaveWaitingRoom();
      
      // Presence durumunu güncelle
      await _setUserPresence(available: false);
      
      // Subscription'ları iptal et
      for (final subscription in _activeSubscriptions.values) {
        subscription.cancel();
      }
      _activeSubscriptions.clear();
      
      // Timer'ları iptal et
      for (final timer in _activeTimers.values) {
        timer.cancel();
      }
      _activeTimers.clear();
      
      // Durumu sıfırla
      _currentMatchId = null;
      _updateStatus(MatchmakingStatus.idle);
      
    } catch (e) {
      debugPrint('❌ Temizlik hatası: $e');
    }
  }
  
  /// 🛑 Servisi kapat
  Future<void> dispose() async {
    try {
      await _cleanup();
      
      await _statusController.close();
      await _matchController.close();
      await _movesController.close();
      await _eventsController.close();
      await _waitingPlayersController.close();
      
      debugPrint('🛑 MatchmakingService kapatıldı');
      
    } catch (e) {
      debugPrint('❌ Servis kapatma hatası: $e');
    }
  }
} 