import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../services/haptic_service.dart';
import '../models/duel_game.dart';
import '../services/firebase_service.dart';

class DuelViewModel extends ChangeNotifier {
  static const int maxAttempts = 6;
  static const int wordLength = 5;

  // Ana oyun durumu
  DuelGame? _currentGame;
  String? _gameId;
  String _playerName = '';
  String _currentWord = '';
  int _currentColumn = 0;
  bool _isGameActive = false;
  
  // Subscriptions
  StreamSubscription<DuelGame?>? _gameSubscription;
  StreamSubscription<String?>? _matchmakingSubscription;
  
  // UI durumu - Düzgün state management
  GameState _gameState = GameState.initializing;
  bool _showingCountdown = false;
  bool _opponentFound = false;
  int _preGameCountdown = 5;
  Timer? _preGameTimer;
  DateTime? _gameStartTime;

  // Kelime seti
  Set<String> validWordsSet = {};
  bool _isLoadingWords = false;

  // Geçici tahmin
  List<String> _currentGuess = List.filled(wordLength, '');

  // Klavye durumu
  Map<String, String> _keyboardLetters = {};

  // Rakip görünürlük
  bool _firstRowVisible = false;
  bool _allRowsVisible = false;
  bool _tokensDeducted = false;
  
  // Animasyon
  bool _needsShake = false;

  // Callback for navigation - Simplified
  Function()? onOpponentFoundCallback;
  Function()? onGameStartCallback;

  // Getters
  DuelGame? get currentGame => _currentGame;
  String? get gameId => _gameId;
  String get playerName => _playerName;
  String get currentWord => _currentWord;
  int get currentColumn => _currentColumn;
  bool get isGameActive => _isGameActive;
  List<String> get currentGuess => _currentGuess;
  bool get isLoadingWords => _isLoadingWords;
  bool get showingCountdown => _showingCountdown;
  Map<String, String> get keyboardLetters => _keyboardLetters;
  bool get needsShake => _needsShake;
  bool get opponentFound => _opponentFound;
  int get preGameCountdown => _preGameCountdown;
  bool get firstRowVisible => _firstRowVisible;
  bool get allRowsVisible => _allRowsVisible;
  GameState get gameState => _gameState;

  Duration get gameDuration {
    if (_gameStartTime == null) return Duration.zero;
    return DateTime.now().difference(_gameStartTime!);
  }

  DuelPlayer? get currentPlayer {
    final user = FirebaseService.getCurrentUser();
    if (user == null || _currentGame == null) return null;
    return _currentGame!.players[user.uid];
  }

  DuelPlayer? get opponentPlayer {
    final user = FirebaseService.getCurrentUser();
    if (user == null || _currentGame == null) return null;
    
    for (final player in _currentGame!.players.values) {
      if (player.playerId != user.uid) {
        return player;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _cleanupSubscriptions();
    _preGameTimer?.cancel();
    super.dispose();
  }

  void _cleanupSubscriptions() {
    _gameSubscription?.cancel();
    _matchmakingSubscription?.cancel();
    _gameSubscription = null;
    _matchmakingSubscription = null;
  }

  // Ana oyun başlatma - Simplified flow
  Future<bool> startDuelGame() async {
    try {
      debugPrint('🎮 === DÜELLO BAŞLADI ===');
      
      _gameState = GameState.initializing;
      notifyListeners();
      
      final user = FirebaseService.getCurrentUser();
      if (user == null) {
        debugPrint('❌ HATA: Kullanıcı giriş yapmamış');
        _gameState = GameState.error;
        notifyListeners();
        return false;
      }

      final currentTokens = await FirebaseService.getUserTokens(user.uid);
      if (currentTokens < 2) {
        debugPrint('❌ HATA: Yetersiz jeton: $currentTokens/2');
        _gameState = GameState.error;
        notifyListeners();
        return false;
      }

      await loadValidWords();
      
      // Kullanıcının gerçek adını kullan
      final userProfile = await FirebaseService.getUserProfile(user.uid);
      _playerName = userProfile?['displayName'] ?? user.displayName ?? 'Oyuncu${user.uid.substring(0, 4)}';
      
      final secretWord = _selectRandomWord();
      
      debugPrint('👤 Oyuncu: $_playerName');
      debugPrint('🔤 Kelime: $secretWord');

      _gameState = GameState.searching;
      notifyListeners();

      final result = await FirebaseService.findOrCreateGame(_playerName, secretWord);
      if (result == null) {
        debugPrint('❌ HATA: Matchmaking başarısız');
        _gameState = GameState.error;
        notifyListeners();
        return false;
      }

      // Sonuç analizi - User ID vs Game ID
      if (result == user.uid) {
        debugPrint('⏳ Queue\'da bekleniyor, listener başlatılıyor...');
        _gameState = GameState.searching;
        _startMatchmakingListener(user.uid);
      } else {
        debugPrint('🎯 Direkt oyun bulundu: $result');
        _gameId = result;
        _gameState = GameState.waitingRoom;
        _startGameListener();
        
        // Callback'i _updateGameState'de çağıracağız
        debugPrint('📞 Direkt oyun bulundu, waiting room state\'e geçildi');
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ HATA: $e');
      _gameState = GameState.error;
      notifyListeners();
      return false;
    }
  }

  // Matchmaking listener - Basitleştirilmiş
  void _startMatchmakingListener(String userId) {
    debugPrint('🔄 Matchmaking listener başlatıldı');
    
    _matchmakingSubscription?.cancel();
    _matchmakingSubscription = FirebaseService.listenToMatchmaking(userId).listen(
      (result) {
        debugPrint('📡 Matchmaking result: $result');
        
        if (result == 'REMOVED_FROM_QUEUE') {
          debugPrint('⚠️ Queue\'dan çıkarıldı - oyun bulunmayı bekliyoruz...');
          // Sadece bekliyoruz, background matchmaking oyunu oluşturacak
        } else if (result != null && result != 'REMOVED_FROM_QUEUE') {
          debugPrint('🎯 Oyun bulundu: $result');
          
          _gameId = result;
          _gameState = GameState.waitingRoom;
          _startGameListener();
          
          // Callback'i _updateGameState'de çağıracağız
          debugPrint('📞 Matchmaking oyun bulundu, waiting room state\'e geçildi');
          
          notifyListeners();
        }
      },
      onError: (error) {
        debugPrint('❌ Matchmaking error: $error');
        _gameState = GameState.error;
        notifyListeners();
      },
    );
  }

  // Oyun listener - Geliştirilmiş
  void _startGameListener() {
    if (_gameId == null) {
      debugPrint('⚠️ Game ID null, listener başlatılamıyor');
      return;
    }
    
    debugPrint('🎧 Game listener başlatıldı: $_gameId');
    
    _gameSubscription?.cancel();
    _gameSubscription = FirebaseService.listenToGame(_gameId!).listen(
      (game) {
        debugPrint('🎮 Game update alındı: ${game?.status}');
        
        // Oyuncu çıkış kontrolü
        if (game != null && _checkPlayerLeft(game)) {
          debugPrint('🚪 Rakip oyunu terk etti, yeni rakip aranıyor...');
          _handleOpponentLeft();
          return;
        }
        
        _currentGame = game;
        _updateGameState();
        notifyListeners();
      },
      onError: (error) {
        debugPrint('❌ Oyun listener error: $error');
        _gameState = GameState.error;
        notifyListeners();
      },
    );
  }

  // Oyuncu çıkış kontrolü
  bool _checkPlayerLeft(DuelGame game) {
    // Eğer oyun başlamamışsa ve oyuncu sayısı 1'e düştüyse
    if (game.status == GameStatus.waiting && game.players.length == 1) {
      final currentUser = FirebaseService.getCurrentUser();
      if (currentUser != null && game.players.containsKey(currentUser.uid)) {
        return true; // Rakip çıktı
      }
    }
    return false;
  }

  // Rakip çıkış durumu
  void _handleOpponentLeft() async {
    try {
      debugPrint('🔄 Rakip çıktı, yeni eşleştirme başlatılıyor...');
      
      // Mevcut oyunu temizle
      _currentGame = null;
      _gameId = null;
      _opponentFound = false;
      _preGameTimer?.cancel();
      
      // State'i searching'e çevir
      _gameState = GameState.searching;
      notifyListeners();
      
      // Yeni rakip ara
      final user = FirebaseService.getCurrentUser();
      if (user != null) {
        final userProfile = await FirebaseService.getUserProfile(user.uid);
        final playerName = userProfile?['displayName'] ?? user.displayName ?? 'Oyuncu${user.uid.substring(0, 4)}';
        final secretWord = _selectRandomWord();
        
        final result = await FirebaseService.findOrCreateGame(playerName, secretWord);
        if (result != null) {
          if (result == user.uid) {
            _startMatchmakingListener(user.uid);
          } else {
            _gameId = result;
            _gameState = GameState.waitingRoom;
            _startGameListener();
          }
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('❌ Rakip çıkış handle hatası: $e');
      _gameState = GameState.error;
      notifyListeners();
    }
  }

  // Oyun durumu güncelle - Yeniden yazıldı
  void _updateGameState() {
    if (_currentGame == null) return;

    final gameStatus = _currentGame!.status;
    final playerCount = _currentGame!.players.length;
    
    debugPrint('🔄 Game state update: Status=$gameStatus, Players=$playerCount');
    
    _updateKeyboardColors();
    
    switch (gameStatus) {
      case GameStatus.waiting:
        if (playerCount == 2 && _gameState != GameState.opponentFound && _gameState != GameState.gameStarting) {
          debugPrint('👥 İki oyuncu da hazır, opponent found sequence başlatılıyor');
          debugPrint('🎯 OPPONENT FOUND STATE\'E GEÇİLİYOR!');
          _gameState = GameState.opponentFound;
          _startOpponentFoundSequence();
        } else if (playerCount < 2) {
          // Eğer yeni waiting room state'ine geçiyorsak callback çağır
          if (_gameState != GameState.waitingRoom) {
            debugPrint('🏠 _updateGameState - Waiting room state\'e geçiliyor (playerCount: $playerCount)');
            _gameState = GameState.waitingRoom;
            
            // Callback çağır - Waiting room'a yönlendir
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (onOpponentFoundCallback != null) {
                debugPrint('📞 _updateGameState - Waiting room callback çağrılıyor');
                onOpponentFoundCallback!();
              } else {
                debugPrint('⚠️ _updateGameState - onOpponentFoundCallback null!');
              }
            });
          } else {
            debugPrint('🏠 _updateGameState - Zaten waiting room state\'te (playerCount: $playerCount)');
          }
        }
        break;
        
      case GameStatus.active:
        if (_gameState != GameState.gameStarting && _gameState != GameState.playing) {
          debugPrint('🚀 Oyun aktif duruma geçti, countdown başlatılıyor');
          _gameState = GameState.gameStarting;
          _showingCountdown = true;
          _isGameActive = false;
          _scheduleGameStart();
          
          // Game start callback
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (onGameStartCallback != null) {
              debugPrint('📞 Game start callback çağrılıyor');
              onGameStartCallback!();
            }
          });
        }
        break;
        
      case GameStatus.finished:
        debugPrint('🏁 Oyun bitti');
        _gameState = GameState.finished;
        _isGameActive = false;
        _showingCountdown = false;
        _updateTokensForGameResult();
        _cleanupFinishedGame();
        break;
    }
  }

  // Rakip bulundu sekansi - İyileştirilmiş
  void _startOpponentFoundSequence() {
    debugPrint('🎉 === OPPONENT FOUND SEQUENCE BAŞLADI ===');
    debugPrint('🎯 GameState: $_gameState');
    debugPrint('👥 Oyuncu sayısı: ${_currentGame?.players.length}');
    
    _opponentFound = true;
    _preGameCountdown = 8; // 8 saniye olarak artırıldı
    
    debugPrint('⏰ Pre-game countdown başlatıldı: $_preGameCountdown saniye');
    
    _preGameTimer?.cancel();
    _preGameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_preGameCountdown > 1) {
        _preGameCountdown--;
        debugPrint('⏰ Countdown: $_preGameCountdown saniye kaldı');
      } else {
        timer.cancel();
        _preGameTimer = null;
        debugPrint('✅ Opponent found countdown bitti, oyun başlatılıyor');
        _startGameAfterCountdown();
      }
      notifyListeners();
    });
    
    notifyListeners();
    debugPrint('🎉 Opponent found sequence kuruldu, UI güncellendi');
  }

  // Countdown sonrası oyun başlat
  void _startGameAfterCountdown() {
    _opponentFound = false;
    _preGameCountdown = 8;
    _gameState = GameState.gameStarting;
    _showingCountdown = true;
    _isGameActive = false;
    notifyListeners();
    _scheduleGameStart();
  }

  // Oyun başlangıcını planla - İyileştirilmiş
  void _scheduleGameStart() {
    debugPrint('📅 Game start scheduled');
    
    Future.delayed(const Duration(seconds: 3), () async {
      if (_currentGame?.status == GameStatus.active) {
        debugPrint('🎮 Oyun başlıyor!');
        
        await _deductGameTokens();
        
        _showingCountdown = false;
        _isGameActive = true;
        _gameState = GameState.playing;
        _gameStartTime = DateTime.now();
        
        if (_currentWord.isEmpty) {
          _currentWord = _currentGame!.secretWord;
        }
        
        debugPrint('✅ Oyun başladı, kelime: $_currentWord');
        notifyListeners();
      }
    });
  }

  // Jeton kes
  Future<void> _deductGameTokens() async {
    if (_tokensDeducted) return;
    
    final user = FirebaseService.getCurrentUser();
    if (user != null) {
      try {
        await FirebaseService.earnTokens(user.uid, -2, 'Düello Oyunu');
        _tokensDeducted = true;
        debugPrint('💰 2 jeton kesildi');
      } catch (e) {
        debugPrint('❌ Jeton kesme hatası: $e');
      }
    }
  }

  // Oyun terk et - İyileştirilmiş
  Future<void> leaveGame() async {
    try {
      debugPrint('🚪 Oyun terk ediliyor...');
      
      final user = FirebaseService.getCurrentUser();
      if (user != null) {
        await FirebaseService.leaveMatchmakingQueue(user.uid);
        if (_gameId != null) {
          await FirebaseService.leaveGame(_gameId!);
        }
      }
      
      _cleanupSubscriptions();
      _preGameTimer?.cancel();
      
      _resetForNewGame();
      
      debugPrint('✅ Oyun başarıyla terk edildi');
    } catch (e) {
      debugPrint('❌ Oyun terk etme hatası: $e');
    }
  }

  // Oyun sıfırlama - Güncellenmiş
  void resetForNewGame() {
    debugPrint('🔄 Oyun sıfırlanıyor...');
    _resetForNewGame();
  }

  void _resetForNewGame() {
    debugPrint('🔄 _resetForNewGame - Tüm state temizleniyor...');
    
    _currentGame = null;
    _gameId = null;
    _currentWord = '';
    _currentColumn = 0;
    _isGameActive = false;
    _showingCountdown = false;
    _opponentFound = false;
    _preGameCountdown = 8;
    _gameStartTime = null;
    _tokensDeducted = false;
    _firstRowVisible = false;
    _allRowsVisible = false;
    _needsShake = false;
    _gameState = GameState.initializing;
    _currentGuess = List.filled(wordLength, '');
    _keyboardLetters.clear();
    
    // Callbacks'leri temizle
    onOpponentFoundCallback = null;
    onGameStartCallback = null;
    
    _cleanupSubscriptions();
    _preGameTimer?.cancel();
    
    debugPrint('✅ _resetForNewGame - State temizlendi');
    notifyListeners();
  }

  // Rakip görünürlük
  Future<bool> buyFirstRowVisibility() async {
    final user = FirebaseService.getCurrentUser();
    if (user == null) return false;

    final currentTokens = await FirebaseService.getUserTokens(user.uid);
    if (currentTokens < 10) return false;

    try {
      await FirebaseService.earnTokens(user.uid, -10, 'Rakip İlk Satır Görünürlük');
      _firstRowVisible = true;
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> buyAllRowsVisibility() async {
    final user = FirebaseService.getCurrentUser();
    if (user == null) return false;

    final currentTokens = await FirebaseService.getUserTokens(user.uid);
    if (currentTokens < 20) return false;

    try {
      await FirebaseService.earnTokens(user.uid, -20, 'Rakip Tüm Satırlar Görünürlük');
      _allRowsVisible = true;
      _firstRowVisible = true;
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  bool shouldShowOpponentRow(int rowIndex) {
    if (_allRowsVisible) return true;
    if (_firstRowVisible && rowIndex == 0) return true;
    return false;
  }

  // Kelime yükleme - JSON dosyasından 5 harfli kelimeler
  Future<void> loadValidWords() async {
    if (_isLoadingWords || validWordsSet.isNotEmpty) return;
    
    try {
      _isLoadingWords = true;
      
      // JSON dosyasını yükle
      final String jsonString = await rootBundle.loadString('assets/kelimeler.json');
      final Map<String, dynamic> wordsData = json.decode(jsonString);
      
      // Tüm kategorilerden 5 harfli kelimeleri topla
      Set<String> allWords = {};
      for (var category in wordsData.values) {
        if (category is List) {
          for (var word in category) {
            if (word is String && word.trim().length == wordLength) {
              allWords.add(word.trim().toUpperCase());
            }
          }
        }
      }
      
      validWordsSet = allWords;
      _isLoadingWords = false;
      
      debugPrint('✅ ${validWordsSet.length} adet 5 harfli kelime yüklendi');
    } catch (e) {
      _isLoadingWords = false;
      debugPrint('❌ Kelime yükleme hatası: $e');
      
      // Fallback kelimeler - 5 harfli
      validWordsSet = {
        'ELMA', 'ARMUT', 'KEBAP', 'PİLAV', 'ÇORBA', 'PASTA', 'SALATA', 'MEYVE', 'SEBZE', 'EKMEK',
        'KÖPEK', 'KEDI', 'BALIK', 'ASLAN', 'KAPLAN', 'TAVUK', 'HOROZ', 'ÖRDEK', 'KARTAL', 'YILAN',
        'ANKARA', 'İZMİR', 'BURSA', 'KONYA', 'ADANA', 'SAMSUN', 'TRABZON', 'MERSİN', 'BODRUM', 'ALANYA',
        'FUTBOL', 'TENİS', 'YÜZME', 'KOŞU', 'GÜREŞ', 'JUDO', 'KARATE', 'BOKS', 'GOLF', 'RUGBY',
        'ŞARKI', 'MÜZİK', 'GİTAR', 'PİYANO', 'DAVUL', 'FLÜT', 'KEMAN', 'KANUN', 'ZURNA', 'KLARNET'
      };
    }
  }

  // Rastgele kelime seç
  String _selectRandomWord() {
    if (validWordsSet.isEmpty) {
      return 'KELIME';
    }
    final words = validWordsSet.toList();
    final random = math.Random();
    return words[random.nextInt(words.length)];
  }

  // Shake animasyonu sıfırlama
  void resetShake() {
    _needsShake = false;
    notifyListeners();
  }

  // String'den Color'a dönüşüm
  Color getColorFromString(String colorString) {
    switch (colorString.toLowerCase()) {
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orange;
      case 'grey':
      case 'gray':
        return Colors.grey;
      case 'empty':
        return const Color(0xFF3A3A3C);
      default:
        return const Color(0xFF3A3A3C);
    }
  }

  // Harf ipucu satın al
  Future<String?> buyLetterHint() async {
    try {
      final user = FirebaseService.getCurrentUser();
      if (user == null) return null;
      
      final currentTokens = await FirebaseService.getUserTokens(user.uid);
      if (currentTokens < 15) {
        return 'INSUFFICIENT_TOKENS';
      }
      
      if (_currentWord.isEmpty) {
        return null;
      }
      
      // Henüz tahmin edilmemiş harfleri bul
      Set<String> guessedLetters = {};
      final currentPlayer = this.currentPlayer;
      if (currentPlayer != null) {
        for (int i = 0; i < currentPlayer.currentAttempt; i++) {
          for (String letter in currentPlayer.guesses[i]) {
            if (letter != '_' && letter.isNotEmpty) {
              guessedLetters.add(letter);
            }
          }
        }
      }
      
      // Kelimede olan ama henüz tahmin edilmemiş harfleri bul
      List<String> hintLetters = [];
      for (String letter in _currentWord.split('')) {
        if (!guessedLetters.contains(letter) && !hintLetters.contains(letter)) {
          hintLetters.add(letter);
        }
      }
      
      if (hintLetters.isEmpty) {
        return 'ALL_LETTERS_GUESSED';
      }
      
      // Rastgele bir harf seç
      final random = math.Random();
      final hintLetter = hintLetters[random.nextInt(hintLetters.length)];
      
      // Jeton kes
      try {
        await FirebaseService.earnTokens(user.uid, -15, 'Düello Harf İpucu');
        return hintLetter;
      } catch (e) {
        return null;
      }
    } catch (e) {
      debugPrint('Harf ipucu hatası: $e');
      return null;
    }
  }

  // Klavye tuş basma
  void onKeyTap(String letter) {
    if (!_isGameActive || _currentGame?.status != GameStatus.active) return;

    if (_currentColumn < wordLength) {
      _currentGuess[_currentColumn] = letter.toUpperCase();
      _currentColumn++;
      notifyListeners();

      if (_currentColumn == wordLength) {
        onEnter();
      }
    }
  }

  // Backspace tuşu
  void onBackspace() {
    if (!_isGameActive || _currentGame?.status != GameStatus.active) return;

    if (_currentColumn > 0) {
      _currentColumn--;
      _currentGuess[_currentColumn] = '';
      notifyListeners();
    }
  }

  // Enter tuşu - tahmin gönder
  void onEnter() {
    if (!_isGameActive || _currentGame?.status != GameStatus.active) return;
    if (_currentColumn != wordLength) return;

    final guess = _currentGuess.join().toUpperCase();
    
    if (!_isValidWord(guess)) {
      _needsShake = true;
      HapticService.triggerErrorHaptic();
      notifyListeners();
      return;
    }

    _submitGuess(guess);
  }

  // Geçerli kelime kontrolü
  bool _isValidWord(String word) {
    return validWordsSet.contains(word);
  }

  // Tahmin gönder
  Future<void> _submitGuess(String guess) async {
    try {
      if (_gameId == null) return;
      
      final success = await FirebaseService.submitGuess(_gameId!, guess);
      if (success) {
        // Tahmin başarılı, state güncellenecek
        _currentGuess = List.filled(wordLength, '');
        _currentColumn = 0;
        notifyListeners();
      } else {
        // Hata durumunda shake göster
        _needsShake = true;
        HapticService.triggerErrorHaptic();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Tahmin gönderme hatası: $e');
      _needsShake = true;
      HapticService.triggerErrorHaptic();
      notifyListeners();
    }
  }



  // Klavye renklerini güncelle
  void _updateKeyboardColors() {
    final currentPlayer = this.currentPlayer;
    if (currentPlayer == null) return;

    _keyboardLetters.clear();

    for (int row = 0; row < currentPlayer.currentAttempt; row++) {
      for (int col = 0; col < wordLength; col++) {
        final letter = currentPlayer.guesses[row][col];
        final colorString = currentPlayer.guessColors[row][col];
        
        if (letter != '_' && letter.isNotEmpty) {
          // Öncelik: yeşil > turuncu > gri
          if (colorString == 'green') {
            _keyboardLetters[letter] = 'green';
          } else if (colorString == 'orange' && _keyboardLetters[letter] != 'green') {
            _keyboardLetters[letter] = 'orange';
          } else if (colorString == 'grey' && !_keyboardLetters.containsKey(letter)) {
            _keyboardLetters[letter] = 'grey';
          }
        }
      }
    }
  }

  void _updateTokensForGameResult() {
    // Token güncelleme mantığı
  }

  void _cleanupFinishedGame() {
    // Bitmiş oyun temizleme
  }

  Future<int> getCurrentUserTokens() async {
    final user = FirebaseService.getCurrentUser();
    if (user == null) return 0;
    return await FirebaseService.getUserTokens(user.uid);
  }












}

// Game State enum
enum GameState {
  initializing,
  searching,
  waitingRoom,
  opponentFound,
  gameStarting,
  playing,
  finished,
  error,
} 