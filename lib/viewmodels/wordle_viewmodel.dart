// lib/viewmodels/wordle_viewmodel.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

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

  // Dinamik kelime uzunluğu ve seviye
  int _currentLevel = 1;
  int _currentWordLength = 5;
  int _currentColumn = 0; // Yeni eklendi

  // High scores
  int _bestTime = 9999; // in seconds
  int _bestAttempts = 999;

  // Geçerli tüm kelimeler seti
  Set<String> validWordsSet = {};

  // Dinamik kelime uzunluğunu belirleyen harita
  final Map<int, int> levelWordLength = {
    1: 4,
    2: 5,
    3: 6,
    4: 7,
    5: 8,
  };

  // Maksimum seviye
  int get maxLevel => levelWordLength.length;

  WordleViewModel() {
    resetGame();
    _loadBestScores();
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

  Future<void> resetGame() async {
    _gameOver = false;
    _needsShake = false;
    _keyboardColors.clear();
    _currentAttempt = 0;
    _currentColumn = 0; // Sıfırla

    // Seviye bazında kelime uzunluğunu ayarla
    _currentWordLength = levelWordLength[_currentLevel] ?? 5;

    // Tahminler ve renkler listesini güncelle
    _guesses = List.generate(maxAttempts, (_) => List.filled(_currentWordLength, ''));
    _guessColors = List.generate(maxAttempts, (_) => List.filled(_currentWordLength, Colors.transparent));

    notifyListeners();

    // Geçerli kelimeler setini yükle
    await loadValidWords();

    // Gizli kelimeyi seç
    _secretWord = selectRandomWord();
    debugPrint('Gizli Kelime: $_secretWord'); // Gizli kelimeyi debug konsoluna yazdır
    notifyListeners();

    // Toplam oyun zamanlayıcısını başlat
    _startTotalTimer();
  }

 Future<void> loadValidWords() async {
  try {
    // JSON dosyasını yükle
    final String data = await rootBundle.loadString('assets/kelimeler.json');

    // JSON verisini bir listeye dönüştür
    final List<dynamic> jsonWords = json.decode(data);

    // Listeyi String olarak filtrele ve uygun uzunluktaki kelimeleri al
    final List<String> words = jsonWords
        .whereType<String>() // Sadece String olanları filtrele
        .map((word) => word.trim().toTurkishUpperCase())
        .where((word) => word.length == _currentWordLength)
        .toList();

    // Kelimeleri bir sete dönüştür
    validWordsSet = words.toSet();
  } catch (e) {
    // Hata durumunda yedek kelime listesi
    debugPrint('Kelime listesi yüklenirken hata oluştu: $e');
    List<String> backupWords = [
      'ELMA', 'ARMUT', 'MASKE', 'CAMLI', 'KEBAP',
      'BILGI', 'YAZAR', 'OYUNU', 'SIHIR', 'UCMAK',
      'AKREP', 'SALON', 'ÇAMUR', 'KAPLI', 'ÖRDEK'
    ];
    validWordsSet = backupWords.where((word) => word.length == _currentWordLength).toSet();
  }
}

  String selectRandomWord() {
    if (validWordsSet.isEmpty) {
      // Yedek kelime listesi, eğer yükleme başarısızsa
      List<String> backupWords = [
        'ELMA', 'ARMUT', 'MASKE', 'CAMLI', 'KEBAP',
        'BILGI', 'YAZAR', 'OYUNU', 'SIHIR', 'UCMAK',
        'AKREP', 'SALON', 'ÇAMUR', 'KAPLI', 'ÖRDEK'
      ];
      backupWords = backupWords.where((word) => word.length == _currentWordLength).toList();
      backupWords.shuffle();
      return backupWords.first.toTurkishUpperCase();
    }
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
      _gameOver = true;
      _stopTotalTimer();
      _updateHighScores();
      notifyListeners();
      // Oyun bittiğinde UI'da dialog gösterilecek
    } else {
      if (_currentAttempt == maxAttempts - 1) {
        _gameOver = true;
        _stopTotalTimer();
        _updateHighScores();
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
      return Colors.grey.shade800;
    }

    String letter = _guesses[row][col];
    if (letter.isEmpty) {
      return Colors.grey.shade800;
    }

    return _guessColors[row][col];
  }

  // Toplam oyun zamanlayıcı yöntemleri
  void _startTotalTimer() {
    _totalTimerRunning = true;
    _totalRemainingSeconds = totalGameSeconds;
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

  // Level progression
  void goToNextLevel() {
    if (_currentLevel < maxLevel) {
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
}