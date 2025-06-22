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
  
  // Countdown kontrolü
  bool _showingCountdown = false;
  
  // Oyun süresi takibi
  DateTime? _gameStartTime;
  
  // Onay sistemi
  bool _isPlayerReady = false;
  Timer? _readyTimer;
  int _readyCountdown = 10;

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
  bool get showingCountdown => _showingCountdown;

  // Oyun süresi hesaplama
  Duration get gameDuration {
    if (_gameStartTime == null) return Duration.zero;
    return DateTime.now().difference(_gameStartTime!);
  }

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

  // Onay sistemi getters
  bool get isPlayerReady => _isPlayerReady;
  int get readyCountdown => _readyCountdown;

  @override
  void dispose() {
    _gameSubscription?.cancel();
    _readyTimer?.cancel();
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
          .where((word) => word.isNotEmpty && word.length == wordLength)
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
      debugPrint('Düello oyunu başlatılıyor...');
      
      // Firebase'e giriş yap
      final user = await FirebaseService.signInAnonymously();
      if (user == null) {
        debugPrint('Firebase giriş başarısız');
        return false;
      }
      debugPrint('Firebase giriş başarılı: ${user.uid}');

      // Kelime listesini yükle
      await loadValidWords();
      debugPrint('Kelime listesi yüklendi: ${validWordsSet.length} kelime');

      // Oyuncu adı oluştur
      _playerName = FirebaseService.generatePlayerName();
      debugPrint('Oyuncu adı: $_playerName');
      
      // Gizli kelime seç
      final secretWord = _selectRandomWord();
      debugPrint('Gizli kelime seçildi: $secretWord');
      
      // Oyun oluştur veya katıl
      _gameId = await FirebaseService.findOrCreateGame(_playerName, secretWord);
      if (_gameId == null) {
        debugPrint('Oyun oluşturma başarısız');
        return false;
      }
      debugPrint('Oyun ID: $_gameId');

      // Oyun durumunu dinlemeye başla
      _gameSubscription = FirebaseService.listenToGame(_gameId!).listen(
        (game) {
          debugPrint('Oyun güncellemesi alındı');
          _currentGame = game;
          _updateGameState();
          notifyListeners();
        },
        onError: (error) {
          debugPrint('Oyun dinleme hatası: $error');
        },
      );

      return true;
    } catch (e) {
      debugPrint('Düello oyunu başlatma hatası: $e');
      return false;
    }
  }

  // Oyun durumunu güncelle
  void _updateGameState() {
    if (_currentGame == null) return;

    final previousGameActive = _isGameActive;
    final gameStatus = _currentGame!.status;
    final playerCount = _currentGame!.players.length;
    
    debugPrint('DuelViewModel - Oyun durumu güncelleniyor: $gameStatus, playerCount: $playerCount');
    
    switch (gameStatus) {
      case GameStatus.waiting:
        // Bekleme odasında
        _isGameActive = false;
        _showingCountdown = false;
        
        // 2 oyuncu varsa ve henüz onay sistemi başlamamışsa başlat
        if (playerCount == 2 && _readyTimer == null && !_isPlayerReady) {
          _startReadyCountdown();
        }
        break;
        
      case GameStatus.active:
        // Oyun aktif - ama önce countdown göster
        if (!previousGameActive && !_showingCountdown) {
          // Bekleme odasından oyuna geçiş - countdown göster
          _showingCountdown = true;
          _isGameActive = false;
          _scheduleGameStart();
        } else if (_showingCountdown) {
          // Countdown devam ediyor
          _isGameActive = false;
        } else {
          // Oyun aktif
          _isGameActive = true;
          if (_currentWord.isEmpty) {
            _currentWord = _currentGame!.secretWord;
          }
        }
        break;
        
      case GameStatus.finished:
        // Oyun bitti
        debugPrint('DuelViewModel - Oyun finished durumuna geçti');
        _isGameActive = false;
        _showingCountdown = false;
        _readyTimer?.cancel();
        break;
    }
  }

  // Oyun başlangıcını planla (countdown sonrası)
  void _scheduleGameStart() {
    Future.delayed(const Duration(seconds: 3), () {
      if (_currentGame?.status == GameStatus.active) {
        _showingCountdown = false;
        _isGameActive = true;
        _gameStartTime = DateTime.now();
        
        if (_currentWord.isEmpty) {
          _currentWord = _currentGame!.secretWord;
        }
        
        // Ready timer'ı temizle
        _readyTimer?.cancel();
        _readyTimer = null;
        
        notifyListeners();
      }
    });
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
    _resetGameState();
    notifyListeners();
  }

  // Onay sistemi başlat
  void _startReadyCountdown() {
    if (_readyTimer != null) return; // Zaten başlatılmış
    
    _readyCountdown = 10;
    _readyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _readyCountdown--;
      notifyListeners();
      
      if (_readyCountdown <= 0) {
        timer.cancel();
        _handleReadyTimeout();
      }
    });
    
    notifyListeners();
  }

  // Onay verilemezse odayı kapat ve yeni oyun ara
  void _handleReadyTimeout() async {
    if (_gameId != null) {
      // Mevcut oyunu sil
      await FirebaseService.deleteGame(_gameId!);
    }
    
    // Durumu sıfırla
    _resetGameState();
    
    // Yeni oyun aramak yerine, timeout mesajı göster
    // Kullanıcı manuel olarak yeni oyun başlatacak
    debugPrint('DuelViewModel - Ready timeout, oyun iptal edildi');
  }

  // Oyun durumunu sıfırla
  void _resetGameState() {
    _currentGame = null;
    _gameId = null;
    _isGameActive = false;
    _showingCountdown = false;
    _gameStartTime = null;
    _isPlayerReady = false;
    _readyCountdown = 10;
    _readyTimer?.cancel();
    _readyTimer = null;
    _currentWord = '';
    _currentColumn = 0;
    _currentGuess = List.filled(wordLength, '');
  }

  // Oyuncunun onay vermesi
  Future<void> setPlayerReady([bool? ready]) async {
    if (_gameId == null) return;
    
    _isPlayerReady = ready ?? !_isPlayerReady;
    notifyListeners();
    
    // Firebase'e ready durumunu gönder
    if (_isPlayerReady) {
      await FirebaseService.setPlayerReady(_gameId!);
    }
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
      case 'empty':
        return Colors.transparent;
      default:
        return Colors.transparent;
    }
  }
} 