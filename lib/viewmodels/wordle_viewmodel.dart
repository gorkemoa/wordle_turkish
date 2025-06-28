// lib/viewmodels/wordle_viewmodel.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../services/haptic_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'leaderboard_viewmodel.dart';
import '../services/firebase_service.dart';
import '../services/ad_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

extension TurkishCaseExtension on String {
  String toTurkishUpperCase() {
    return this
        .replaceAll('i', 'İ')
        .replaceAll('ğ', 'Ğ')
        .replaceAll('ü', 'Ü')
        .replaceAll('ş', 'Ş')
        .replaceAll('ö', 'Ö')
        .replaceAll('ç', 'Ç')
        .replaceAll('ı', 'I')
        .toUpperCase();
  }
}

enum GameMode {
  unlimited, // Serbest mod - sınırsız oynama, 5 harfli
  challenge, // Zorlu mod - 4'ten 8'e kademeli
  timeRush, // Zamana Karşı - 60 saniyede mümkün olduğunca çok kelime
  themed    // Tema Modları - kategoriye özel kelimeler
}

class WordleViewModel extends ChangeNotifier {
  static const int maxAttempts = 6;
  static const int minWordLength = 4;
  static const int maxWordLength = 8;
  static const int totalGameSeconds = 150; // 2 dakika 30 saniye

  final List<String> turkishKeyboard = [
    'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'İ', 'O', 'P', 'Ğ', 'Ü',
    'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'Ş', 'İ',
    'Z', 'X', 'C', 'V', 'B', 'N', 'M', 'Ö', 'Ç'
  ];

  late String _secretWord;
  List<List<String>> _guesses = [];
  List<List<Color>> _guessColors = [];
  int _currentAttempt = 0;
  bool _gameOver = false;
  bool _needsShake = false;

  final Map<String, Color> _keyboardColors = {};

  // Toplam oyun zamanlayıcı değişkenleri
  Timer? _totalTimer;
  int _totalRemainingSeconds = totalGameSeconds;
  bool _totalTimerRunning = false;

  // Oyun modu
  GameMode _gameMode = GameMode.unlimited;

  // Dinamik kelime uzunluğu ve seviye
  int _currentLevel = 1;
  int _currentWordLength = 5;
  int _currentColumn = 0; // Yeni eklendi

  // Tema modu için
  String _currentTheme = '';
  String _themeName = '';
  String _themeEmoji = '';
  
  // Zamana karşı modu için
  int _wordsGuessedCount = 0;
  int _timeRushScore = 0;
  Timer? _timeRushTimer;
  int _timeRushSeconds = 60; // 60 saniye
  bool _timeRushActive = false;

  // High scores
  int _bestTime = 9999; // in seconds
  int _bestAttempts = 999;

  // Geçerli tüm kelimeler seti
  Set<String> validWordsSet = {};
  
  // Jeton sistemi
  int _userTokens = 0;
  List<int> _revealedHints = []; // Açılan ipucu pozisyonları

  // Zorlu mod için dinamik kelime uzunluğunu belirleyen harita
  final Map<int, int> challengeModeWordLength = {
    1: 4,  // 1. seviye: 4 harf
    2: 5,  // 2. seviye: 5 harf
    3: 6,  // 3. seviye: 6 harf
    4: 7,  // 4. seviye: 7 harf
    5: 8,  // 5. seviye: 8 harf
  };

  // Maksimum seviye (sadece zorlu modda kullanılır)
  int get maxLevel => challengeModeWordLength.length;

  // 24 saatlik kısıtlama için son oyun zamanı
  DateTime? _lastChallengeModePlay;

  WordleViewModel() {
    resetGame();
    _loadBestScores();
    _loadUserTokens();
    _loadLastChallengeModePlay(); // Son zorlu mod oyun zamanını yükle
  }

  // Getters
  String get secretWord => _secretWord;
  List<List<String>> get guesses => _guesses;
  List<List<Color>> get guessColors => _guessColors;
  int get currentAttempt => _currentAttempt;
  bool get gameOver => _gameOver;
  bool get needsShake => _needsShake;
  Map<String, Color> get keyboardColors => _keyboardColors;
  int get totalRemainingSeconds => _totalRemainingSeconds;
  bool get totalTimerRunning => _totalTimerRunning;
  int get currentWordLength => _currentWordLength;
  int get currentLevel => _currentLevel;
  int get bestTime => _bestTime;
  int get bestAttempts => _bestAttempts;
  GameMode get gameMode => _gameMode;
  int get userTokens => _userTokens;
  List<int> get revealedHints => _revealedHints;
  int get currentColumn => _currentColumn;
  DateTime? get lastChallengeModePlay => _lastChallengeModePlay;
  
  // Yeni getter'lar
  String get currentTheme => _currentTheme;
  String get themeName => _themeName;
  String get themeEmoji => _themeEmoji;
  int get wordsGuessedCount => _wordsGuessedCount;
  int get timeRushScore => _timeRushScore;
  int get timeRushSeconds => _timeRushSeconds;
  bool get timeRushActive => _timeRushActive;

  // Kazanma durumu kontrol edicisi
  bool get isWinner {
    if (!_gameOver) return false;
    
    // Tüm tahminleri kontrol et
    for (int i = 0; i < _guesses.length; i++) {
      final guess = _guesses[i].join().toTurkishUpperCase();
      if (guess == _secretWord && guess.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  // Zorlu moda erişim kontrolü
  bool get canPlayChallengeMode {
    // TEST İÇİN SÜREKLI AÇIK
    return true;
    
    // Orijinal 24 saatlik kısıtlama (test bitince aç)
    // if (_lastChallengeModePlay == null) return true;
    // final now = DateTime.now();
    // final difference = now.difference(_lastChallengeModePlay!);
    // return difference.inHours >= 24;
  }
  
  // Zorlu mod için kalan süre (saat cinsinden)
  int get hoursUntilNextChallengeMode {
    // TEST İÇİN SÜREKLI 0 (erişilebilir)
    return 0;
    
    // Orijinal 24 saatlik kısıtlama hesabı (test bitince aç)
    // if (_lastChallengeModePlay == null) return 0;
    // final now = DateTime.now();
    // final difference = now.difference(_lastChallengeModePlay!);
    // final hoursLeft = 24 - difference.inHours;
    // return hoursLeft > 0 ? hoursLeft : 0;
  }

  Future<void> resetGame({GameMode? mode, String? themeId, int? customWordLength, int? customTimerDuration}) async {
    _gameOver = false;
    _needsShake = false;
    _keyboardColors.clear();
    _currentAttempt = 0;
    _currentColumn = 0; // Sıfırla
    _revealedHints.clear(); // İpuçlarını sıfırla

    // Zamana karşı modunu temizle
    _timeRushTimer?.cancel();
    _timeRushActive = false;
    _wordsGuessedCount = 0;
    _timeRushScore = 0;
    _timeRushSeconds = 60;

    // Mod ayarla
    if (mode != null) {
      _gameMode = mode;
    }

    // Mod bazında kelime uzunluğunu ve özel ayarları belirle
    switch (_gameMode) {
      case GameMode.unlimited:
        _currentWordLength = customWordLength ?? 5; // Serbest mod: custom veya varsayılan 5 harfli
        _currentLevel = 1; // Serbest modda seviye yok
        break;
      case GameMode.challenge:
        // Zorlu mod - seviye bazında kelime uzunluğunu ayarla
        _currentWordLength = challengeModeWordLength[_currentLevel] ?? 5;
        break;
      case GameMode.timeRush:
        _currentWordLength = 5; // Zamana karşı modda 5 harfli
        _currentLevel = 1;
        _timeRushActive = true;
        _timeRushSeconds = 60;
        break;
      case GameMode.themed:
        _currentWordLength = 5; // Tema modunda varsayılan 5 harfli
        _currentLevel = 1;
        // Tema bilgilerini yükle
        if (themeId != null) {
          _currentTheme = themeId;
          await _loadThemeInfo(themeId);
        }
        break;
    }

    // Tahminler ve renkler listesini güncelle
    _guesses = List.generate(maxAttempts, (_) => List.filled(_currentWordLength, ''));
    _guessColors = List.generate(maxAttempts, (_) => List.filled(_currentWordLength, Colors.transparent));

    notifyListeners();

    // Geçerli kelimeler setini yükle
    await loadValidWords();

    // Gizli kelimeyi seç
    _secretWord = selectRandomWord();
    debugPrint('Gizli Kelime: $_secretWord ($_gameMode Mod)');
    
    // Zamana karşı modunda ilk kelime için otomatik ipucu ver
    if (_gameMode == GameMode.timeRush) {
      _giveAutoHint();
    }
    
    notifyListeners();

    // Zamanlayıcıyı başlat
    if (_gameMode == GameMode.timeRush) {
      _startTimeRushTimer();
    } else if (_gameMode != GameMode.challenge) {
      // Zorlu modda zamanlayıcı yok
      _startTotalTimer(customDuration: customTimerDuration);
    }
  }

 Future<void> loadValidWords() async {
  try {
    if (_gameMode == GameMode.themed && _currentTheme.isNotEmpty) {
      // Tema modunda Firebase'den tema kelimelerini yükle
      final themedWords = await FirebaseService.getThemedWords(_currentTheme);
      validWordsSet = themedWords
          .where((word) => word.trim().length == _currentWordLength)
          .map((word) => word.trim().toTurkishUpperCase())
          .toSet();
      debugPrint('${validWordsSet.length} adet $_currentWordLength harfli tema kelimesi yüklendi ($_currentTheme)');
    } else {
      // Normal modlarda JSON dosyasını yükle
      final String data = await rootBundle.loadString('assets/kelimeler.json');

      // JSON verisini bir Map'e dönüştür
      final Map<String, dynamic> jsonData = json.decode(data);

      // Tüm kategorilerden kelimeleri topla
      List<String> allWords = [];
      for (var category in jsonData.values) {
        if (category is List) {
          for (var word in category) {
            if (word is String && word.trim().isNotEmpty) {
              allWords.add(word.trim().toTurkishUpperCase());
            }
          }
        }
      }

      // Uygun uzunluktaki kelimeleri filtrele
      final List<String> words = allWords
          .where((word) => word.length == _currentWordLength)
          .toList();

      // Kelimeleri bir sete dönüştür
      validWordsSet = words.toSet();
      debugPrint('${validWordsSet.length} adet $_currentWordLength harfli kelime yüklendi');
    }
  } catch (e) {
    // Hata durumunda yedek kelime listesi
    debugPrint('Kelime listesi yüklenirken hata oluştu: $e');
    List<String> backupWords = [
      
    ];
    validWordsSet = backupWords.where((word) => word.length == _currentWordLength).toSet();
  }
}

  String selectRandomWord() {
    
    List<String> words = validWordsSet.toList();
    words.shuffle();
    return words.first.toTurkishUpperCase();
  }

  void onKeyTap(String letter) {
    if (_gameOver) return;

    if (_currentColumn < _currentWordLength) {
      _guesses[_currentAttempt][_currentColumn] = letter.toTurkishUpperCase();
      _currentColumn++;
      notifyListeners();

      // Her harf girildiğinde zamanlayıcıyı sıfırlamayı kaldırdık
      // _resetTotalTimer();

      if (_currentColumn == _currentWordLength) {
        // Kelime tamamlandıysa tahmin et
        onEnter();
      }
    }
  }

  void onBackspace() {
    if (_gameOver) return;

    if (_currentColumn > 0) {
      _currentColumn--;
      _guesses[_currentAttempt][_currentColumn] = '';
      notifyListeners();

      // Her backspace yapıldığında zamanlayıcıyı sıfırlamayı kaldırdık
      // _resetTotalTimer();
    }
  }

  void onEnter() {
    if (_gameOver) return;

    String guess = _guesses[_currentAttempt].join().toTurkishUpperCase();

    if (!isValidWord(guess)) {
      _needsShake = true;
      HapticService.triggerErrorHaptic(); // Yeni service kullan
      notifyListeners();
      return;
    }

    _evaluateGuess(guess);
  }

  void resetShake() {
    _needsShake = false;
    notifyListeners();
  }



  bool isValidWord(String word) {
    return validWordsSet.contains(word);
  }

  void _evaluateGuess(String guess) {
    List<Color> colors = List.filled(_currentWordLength, Colors.grey);

    // Gizli kelime harflerini kopyala
    List<String> secretLetters = _secretWord.split('');

    // İlk geçiş: doğru konumda olan harfler
    for (int i = 0; i < _currentWordLength; i++) {
      if (guess[i] == secretLetters[i]) {
        colors[i] = Colors.green;
        secretLetters[i] = ''; // Eşleşen harfi kaldır
      }
    }

    // İkinci geçiş: doğru harf ama yanlış konumda
    for (int i = 0; i < _currentWordLength; i++) {
      if (colors[i] == Colors.green) continue;
      if (secretLetters.contains(guess[i])) {
        colors[i] = Colors.orange;
        secretLetters[secretLetters.indexOf(guess[i])] = ''; // Tekrar eşleşmeyi önle
      }
    }

    _guessColors[_currentAttempt] = colors;
    _updateKeyboardColors(guess);
    notifyListeners();

    if (guess == _secretWord) {
      if (_gameMode == GameMode.timeRush && _timeRushActive) {
        // Zamana karşı modunda doğru tahminde yeni kelimeye geç
        nextTimeRushWord();
      } else if (_gameMode == GameMode.challenge) {
        nextChallengeWord();
      }
      else {
        _gameOver = true;
        _stopTotalTimer();
        _updateHighScores();
        
        // Zorlu mod için son oyun zamanını kaydet
        if (_gameMode == GameMode.challenge) {
          _saveLastChallengeModePlay();
        }
        
        notifyListeners();
        // Oyun bittiğinde UI'da dialog gösterilecek
      }
    } else {
      if (_currentAttempt == maxAttempts - 1) {
        _gameOver = true;
        _stopTotalTimer();
        _updateHighScores();
        
        // Zorlu mod için son oyun zamanını kaydet (kaybedilen oyunlarda da)
        if (_gameMode == GameMode.challenge) {
          _saveLastChallengeModePlay();
        }
        
        notifyListeners();
        // Oyun bittiğinde UI'da dialog gösterilecek
      } else {
        _currentAttempt++;
        _currentColumn = 0; // Yeni denemeye başladığında sütunu sıfırla
        notifyListeners();
        // Oyun devam ederken zamanlayıcıyı sıfırlamıyoruz
      }
    }
  }

  void nextChallengeWord() {
    if (_currentLevel >= maxLevel) {
      // Son seviye tamamlandı, oyun bitti
      _gameOver = true;
      _updateHighScores();
      _saveLastChallengeModePlay();
      notifyListeners();
    } else {
      // Sonraki seviyeye geç
      _currentLevel++;
      
      _currentAttempt = 0;
      _currentColumn = 0;
      _keyboardColors.clear(); // Klavye renklerini sıfırla
      
      _currentWordLength = challengeModeWordLength[_currentLevel]!;

      // Tahminleri ve renkleri yeni kelime uzunluğuna göre sıfırla
      _guesses = List.generate(maxAttempts, (_) => List.filled(_currentWordLength, ''));
      _guessColors = List.generate(maxAttempts, (_) => List.filled(_currentWordLength, Colors.transparent));
      
      // Yeni kelimeleri yükle ve yeni gizli kelimeyi seç
      loadValidWords().then((_) {
        _secretWord = selectRandomWord();
        debugPrint('Yeni Seviye: $_currentLevel, Yeni Kelime: $_secretWord');
        notifyListeners();
      });
    }
  }

  void _updateKeyboardColors(String guess) {
    for (int i = 0; i < _currentWordLength; i++) {
      String letter = guess[i];
      if (letter.isEmpty) continue;

      if (letter == _secretWord[i]) {
        _keyboardColors[letter] = Colors.green;
      } else if (_secretWord.contains(letter)) {
        if (_keyboardColors[letter] != Colors.green) {
          _keyboardColors[letter] = Colors.orange;
        }
      } else {
        if (!_keyboardColors.containsKey(letter) ||
            (_keyboardColors[letter] != Colors.green &&
                _keyboardColors[letter] != Colors.orange)) {
          _keyboardColors[letter] = Colors.grey;
        }
      }
    }
  }

  Color getBoxColor(int row, int col) {
    if (row > _currentAttempt) {
      return Colors.grey.shade800;
    }

    if (row == _currentAttempt && !_gameOver) {
      // İpucu harfi gösteriliyorsa sarı arka plan
      if (isHintRevealed(col)) {
        return Colors.amber.withOpacity(0.3);
      }
      return Colors.grey.shade800;
    }

    String letter = _guesses[row][col];
    if (letter.isEmpty) {
      return Colors.grey.shade800;
    }

    return _guessColors[row][col];
  }

  // Toplam oyun zamanlayıcı yöntemleri
  void _startTotalTimer({int? customDuration}) {
    _totalTimerRunning = true;
    _totalRemainingSeconds = customDuration ?? totalGameSeconds;
    notifyListeners();

    _totalTimer?.cancel();
    _totalTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_totalRemainingSeconds > 0) {
        _totalRemainingSeconds--;
        notifyListeners();
      } else {
        timer.cancel();
        _totalTimerRunning = false;
        _handleTimeOut();
      }
    });
  }

  void _stopTotalTimer() {
    _totalTimer?.cancel();
    _totalTimerRunning = false;
    _totalRemainingSeconds = totalGameSeconds;
    notifyListeners();
  }

  void _handleTimeOut() {
    debugPrint('Zaman Aşımı: Oyun Denemesi Geçersiz');
    _gameOver = true;
    notifyListeners();
    // Oyun bittiğinde UI'da dialog gösterilecek
  }

  // High scores methods
  Future<void> _loadBestScores() async {
    final prefs = await SharedPreferences.getInstance();
    _bestTime = prefs.getInt('bestTime') ?? 9999;
    _bestAttempts = prefs.getInt('bestAttempts') ?? 999;
    notifyListeners();
  }

  Future<void> _saveBestScores() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bestTime', _bestTime);
    await prefs.setInt('bestAttempts', _bestAttempts);
  }

  // 24 saatlik kısıtlama için son oyun zamanı metodları
  Future<void> _loadLastChallengeModePlay() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt('lastChallengeModePlay');
    if (timestamp != null) {
      _lastChallengeModePlay = DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    notifyListeners();
  }

  Future<void> _saveLastChallengeModePlay() async {
    final prefs = await SharedPreferences.getInstance();
    _lastChallengeModePlay = DateTime.now();
    await prefs.setInt('lastChallengeModePlay', _lastChallengeModePlay!.millisecondsSinceEpoch);
    notifyListeners();
  }

  void _updateHighScores() {
    final currentTime = totalGameSeconds - _totalRemainingSeconds;
    final currentAttempts = _currentAttempt + 1;

    bool updated = false;

    if (currentTime < _bestTime) {
      _bestTime = currentTime;
      updated = true;
    }

    if (currentAttempts < _bestAttempts) {
      _bestAttempts = currentAttempts;
      updated = true;
    }

    if (updated) {
      _saveBestScores();
      notifyListeners();
    }
  }

  void updateLeaderboardStats(BuildContext context) {
    final currentTime = totalGameSeconds - _totalRemainingSeconds;
    final currentAttempts = _currentAttempt + 1;
    final gameWon = _secretWord == _guesses[_currentAttempt].join();

    try {
      final leaderboardViewModel = context.read<LeaderboardViewModel>();
      leaderboardViewModel.updateUserStats(
        gameWon: gameWon,
        attempts: currentAttempts,
        timeSpent: currentTime,
      );
    } catch (e) {
      print('Başarı tablosu güncellenirken hata: $e');
    }
  }

  // Sharing results
  String generateShareText() {
    String result = "Kelime Bul Türkçe\nLevel: $_currentLevel\nAttempts: ${_currentAttempt + 1}\n";

    for (int rowIndex = 0; rowIndex < maxAttempts; rowIndex++) {
      if (_guesses[rowIndex].isEmpty) {
        for (int col = 0; col < _currentWordLength; col++) {
          result += '⬜';
        }
      } else {
        for (int col = 0; col < _currentWordLength; col++) {
          String letter = _guesses[rowIndex][col];
          if (letter.isEmpty) {
            result += '⬜';
          } else if (letter == _secretWord[col]) {
            result += '🟩';
          } else if (_secretWord.contains(letter)) {
            result += '🟨';
          } else {
            result += '⬛';
          }
        }
      }
      result += '\n';
    }

    return result;
  }

  // Level progression (sadece zorlu modda)
  void goToNextLevel() {
    if (_gameMode == GameMode.challenge && _currentLevel < maxLevel) {
      _currentLevel++;
      resetGame();
    } else {
      _gameOver = true;
      _stopTotalTimer();
      _updateHighScores();
      notifyListeners();
      // Maksimum seviyeye ulaşıldığında yapılacak işlemler
    }
  }

  // ============= JETON SİSTEMİ =============
  
  /// Kullanıcının jeton sayısını Firebase'den yükle
  Future<void> _loadUserTokens() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _userTokens = await FirebaseService.getUserTokens(user.uid);
        notifyListeners();
      }
    } catch (e) {
      print('Jeton yükleme hatası: $e');
    }
  }
  
  /// Jeton sayısını yenile
  Future<void> refreshTokens() async {
    await _loadUserTokens();
  }
  
  /// Harf ipucu satın al (3 jeton) - sarı ipucu
  Future<bool> buyLetterHint() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      
      // Yetersiz jeton kontrolü
      if (_userTokens < 3) {
        return false;
      }
      
      // Tüm harfler açılmış mı kontrolü
      if (_revealedHints.length >= _currentWordLength) {
        return false;
      }
      
      // Rastgele bir harf pozisyonu seç (henüz açılmamış)
      List<int> availablePositions = [];
      for (int i = 0; i < _currentWordLength; i++) {
        if (!_revealedHints.contains(i)) {
          availablePositions.add(i);
        }
      }
      
      if (availablePositions.isEmpty) return false;
      
      availablePositions.shuffle();
      int selectedPosition = availablePositions.first;
      
      // 3 jeton harca
      bool success = await FirebaseService.spendTokens(user.uid, 3, 'Harf İpucu (Sarı)');
      if (success) {
        _revealedHints.add(selectedPosition);
        await _loadUserTokens(); // Jeton sayısını Firebase'den yenile
        notifyListeners();
        return true;
      }
      
      return false;
    } catch (e) {
      print('Harf ipucu satın alma hatası: $e');
      return false;
    }
  }
  
  /// Yer ipucu satın al (7 jeton) - yeşil ipucu
  Future<bool> buyPositionHint() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      
      // Yetersiz jeton kontrolü
      if (_userTokens < 7) {
        return false;
      }
      
      // Mevcut tahminde yanlış pozisyondaki harfleri bul
      if (_currentAttempt == 0 || _guesses[_currentAttempt - 1].join().isEmpty) {
        return false; // Önceki tahmin yok
      }
      
      String lastGuess = _guesses[_currentAttempt - 1].join();
      List<int> wrongPositions = [];
      
      for (int i = 0; i < lastGuess.length && i < _secretWord.length; i++) {
        if (lastGuess[i] != _secretWord[i] && _secretWord.contains(lastGuess[i])) {
          wrongPositions.add(i);
        }
      }
      
      if (wrongPositions.isEmpty) {
        return false; // Yer değiştirilecek harf yok
      }
      
      // 7 jeton harca
      bool success = await FirebaseService.spendTokens(user.uid, 7, 'Yer İpucu (Yeşil)');
      if (success) {
        // Bir harfi doğru yerine koy (geçici olarak sarı göster)
        int randomWrongPos = wrongPositions[Random().nextInt(wrongPositions.length)];
        String wrongLetter = lastGuess[randomWrongPos];
        
        // Bu harfin doğru pozisyonunu bul
        for (int i = 0; i < _secretWord.length; i++) {
          if (_secretWord[i] == wrongLetter && i != randomWrongPos) {
            // Yer ipucu gösterim logic'i eklenebilir
            break;
          }
        }
        
        await _loadUserTokens(); // Jeton sayısını Firebase'den yenile
        notifyListeners();
        return true;
      }
      
      return false;
    } catch (e) {
      print('Yer ipucu satın alma hatası: $e');
      return false;
    }
  }
  
  /// Reklam izleyerek jeton kazan
  Future<bool> watchAdForTokens() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      
      if (!AdService.isRewardedAdReady()) {
        return false;
      }
      
      bool success = await AdService.showRewardedAd(user.uid);
      if (success) {
        await refreshTokens(); // Jeton sayısını güncelle
        return true;
      }
      
      return false;
    } catch (e) {
      print('Reklam izleme hatası: $e');
      return false;
    }
  }
  
  /// Belirli pozisyondaki harfin ipucu olarak açılıp açılmadığını kontrol et
  bool isHintRevealed(int position) {
    return _revealedHints.contains(position);
  }
  
  /// İpucu harfini al
  String getHintLetter(int position) {
    if (isHintRevealed(position) && position < _secretWord.length) {
      return _secretWord[position];
    }
    return '';
  }

  // ============= TEMA MODU METOTLARİ =============

  Future<void> _loadThemeInfo(String themeId) async {
    try {
      // Tema bilgilerini belirle
      switch (themeId) {
        case 'food':
          _themeName = 'Yiyecek & İçecek';
          _themeEmoji = '🍎';
          break;
        case 'animals':
          _themeName = 'Hayvanlar';
          _themeEmoji = '🐱';
          break;
        case 'cities':
          _themeName = 'Şehirler';
          _themeEmoji = '🏙️';
          break;
        case 'sports':
          _themeName = 'Spor';
          _themeEmoji = '⚽';
          break;
        case 'music':
          _themeName = 'Müzik';
          _themeEmoji = '🎵';
          break;
        case 'random':
          // Rastgele tema seç
          final randomTheme = await FirebaseService.getRandomTheme();
          _currentTheme = randomTheme;
          await _loadThemeInfo(randomTheme);
          return;
        default:
          _themeName = 'Genel';
          _themeEmoji = '🔤';
          break;
      }
      debugPrint('Tema yüklendi: $_themeName $_themeEmoji');
    } catch (e) {
      debugPrint('Tema bilgisi yükleme hatası: $e');
      _themeName = 'Genel';
      _themeEmoji = '🔤';
    }
  }

  // ============= ZAMANA KARŞI MODU METOTLARİ =============

  void _startTimeRushTimer() {
    _timeRushActive = true;
    _timeRushSeconds = 60;
    notifyListeners();

    _timeRushTimer?.cancel();
    _timeRushTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRushSeconds > 0 && !_gameOver) {
        _timeRushSeconds--;
        notifyListeners();
      } else {
        timer.cancel();
        _timeRushActive = false;
        _handleTimeRushEnd();
      }
    });
  }

  void _handleTimeRushEnd() async {
    _gameOver = true;
    _timeRushActive = false;
    notifyListeners();

    // Oyun sonucu Firebase'e kaydet
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseService.saveTimeRushScore(
          user.uid, 
          _wordsGuessedCount, 
          60, // Başlangıç süresi
          _wordsGuessedCount * 2 // Toplam kazanılan jeton
        );
      }
    } catch (e) {
      debugPrint('Zamana karşı skor kaydetme hatası: $e');
    }
  }

  void nextTimeRushWord() async {
    // Kelime sayısını artır
    _wordsGuessedCount++;
    
    // Her doğru kelimede +30 saniye bonus süre ekle
    _timeRushSeconds = (_timeRushSeconds + 30).clamp(0, 120); // Maksimum 120 saniye
    
    // Her doğru kelimede 2 jeton ver
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseService.earnTokens(user.uid, 2, 'Zamana Karşı - Kelime Doğru');
        await _loadUserTokens(); // Jeton sayısını güncelle
      }
    } catch (e) {
      debugPrint('Jeton verme hatası: $e');
    }
    
    // Yeni kelime seç
    _secretWord = selectRandomWord();
    
    // Oyun durumunu sıfırla
    _currentAttempt = 0;
    _currentColumn = 0;
    _keyboardColors.clear();
    _revealedHints.clear(); // İpuçlarını sıfırla
    _guesses = List.generate(maxAttempts, (_) => List.filled(_currentWordLength, ''));
    _guessColors = List.generate(maxAttempts, (_) => List.filled(_currentWordLength, Colors.transparent));
    
    // Yeni kelime için otomatik ipucu ver (ilk harf hariç rastgele bir harf)
    _giveAutoHint();
    
    debugPrint('Yeni zamana karşı kelime: $_secretWord (Kelime: $_wordsGuessedCount, Süre: +30s, Jeton: +2)');
    notifyListeners();
  }

  /// Zamana karşı modunda otomatik ipucu ver (ilk harf hariç rastgele bir harf)
  void _giveAutoHint() {
    if (_gameMode == GameMode.timeRush && _secretWord.isNotEmpty) {
      // İlk harf hariç rastgele bir pozisyon seç (1'den başla)
      final List<int> availablePositions = List.generate(_currentWordLength - 1, (index) => index + 1);
      availablePositions.shuffle();
      
      if (availablePositions.isNotEmpty) {
        final int hintPosition = availablePositions.first;
        _revealedHints.add(hintPosition);
        debugPrint('Otomatik ipucu: ${hintPosition + 1}. pozisyon -> ${_secretWord[hintPosition]}');
      }
    }
  }

  @override
  void dispose() {
    _totalTimer?.cancel();
    _timeRushTimer?.cancel();
    super.dispose();
  }
}