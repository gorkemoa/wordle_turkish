import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/duel_game.dart';
import '../services/firebase_service.dart';
import '../viewmodels/wordle_viewmodel.dart';

class DuelViewModel extends ChangeNotifier {
  static const int maxAttempts = 6;
  static const int wordLength = 5;

  // Oyun durumu
  DuelGame? _currentGame;
  String? _gameId;
  String _playerName = '';
  String _currentWord = '';
  int _currentColumn = 0;
  bool _isGameActive = false;
  StreamSubscription<DuelGame?>? _gameSubscription;
  
  // Kelime seti
  Set<String> validWordsSet = {};
  bool _isLoadingWords = false;

  // Geçici tahmin (henüz gönderilmeden)
  List<String> _currentGuess = List.filled(wordLength, '');

  // Getters
  DuelGame? get currentGame => _currentGame;
  String? get gameId => _gameId;
  String get playerName => _playerName;
  String get currentWord => _currentWord;
  int get currentColumn => _currentColumn;
  bool get isGameActive => _isGameActive;
  List<String> get currentGuess => _currentGuess;
  bool get isLoadingWords => _isLoadingWords;

  // Mevcut oyuncunun verilerini al
  DuelPlayer? get currentPlayer {
    final user = FirebaseService.getCurrentUser();
    if (user == null || _currentGame == null) return null;
    return _currentGame!.players[user.uid];
  }

  // Rakip oyuncunun verilerini al
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
    super.dispose();
  }

  // Kelime listesini yükle
  Future<void> loadValidWords() async {
    if (validWordsSet.isNotEmpty) return;
    
    _isLoadingWords = true;
    notifyListeners();

    try {
      final String data = await rootBundle.loadString('assets/kelimeler.json');
      final List<dynamic> jsonWords = json.decode(data);

      final List<String> words = jsonWords
          .whereType<String>()
          .map((word) => word.trim().toTurkishUpperCase())
          .where((word) => word.length == wordLength)
          .toList();

      validWordsSet = words.toSet();
    } catch (e) {
      debugPrint('Kelime listesi yüklenirken hata: $e');
      // Yedek kelime listesi
      validWordsSet = {
        'ELMA', 'ARMUT', 'MASKE', 'KEBAP', 'SALON', 
        'BILGI', 'YAZAR', 'OYUNU', 'SIHIR', 'KALEM'
      }.toSet();
    }

    _isLoadingWords = false;
    notifyListeners();
  }

  // Rastgele kelime seç
  String _selectRandomWord() {
    if (validWordsSet.isEmpty) return 'ELMA';
    
    final words = validWordsSet.toList();
    words.shuffle();
    return words.first;
  }

  // Düello oyununu başlat
  Future<bool> startDuelGame() async {
    try {
      // Firebase'e giriş yap
      final user = await FirebaseService.signInAnonymously();
      if (user == null) return false;

      // Kelime listesini yükle
      await loadValidWords();

      // Oyuncu adı oluştur
      _playerName = FirebaseService.generatePlayerName();
      
      // Gizli kelime seç
      final secretWord = _selectRandomWord();
      
      // Oyun oluştur veya katıl
      _gameId = await FirebaseService.findOrCreateGame(_playerName, secretWord);
      if (_gameId == null) return false;

      // Oyun durumunu dinlemeye başla
      _gameSubscription = FirebaseService.listenToGame(_gameId!).listen((game) {
        _currentGame = game;
        _updateGameState();
        notifyListeners();
      });

      return true;
    } catch (e) {
      debugPrint('Düello oyunu başlatma hatası: $e');
      return false;
    }
  }

  // Oyun durumunu güncelle
  void _updateGameState() {
    if (_currentGame == null) return;

    _isGameActive = _currentGame!.status == GameStatus.active;
    
    // Oyun başladıysa gizli kelimeyi ayarla
    if (_isGameActive && _currentWord.isEmpty) {
      _currentWord = _currentGame!.secretWord;
    }
  }

  // Harf gir
  void onKeyTap(String letter) {
    if (!_isGameActive || _currentColumn >= wordLength) return;
    
    final player = currentPlayer;
    if (player == null || player.status == PlayerStatus.won) return;

    _currentGuess[_currentColumn] = letter.toTurkishUpperCase();
    _currentColumn++;
    notifyListeners();
  }

  // Harf sil
  void onBackspace() {
    if (!_isGameActive || _currentColumn <= 0) return;
    
    final player = currentPlayer;
    if (player == null || player.status == PlayerStatus.won) return;

    _currentColumn--;
    _currentGuess[_currentColumn] = '';
    notifyListeners();
  }

  // Tahmini gönder
  Future<void> onEnter() async {
    if (!_isGameActive || _currentColumn != wordLength) return;
    
    final player = currentPlayer;
    if (player == null || player.status == PlayerStatus.won) return;

    final guess = _currentGuess.join('').toTurkishUpperCase();
    
    // Kelime geçerliliğini kontrol et
    if (!_isValidWord(guess)) {
      // Geçersiz kelime animasyonu göster
      // TODO: Shake animasyonu ekle
      return;
    }

    // Renk hesapla
    final guessColors = _evaluateGuess(guess);
    
    // Firebase'e gönder
    final success = await FirebaseService.makeGuess(_gameId!, _currentGuess, guessColors);
    
    if (success) {
      // Tahmini sıfırla
      _currentGuess = List.filled(wordLength, '');
      _currentColumn = 0;
      notifyListeners();
    }
  }

  // Kelimenin geçerliliğini kontrol et
  bool _isValidWord(String word) {
    return validWordsSet.contains(word);
  }

  // Tahmini değerlendir ve renkleri hesapla
  List<String> _evaluateGuess(String guess) {
    List<String> colors = List.filled(wordLength, 'grey');
    List<String> secretLetters = _currentWord.split('');

    // İlk geçiş: doğru konumda olan harfler
    for (int i = 0; i < wordLength; i++) {
      if (guess[i] == secretLetters[i]) {
        colors[i] = 'green';
        secretLetters[i] = '';
      }
    }

    // İkinci geçiş: doğru harf ama yanlış konumda
    for (int i = 0; i < wordLength; i++) {
      if (colors[i] == 'green') continue;
      if (secretLetters.contains(guess[i])) {
        colors[i] = 'orange';
        secretLetters[secretLetters.indexOf(guess[i])] = '';
      }
    }

    return colors;
  }

  // Oyundan çık
  Future<void> leaveGame() async {
    if (_gameId != null) {
      await FirebaseService.leaveGame(_gameId!);
    }
    
    _gameSubscription?.cancel();
    _currentGame = null;
    _gameId = null;
    _isGameActive = false;
    _currentWord = '';
    _currentColumn = 0;
    _currentGuess = List.filled(wordLength, '');
    notifyListeners();
  }

  // Renk string'ini Color'a çevir
  Color getColorFromString(String colorString) {
    switch (colorString) {
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orange;
      case 'grey':
        return Colors.grey;
      default:
        return Colors.transparent;
    }
  }
} 