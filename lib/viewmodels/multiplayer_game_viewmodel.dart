// lib/viewmodels/multiplayer_game_viewmodel.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/multiplayer_game.dart';
import '../services/matchmaking_service.dart';
import '../services/firebase_service.dart';
import '../services/haptic_service.dart';
import 'package:flutter/material.dart'; // Added for Color
import 'package:firebase_database/firebase_database.dart'; // Added for Firebase Database

/// 🎮 Multiplayer oyun ViewModel'i
/// 
/// Bu sınıf şu özellikleri sağlar:
/// - Eşleştirme yönetimi
/// - Oyun durumu takibi
/// - Gerçek zamanlı senkronizasyon
/// - Hamle yönetimi
/// - Oyun sonuç hesaplaması
/// - Temiz MVVM mimarisi
class MultiplayerGameViewModel extends ChangeNotifier {
  final MatchmakingService _matchmakingService = MatchmakingService();
  
  // Oyun durumu
  MultiplayerMatch? _currentMatch;
  List<GameMove> _moves = [];
  List<GameEvent> _events = [];
  MatchmakingStatus _matchmakingStatus = MatchmakingStatus.idle;
  
  // UI durumu
  bool _isLoading = false;
  String? _error;
  int _waitingPlayersCount = 0;
  
  // Oyuncu durumu
  String? _currentPlayerId;
  MultiplayerPlayer? _currentPlayer;
  MultiplayerPlayer? _opponent;
  
  // Oyun mekaniği
  List<List<String>> _guesses = [];
  List<List<LetterStatus>> _guessColors = [];
  Map<String, LetterStatus> _keyboardColors = {};
  int _currentAttempt = 0;
  int _currentColumn = 0;
  bool _gameFinished = false;
  
  // Subscription'lar
  StreamSubscription? _statusSubscription;
  StreamSubscription? _matchSubscription;
  StreamSubscription? _movesSubscription;
  StreamSubscription? _eventsSubscription;
  StreamSubscription? _waitingPlayersSubscription;
  
  // Timer'lar
  Timer? _gameTimer;
  Timer? _heartbeatTimer;
  
  // Getters
  MultiplayerMatch? get currentMatch => _currentMatch;
  List<GameMove> get moves => _moves;
  List<GameEvent> get events => _events;
  MatchmakingStatus get matchmakingStatus => _matchmakingStatus;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get waitingPlayersCount => _waitingPlayersCount;
  String? get currentPlayerId => _currentPlayerId;
  MultiplayerPlayer? get currentPlayer => _currentPlayer;
  MultiplayerPlayer? get opponent => _opponent;
  List<List<String>> get guesses => _guesses;
  List<List<LetterStatus>> get guessColors => _guessColors;
  Map<String, LetterStatus> get keyboardColors => _keyboardColors;
  int get currentAttempt => _currentAttempt;
  int get currentColumn => _currentColumn;
  bool get gameFinished => _gameFinished;
  
  // Hesaplanan özellikler
  bool get isSearching => _matchmakingStatus == MatchmakingStatus.searching;
  bool get isMatched => _matchmakingStatus == MatchmakingStatus.matched;
  bool get isInGame => _currentMatch != null && _currentMatch!.isActive;
  bool get isWinner => _currentMatch?.winner == _currentPlayerId;
  bool get isMyTurn => _currentMatch?.currentTurn == _currentPlayerId;
  bool get canMakeMove => isInGame && isMyTurn && !_gameFinished;
  
  /// 🚀 ViewModel'i başlat
  Future<void> initialize() async {
    try {
      _setLoading(true);
      
      // Mevcut kullanıcıyı al
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı giriş yapmamış');
      }
      _currentPlayerId = user.uid;
      
      debugPrint('🎮 MultiplayerGameViewModel başlatılıyor - User: ${user.uid}');
      
      // Firebase Database bağlantısını test et
      await _testFirebaseConnection();
      
      // Matchmaking servisini başlat
      await _matchmakingService.initialize();
      
      // Stream'leri dinle
      _setupListeners();
      
      _setLoading(false);
      debugPrint('✅ MultiplayerGameViewModel başlatıldı');
      
    } catch (e) {
      _setError('Başlatma hatası: $e');
      _setLoading(false);
      debugPrint('❌ ViewModel başlatma hatası: $e');
    }
  }
  
  /// 🛠️ Firebase bağlantısını test et
  Future<void> _testFirebaseConnection() async {
    try {
      debugPrint('🔍 Firebase bağlantısı test ediliyor...');
      
      // Firebase Auth durumunu kontrol et
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı authentication yapılmamış');
      }
      
      debugPrint('✅ Firebase Auth OK - User: ${user.uid}');
      
      // Firebase Database'e basit bir test yazma
      final testRef = FirebaseDatabase.instance.ref('test_connection');
      await testRef.set({
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'userId': user.uid,
        'test': 'connection_test',
      });
      
      debugPrint('✅ Firebase Database yazma testi başarılı');
      
      // Test verisini okuma
      final snapshot = await testRef.get();
      if (snapshot.exists) {
        debugPrint('✅ Firebase Database okuma testi başarılı');
        await testRef.remove(); // Test verisini temizle
      } else {
        throw Exception('Firebase Database okuma testi başarısız');
      }
      
    } catch (e) {
      debugPrint('❌ Firebase bağlantı testi başarısız: $e');
      throw Exception('Firebase bağlantı sorunu: $e');
    }
  }
  
  /// 🎯 Eşleştirme ara
  Future<bool> findMatch({
    int wordLength = 5,
    String gameMode = 'multiplayer',
  }) async {
    try {
      _setLoading(true);
      _clearError();
      
      final result = await _matchmakingService.findMatch(
        wordLength: wordLength,
        gameMode: gameMode,
      );
      
      _setLoading(false);
      
      switch (result) {
        case MatchmakingResult.success:
          return true;
        case MatchmakingResult.timeout:
          _setError('Eşleştirme zaman aşımına uğradı');
          return false;
        case MatchmakingResult.cancelled:
          _setError('Eşleştirme iptal edildi');
          return false;
        case MatchmakingResult.alreadyInGame:
          _setError('Zaten bir oyunda veya eşleştirme yapılıyor');
          return false;
        case MatchmakingResult.error:
          _setError('Eşleştirme hatası');
          return false;
      }
      
    } catch (e) {
      _setError('Eşleştirme hatası: $e');
      _setLoading(false);
      return false;
    }
  }
  
  /// 🔤 Harf girişi
  void inputLetter(String letter) {
    if (!canMakeMove || _currentColumn >= _getCurrentWordLength()) return;
    
    _guesses[_currentAttempt][_currentColumn] = letter.toUpperCase();
    _currentColumn++;
    
    // Haptic feedback
    HapticService.triggerLightHaptic();
    
    notifyListeners();
  }
  
  /// ⌫ Harf silme
  void deleteLetter() {
    if (!canMakeMove || _currentColumn <= 0) return;
    
    _currentColumn--;
    _guesses[_currentAttempt][_currentColumn] = '';
    
    // Haptic feedback
    HapticService.triggerLightHaptic();
    
    notifyListeners();
  }
  
  /// ✅ Tahmini gönder
  Future<void> submitGuess() async {
    if (!canMakeMove || _currentColumn != _getCurrentWordLength()) return;
    
    final guess = _guesses[_currentAttempt].join();
    
    // Kelime doğrulaması
    if (!await _isValidWord(guess)) {
      _setError('Geçersiz kelime');
      HapticService.triggerErrorHaptic();
      return;
    }
    
    try {
      // Hamleyi sunucuya gönder
      final success = await _matchmakingService.makeMove(
        matchId: _currentMatch!.matchId,
        guess: guess,
        attempt: _currentAttempt,
      );
      
      if (success) {
        _currentAttempt++;
        _currentColumn = 0;
        
        // Success haptic
        HapticService.triggerMediumHaptic();
        
        notifyListeners();
      } else {
        _setError('Hamle gönderilemedi');
        HapticService.triggerErrorHaptic();
      }
      
    } catch (e) {
      _setError('Hamle hatası: $e');
      HapticService.triggerErrorHaptic();
    }
  }
  
  /// 🚪 Oyundan çık
  Future<void> leaveGame() async {
    try {
      await _matchmakingService.leaveMatch();
      _resetGameState();
      
    } catch (e) {
      _setError('Oyundan çıkma hatası: $e');
    }
  }
  
  /// 🔄 Oyunu yeniden başlat
  Future<void> playAgain() async {
    try {
      _resetGameState();
      await findMatch();
      
    } catch (e) {
      _setError('Yeniden oynatma hatası: $e');
    }
  }
  
  /// 👂 Stream listener'ları ayarla
  void _setupListeners() {
    // Matchmaking durumu
    _statusSubscription = _matchmakingService.statusStream.listen((status) {
      _matchmakingStatus = status;
      notifyListeners();
    });
    
    // Match durumu
    _matchSubscription = _matchmakingService.matchStream.listen((match) {
      if (match != null) {
        _updateMatch(match);
      }
    });
    
    // Hamle güncellemeleri
    _movesSubscription = _matchmakingService.movesStream.listen((moves) {
      _updateMoves(moves);
    });
    
    // Oyun olayları
    _eventsSubscription = _matchmakingService.eventsStream.listen((events) {
      _updateEvents(events);
    });
    
    // Bekleme odası sayısı
    _waitingPlayersSubscription = _matchmakingService.waitingPlayersStream.listen((count) {
      _waitingPlayersCount = count;
      notifyListeners();
    });
  }
  
  /// 🎮 Match güncelle
  void _updateMatch(MultiplayerMatch match) {
    _currentMatch = match;
    
    // Oyuncu bilgilerini güncelle
    _currentPlayer = match.getPlayer(_currentPlayerId!);
    _opponent = match.getOpponent(_currentPlayerId!);
    
    // Oyun durumunu güncelle
    _gameFinished = match.isFinished;
    
    // Oyun grid'ini ayarla
    if (_guesses.isEmpty) {
      _initializeGameGrid(match.wordLength);
    }
    
    notifyListeners();
  }
  
  /// 🎯 Hamleleri güncelle
  void _updateMoves(List<GameMove> moves) {
    _moves = moves;
    
    // Opponent'ın hamlelerini grid'e yansıt
    _updateOpponentMoves();
    
    notifyListeners();
  }
  
  /// 🔄 Rakibin hamlelerini güncelle
  void _updateOpponentMoves() {
    if (_opponent == null || _currentMatch == null) return;
    
    // Opponent'ın hamlelerini filtrele
    final opponentMoves = _moves
        .where((move) => move.playerId == _opponent!.uid)
        .toList()
      ..sort((a, b) => a.attempt.compareTo(b.attempt));
    
    // Klavye renklerini güncelle
    for (final move in opponentMoves) {
      _updateKeyboardColorsFromMove(move);
    }
  }
  
  /// ⌨️ Klavye renklerini güncelle
  void _updateKeyboardColorsFromMove(GameMove move) {
    for (final letterResult in move.result) {
      final letter = letterResult.letter;
      final currentStatus = _keyboardColors[letter];
      
      // Daha iyi durumu koru (doğru > mevcut > yok)
      if (currentStatus != LetterStatus.correct) {
        if (letterResult.status == LetterStatus.correct) {
          _keyboardColors[letter] = LetterStatus.correct;
        } else if (letterResult.status == LetterStatus.present && 
                   currentStatus != LetterStatus.present) {
          _keyboardColors[letter] = LetterStatus.present;
        } else if (currentStatus == null) {
          _keyboardColors[letter] = letterResult.status;
        }
      }
    }
  }
  
  /// 🎪 Oyun olaylarını güncelle
  void _updateEvents(List<GameEvent> events) {
    _events = events;
    
    // Son olayları işle
    for (final event in events) {
      _handleGameEvent(event);
    }
    
    notifyListeners();
  }
  
  /// 🎯 Oyun olayını işle
  void _handleGameEvent(GameEvent event) {
    switch (event.type) {
      case GameEventType.gameStarted:
        // Oyun başladı animasyonu/ses
        break;
      case GameEventType.moveMade:
        // Hamle yapıldı bildirimi
        break;
      case GameEventType.gameFinished:
        // Oyun bitti
        _gameFinished = true;
        _handleGameFinished();
        break;
      case GameEventType.playerDisconnected:
        // Oyuncu bağlantısı kesildi
        _handlePlayerDisconnected(event.playerId);
        break;
      default:
        break;
    }
  }
  
  /// 🏁 Oyun bitişini işle
  void _handleGameFinished() {
    _gameTimer?.cancel();
    
    // Sonuç hesapla
    final isWinner = _currentMatch?.winner == _currentPlayerId;
    
    // Skor hesapla
    final score = _calculateScore();
    
    // Firebase'e sonuç kaydet
    _saveGameResult(isWinner, score);
    
    // Haptic feedback
    if (isWinner) {
      HapticService.triggerMediumHaptic();
    } else {
      HapticService.triggerErrorHaptic();
    }
  }
  
  /// 🔌 Oyuncu bağlantı kesintisini işle
  void _handlePlayerDisconnected(String playerId) {
    if (playerId == _opponent?.uid) {
      // Rakip bağlantısı kesildi
      _setError('Rakip oyundan çıktı');
    }
  }
  
  /// 🎮 Oyun grid'ini başlat
  void _initializeGameGrid(int wordLength) {
    _guesses = List.generate(6, (_) => List.filled(wordLength, ''));
    _guessColors = List.generate(6, (_) => List.filled(wordLength, LetterStatus.absent));
    _keyboardColors.clear();
    _currentAttempt = 0;
    _currentColumn = 0;
  }
  
  /// 📏 Mevcut kelime uzunluğunu al
  int _getCurrentWordLength() {
    return _currentMatch?.wordLength ?? 5;
  }
  
  /// ✅ Kelimenin geçerli olup olmadığını kontrol et
  Future<bool> _isValidWord(String word) async {
    // Basit kontrol - gerçek implementasyon kelime listesini kontrol etmeli
    return word.length == _getCurrentWordLength() && 
           word.isNotEmpty && 
           RegExp(r'^[A-ZÇĞIİÖŞÜ]+$').hasMatch(word);
  }
  
  /// 🏆 Skoru hesapla
  int _calculateScore() {
    if (_currentPlayer == null) return 0;
    
    int baseScore = 100;
    
    // Deneme bonusu
    int attemptBonus = (7 - _currentPlayer!.attempts) * 10;
    
    // Hız bonusu (zaman bazlı)
    int speedBonus = 0; // Implement based on timing
    
    return baseScore + attemptBonus + speedBonus;
  }
  
  /// 💾 Oyun sonucunu kaydet
  void _saveGameResult(bool isWinner, int score) {
    if (_currentPlayerId == null) return;
    
    FirebaseService.saveGameResult(
      uid: _currentPlayerId!,
      gameType: 'Multiplayer',
      score: score,
      isWon: isWinner,
      duration: Duration(seconds: 0), // Implement proper timing
      additionalData: {
        'opponent': _opponent?.uid,
        'matchId': _currentMatch?.matchId,
        'attempts': _currentPlayer?.attempts,
      },
    );
  }
  
  /// 🔄 Oyun durumunu sıfırla
  void _resetGameState() {
    _currentMatch = null;
    _moves.clear();
    _events.clear();
    _currentPlayer = null;
    _opponent = null;
    _guesses.clear();
    _guessColors.clear();
    _keyboardColors.clear();
    _currentAttempt = 0;
    _currentColumn = 0;
    _gameFinished = false;
    _clearError();
    
    notifyListeners();
  }
  
  /// 🔄 Loading durumunu ayarla
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  /// ❌ Hata ayarla
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }
  
  /// ✅ Hatayı temizle
  void _clearError() {
    _error = null;
    notifyListeners();
  }
  
  /// 🎨 Harf rengini al
  LetterStatus getLetterColor(int row, int col) {
    if (row >= _guessColors.length || col >= _guessColors[row].length) {
      return LetterStatus.absent;
    }
    return _guessColors[row][col];
  }
  
  /// ⌨️ Klavye harfinin rengini al
  LetterStatus getKeyboardLetterColor(String letter) {
    return _keyboardColors[letter] ?? LetterStatus.absent;
  }

  /// Map keyboard letter statuses to colors for the keyboard widget
  Map<String, Color> get keyboardColorsMapped => _keyboardColors.map(
        (key, status) => MapEntry(key, _letterStatusToColor(status)),
      );

  Color _letterStatusToColor(LetterStatus status) {
    switch (status) {
      case LetterStatus.correct:
        return const Color(0xFF538D4E); // Green
      case LetterStatus.present:
        return const Color(0xFFB59F3B); // Yellow
      case LetterStatus.absent:
        return const Color(0xFF3A3A3C); // Dark grey
      default:
        return const Color(0xFF818384); // Default grey
    }
  }
  
  /// 📊 Oyun istatistiklerini al
  Map<String, dynamic> getGameStats() {
    return {
      'currentAttempt': _currentAttempt,
      'totalAttempts': _currentPlayer?.attempts ?? 0,
      'isFinished': _gameFinished,
      'isWinner': isWinner,
      'opponent': _opponent?.displayName ?? 'Bilinmeyen',
      'matchId': _currentMatch?.matchId,
      'wordLength': _getCurrentWordLength(),
    };
  }
  
  /// 🎮 Mevcut oyun durumunu al
  String getGameStatusText() {
    if (_isLoading) return 'Yükleniyor...';
    if (_error != null) return 'Hata: $_error';
    if (isSearching) return 'Rakip aranıyor...';
    if (!isMatched) return 'Eşleştirme bekleniyor...';
    if (_gameFinished) {
      return isWinner ? 'Kazandınız!' : 'Kaybettiniz!';
    }
    if (isMyTurn) return 'Sizin sıranız';
    return 'Rakibin sırası';
  }
  
  /// 🎯 Hamle geçmişini al
  List<GameMove> getPlayerMoves(String playerId) {
    return _moves.where((move) => move.playerId == playerId).toList()
      ..sort((a, b) => a.attempt.compareTo(b.attempt));
  }
  
  /// 🧹 Temizlik
  @override
  void dispose() {
    _statusSubscription?.cancel();
    _matchSubscription?.cancel();
    _movesSubscription?.cancel();
    _eventsSubscription?.cancel();
    _waitingPlayersSubscription?.cancel();
    _gameTimer?.cancel();
    _heartbeatTimer?.cancel();
    
    _matchmakingService.dispose();
    
    super.dispose();
  }
} 