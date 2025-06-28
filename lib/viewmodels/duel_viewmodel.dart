import 'dart:async';
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
  
  // UI durumu
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

  // Callback for opponent found
  Function()? onOpponentFoundCallback;

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
    _gameSubscription?.cancel();
    _matchmakingSubscription?.cancel();
    _preGameTimer?.cancel();
    super.dispose();
  }

  // Ana oyun başlatma
  Future<bool> startDuelGame() async {
    try {
      debugPrint('=== DÜELLO BAŞLADI ===');
      
      final user = FirebaseService.getCurrentUser();
      if (user == null) {
        debugPrint('HATA: Kullanıcı giriş yapmamış');
        return false;
      }

      final currentTokens = await FirebaseService.getUserTokens(user.uid);
      if (currentTokens < 2) {
        debugPrint('HATA: Yetersiz jeton: $currentTokens/2');
        return false;
      }

      await loadValidWords();
      _playerName = FirebaseService.generatePlayerName();
      final secretWord = _selectRandomWord();
      
      debugPrint('Oyuncu: $_playerName, Kelime: $secretWord');

      final result = await FirebaseService.findOrCreateGame(_playerName, secretWord);
      if (result == null) {
        debugPrint('HATA: Matchmaking başarısız');
        return false;
      }

      if (result == user.uid) {
        debugPrint('Queue\'da bekleniyor...');
        _startMatchmakingListener(user.uid);
      } else {
        debugPrint('Direkt oyun: $result');
        _gameId = result;
        _startGameListener();
      }

      return true;
    } catch (e) {
      debugPrint('HATA: $e');
      return false;
    }
  }

  // Matchmaking listener
  void _startMatchmakingListener(String userId) {
    _matchmakingSubscription = FirebaseService.listenToMatchmaking(userId).listen(
      (result) {
        if (result == 'REMOVED_FROM_QUEUE') {
          debugPrint('DuelViewModel - Queue\'dan çıkarıldı, oyun bulunmayı bekliyoruz...');
          // Queue'dan çıkarıldığında background matchmaking zaten oyunu oluşturmuş olacak
          // Sadece bekliyoruz, arama yapmıyoruz
        } else if (result != null && result != 'REMOVED_FROM_QUEUE') {
          debugPrint('DuelViewModel - Oyun bulundu: $result');
          _gameId = result;
          
          // Oyun bulunduğunda direkt callback çağır
          if (onOpponentFoundCallback != null) {
            debugPrint('DuelViewModel - Rakip bulundu callback çağrılıyor');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onOpponentFoundCallback!();
            });
          }
          
          _startGameListener();
        }
      },
      onError: (error) => debugPrint('Matchmaking error: $error'),
    );
  }



  // Oyun listener
  void _startGameListener() {
    if (_gameId == null) return;
    
    _gameSubscription?.cancel();
    _gameSubscription = FirebaseService.listenToGame(_gameId!).listen(
      (game) {
        _currentGame = game;
        _updateGameState();
        notifyListeners();
      },
      onError: (error) => debugPrint('Oyun listener error: $error'),
    );
  }

  // Oyun durumu güncelle
  void _updateGameState() {
    if (_currentGame == null) return;

    final gameStatus = _currentGame!.status;
    final playerCount = _currentGame!.players.length;
    
    _updateKeyboardColors();
    
    switch (gameStatus) {
      case GameStatus.waiting:
        _isGameActive = false;
        _showingCountdown = false;
        
        if (playerCount == 2 && !_opponentFound) {
          _startOpponentFoundSequence();
        }
        break;
        
      case GameStatus.active:
        if (!_showingCountdown) {
          _showingCountdown = true;
          _isGameActive = false;
          _scheduleGameStart();
        }
        break;
        
      case GameStatus.finished:
        _isGameActive = false;
        _showingCountdown = false;
        _updateTokensForGameResult();
        _cleanupFinishedGame();
        break;
    }
  }

  // Rakip bulundu sekansi
  void _startOpponentFoundSequence() {
    _opponentFound = true;
    _preGameCountdown = 5;
    notifyListeners();
    
    // Callback'i UI thread'inde çağır
    if (onOpponentFoundCallback != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onOpponentFoundCallback!();
      });
    }
    
    _preGameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_preGameCountdown > 1) {
        _preGameCountdown--;
        notifyListeners();
      } else {
        timer.cancel();
        _preGameTimer = null;
        _startGameAfterCountdown();
      }
    });
  }

  // Countdown sonrası oyun başlat
  void _startGameAfterCountdown() {
    _opponentFound = false;
    _preGameCountdown = 5;
    _showingCountdown = true;
    _isGameActive = false;
    notifyListeners();
    _scheduleGameStart();
  }

  // Oyun başlangıcını planla
  void _scheduleGameStart() {
    Future.delayed(const Duration(seconds: 3), () async {
      if (_currentGame?.status == GameStatus.active) {
        await _deductGameTokens();
        
        _showingCountdown = false;
        _isGameActive = true;
        _gameStartTime = DateTime.now();
        
        if (_currentWord.isEmpty) {
          _currentWord = _currentGame!.secretWord;
        }
        
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
      } catch (e) {
        debugPrint('Jeton kesme hatası: $e');
      }
    }
  }

  // Oyun terk et
  Future<void> leaveGame() async {
    try {
      final user = FirebaseService.getCurrentUser();
      if (user != null) {
        await FirebaseService.leaveMatchmakingQueue(user.uid);
        if (_gameId != null) {
          await FirebaseService.leaveGame(_gameId!);
        }
      }
      
      _gameSubscription?.cancel();
      _matchmakingSubscription?.cancel();
      _preGameTimer?.cancel();
      
      _currentGame = null;
      _gameId = null;
      _isGameActive = false;
      _showingCountdown = false;
      _opponentFound = false;
      _preGameCountdown = 5;
      _gameStartTime = null;
      _tokensDeducted = false;
      
      notifyListeners();
    } catch (e) {
      debugPrint('Oyun terk etme hatası: $e');
    }
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

  // Kelime yükleme
  Future<void> loadValidWords() async {
    if (_isLoadingWords || validWordsSet.isNotEmpty) return;
    
    try {
      _isLoadingWords = true;
      final String response = await rootBundle.loadString('assets/turkce_kelime_listesi.txt');
      final List<String> words = response.split('\n')
          .map((word) => word.trim().toUpperCase())
          .where((word) => word.length == wordLength)
          .toList();
      validWordsSet = words.toSet();
      _isLoadingWords = false;
    } catch (e) {
      _isLoadingWords = false;
      debugPrint('Kelime yükleme hatası: $e');
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

  // Oyun sıfırlama
  void resetForNewGame() {
    _currentGame = null;
    _gameId = null;
    _currentWord = '';
    _currentColumn = 0;
    _isGameActive = false;
    _showingCountdown = false;
    _opponentFound = false;
    _preGameCountdown = 5;
    _gameStartTime = null;
    _tokensDeducted = false;
    _firstRowVisible = false;
    _allRowsVisible = false;
    _needsShake = false;
    _currentGuess = List.filled(wordLength, '');
    _keyboardLetters.clear();
    
    _gameSubscription?.cancel();
    _matchmakingSubscription?.cancel();
    _preGameTimer?.cancel();
    
    notifyListeners();
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