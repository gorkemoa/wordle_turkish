import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../services/haptic_service.dart';
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
  int _readyCountdown = 20;

  // Kelime seti
  Set<String> validWordsSet = {};
  bool _isLoadingWords = false;

  // Geçici tahmin (henüz gönderilmeden)
  List<String> _currentGuess = List.filled(wordLength, '');

  // Klavye harf durumları
  Map<String, String> _keyboardLetters = {};

  // Rakip görünürlük sistemi
  bool _firstRowVisible = false;
  bool _allRowsVisible = false;
  bool _tokensDeducted = false; // Jetonların kesilip kesilmediğini takip et
  
  // Titreme animasyonu
  bool _needsShake = false;

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

  // Rakip görünürlük getters
  bool get firstRowVisible => _firstRowVisible;
  bool get allRowsVisible => _allRowsVisible;

  Future<int> getCurrentUserTokens() async {
    final user = FirebaseService.getCurrentUser();
    if (user == null) return 0;
    return await FirebaseService.getUserTokens(user.uid);
  }

  @override
  void dispose() {
    _gameSubscription?.cancel();
    _readyTimer?.cancel();
    super.dispose();
  }

  // Rakip görünürlük fonksiyonları
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
      debugPrint('İlk satır görünürlük satın alma hatası: $e');
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
      _firstRowVisible = true; // Tüm satırlar görünürse ilk satır da görünür
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Tüm satırlar görünürlük satın alma hatası: $e');
      return false;
    }
  }

  // Rakip tahtasında hangi satırların görünür olduğunu kontrol et
  bool shouldShowOpponentRow(int rowIndex) {
    if (_allRowsVisible) return true;
    if (_firstRowVisible && rowIndex == 0) return true;
    return false;
  }

  // Harf ipucu satın al (15 jeton)
  Future<String?> buyLetterHint() async {
    try {
      debugPrint('=== HARF İPUCU SATIN ALMA BAŞLADI ===');
      
      final user = FirebaseService.getCurrentUser();
      if (user == null) {
        debugPrint('HATA: Kullanıcı bulunamadı');
        return null;
      }
      
      final currentTokens = await getCurrentUserTokens();
      debugPrint('Mevcut jeton sayısı: $currentTokens');
      
      if (currentTokens < 15) {
        debugPrint('YETERSIZ JETON: $currentTokens < 15 - İşlem iptal edildi');
        return 'INSUFFICIENT_TOKENS'; // Özel string döndür
      }
      
      if (_currentWord.isEmpty) {
        debugPrint('HATA: Gizli kelime henüz belirlenmemiş');
        return null;
      }
      
      debugPrint('Gizli kelime: $_currentWord');
      
      // Henüz tahmin edilmemiş harfleri bul
      final Set<String> guessedLetters = _keyboardLetters.keys.toSet();
      debugPrint('Tahmin edilen harfler: $guessedLetters');
      
      final List<String> wordLetters = _currentWord.split('');
      final List<String> unguessedLetters = [];
      
      for (String letter in wordLetters) {
        if (!guessedLetters.contains(letter) && !unguessedLetters.contains(letter)) {
          unguessedLetters.add(letter);
        }
      }
      
      debugPrint('Tahmin edilmemiş harfler: $unguessedLetters');
      
      if (unguessedLetters.isEmpty) {
        debugPrint('TÜM HARFLER ZATEN TAHMİN EDİLMİŞ');
        return 'ALL_LETTERS_GUESSED'; // Özel string döndür
      }
      
      // Rastgele bir harf seç
      final random = math.Random();
      final hintLetter = unguessedLetters[random.nextInt(unguessedLetters.length)];
      debugPrint('Seçilen ipucu harfi: $hintLetter');
      
      // SADECE BAŞARILI OLACAĞINI BİLİYORSAK JETON KES
      debugPrint('Jeton kesimi başlıyor...');
      await FirebaseService.earnTokens(user.uid, -15, 'Harf İpucu');
      
      final newTokens = await getCurrentUserTokens();
      debugPrint('Jeton kesimi sonrası: $newTokens jeton');
      
      debugPrint('=== HARF İPUCU BAŞARIYLA SATIN ALINDI: $hintLetter ===');
      return hintLetter;
      
    } catch (e) {
      debugPrint('=== HARF İPUCU SATIN ALMA HATASI: $e ===');
      debugPrint('Hata stack trace: ${StackTrace.current}');
      return null;
    }
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
    
    }

    _isLoadingWords = false;
    notifyListeners();
  }

  // Rastgele kelime seç
  String _selectRandomWord() {
    if (validWordsSet.isEmpty) return 'ELMA';
    
    final words = validWordsSet.toList();
    final random = math.Random();
    
    // Daha gerçek rastgele seçim için timestamp kullan
    random.nextInt(words.length);
    
    final selectedWord = words[random.nextInt(words.length)];
    debugPrint('Rastgele kelime seçildi: $selectedWord (${words.length} kelime arasından)');
    
    return selectedWord;
  }

  // Düello oyununu başlat
  Future<bool> startDuelGame() async {
    try {
      debugPrint('Düello oyunu başlatılıyor...');
      
      // Mevcut kullanıcıyı kontrol et
      final user = FirebaseService.getCurrentUser();
      if (user == null) {
        debugPrint('Kullanıcı giriş yapmamış');
        return false;
      }
      debugPrint('Firebase giriş başarılı: ${user.uid}');

      // Jeton kontrolü (henüz kesme, oyun başladığında kesilecek)
      final currentTokens = await FirebaseService.getUserTokens(user.uid);
      debugPrint('Düello başlangıcında mevcut jeton: $currentTokens');
      if (currentTokens < 2) {
        debugPrint('Yetersiz jeton: $currentTokens (2 gerekli)');
        return false;
      }
      debugPrint('Jeton kontrolü başarılı: $currentTokens (2 jeton oyun başladığında kesilecek)');

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
      debugPrint('Firebase\'e oyun oluşturma isteği gönderiliyor...');
      _gameId = await FirebaseService.findOrCreateGame(_playerName, secretWord);
      if (_gameId == null) {
        debugPrint('HATA: Oyun oluşturma başarısız - Firebase bağlantısı kontrol edilsin');
        return false;
      }
      debugPrint('Oyun ID: $_gameId');

      // Oyun durumunu dinlemeye başla
      _gameSubscription = FirebaseService.listenToGame(_gameId!).listen(
        (game) {
          debugPrint('=== OYUN GÜNCELLEMESİ ALINDI ===');
          debugPrint('Oyun durumu: ${game?.status}');
          debugPrint('Oyuncu sayısı: ${game?.players.length}');
          debugPrint('Oyun ID: ${game?.gameId}');
          
          _currentGame = game;
          _updateGameState();
          notifyListeners();
          
          debugPrint('=== OYUN GÜNCELLEMESİ İŞLENDİ ===');
        },
        onError: (error) {
          debugPrint('=== OYUN DİNLEME HATASI: $error ===');
          debugPrint('Hata tipi: ${error.runtimeType}');
          debugPrint('Hata stack trace: ${StackTrace.current}');
        },
        onDone: () {
          debugPrint('=== OYUN SUBSCRIPTION KAPANDI ===');
          debugPrint('Firebase stream\'i kapatıldı');
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
    
    // Klavye harflerini güncelle
    _updateKeyboardColors();
    
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
        
        // Jeton sistemini güncelle
        _updateTokensForGameResult();
        
        // Oyun bittikten sonra odayı temizle
        Future.delayed(const Duration(seconds: 2), () async {
          await _cleanupFinishedGame();
        });
        break;
    }
  }

  // Oyun başlangıcını planla (countdown sonrası)
  void _scheduleGameStart() {
    Future.delayed(const Duration(seconds: 3), () async {
      if (_currentGame?.status == GameStatus.active) {
        // Oyun başlıyor - jetonu kes
        await _deductGameTokens();
        
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

  // Oyun başladığında jeton kes
  Future<void> _deductGameTokens() async {
    try {
      // Jetonlar zaten kesildi mi kontrol et
      if (_tokensDeducted) {
        debugPrint('Jetonlar zaten kesilmiş, tekrar kesim yapılmıyor');
        return;
      }
      
      final user = FirebaseService.getCurrentUser();
      if (user != null) {
        // Önce mevcut jetonları logla
        final tokensBefore = await FirebaseService.getUserTokens(user.uid);
        debugPrint('Jeton kesme öncesi: $tokensBefore jeton');
        
        await FirebaseService.earnTokens(user.uid, -2, 'Düello Oyunu');
        
        // Sonra yeni jeton sayısını logla
        final tokensAfter = await FirebaseService.getUserTokens(user.uid);
        debugPrint('Jeton kesme sonrası: $tokensAfter jeton (${tokensBefore - tokensAfter} jeton kesildi)');
        
        // Flag'i set et
        _tokensDeducted = true;
      }
    } catch (e) {
      debugPrint('Jeton kesme exception: $e');
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
    
    // Kelime tamamlandıysa otomatik olarak gönder
    if (_currentColumn == wordLength) {
      onEnter();
    }
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
      _needsShake = true;
      HapticService.triggerErrorHaptic(); // Yeni service kullan
      notifyListeners();
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

  // Titreme animasyonunu sıfırla
  void resetShake() {
    _needsShake = false;
    notifyListeners();
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
    try {
      debugPrint('=== OYUNDAN ÇIKMA İŞLEMİ BAŞLADI ===');
      debugPrint('Mevcut oyun ID: $_gameId');
      debugPrint('Oyun durumu: ${_currentGame?.status}');
      debugPrint('Oyuncu sayısı: ${_currentGame?.players.length}');
      
      if (_gameId != null) {
        debugPrint('Firebase\'den oyunu terk etme isteği gönderiliyor...');
        await FirebaseService.leaveGame(_gameId!);
        debugPrint('Firebase oyunu terk etme tamamlandı');
      } else {
        debugPrint('Oyun ID null, Firebase çağrısı yapılmadı');
      }
      
      debugPrint('Subscription iptal ediliyor...');
      _gameSubscription?.cancel();
      
      debugPrint('Oyun state sıfırlanıyor...');
      _resetGameState();
      
      debugPrint('Listeners güncelleniyor...');
      notifyListeners();
      
      debugPrint('=== OYUNDAN ÇIKMA İŞLEMİ TAMAMLANDI ===');
    } catch (e) {
      debugPrint('=== OYUNDAN ÇIKMA HATASI: $e ===');
      debugPrint('Hata stack trace: ${StackTrace.current}');
      
      // Hata olsa bile state'i temizle
      _gameSubscription?.cancel();
      _resetGameState();
      notifyListeners();
    }
  }

  // Onay sistemi başlat
  void _startReadyCountdown() {
    if (_readyTimer != null) return; // Zaten başlatılmış
    
    _readyCountdown = 20;
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

  // Klavye renklerini güncelle
  void _updateKeyboardColors() {
    if (_currentGame == null) return;
    
    final currentPlayer = this.currentPlayer;
    if (currentPlayer == null) return;
    
    // Oyuncunun tahminlerini kontrol et
    for (int guessIndex = 0; guessIndex < currentPlayer.guesses.length; guessIndex++) {
      final guessLetters = currentPlayer.guesses[guessIndex];
      final guessColors = currentPlayer.guessColors[guessIndex];
      
      // Boş tahminleri atla
      if (guessLetters.every((letter) => letter == '_' || letter.isEmpty)) {
        continue;
      }
      
      // Her harfi kontrol et
      for (int i = 0; i < guessLetters.length && i < guessColors.length; i++) {
        final letter = guessLetters[i];
        final color = guessColors[i];
        
        // Boş harfleri atla
        if (letter == '_' || letter.isEmpty || color == 'empty') {
          continue;
        }
        
        // Mevcut klavye rengi
        final currentColor = _keyboardLetters[letter];
        
        // Renk önceliği: yeşil > turuncu > gri
        if (color == 'green') {
          _keyboardLetters[letter] = 'green';
        } else if (color == 'orange' && currentColor != 'green') {
          _keyboardLetters[letter] = 'orange';
        } else if (color == 'grey' && currentColor != 'green' && currentColor != 'orange') {
          _keyboardLetters[letter] = 'grey';
        }
      }
    }
  }

  // Oyun durumunu sıfırla
  void _resetGameState() {
    _currentGame = null;
    _gameId = null;
    _isGameActive = false;
    _showingCountdown = false;
    _gameStartTime = null;
    _isPlayerReady = false;
    _readyCountdown = 20;
    _readyTimer?.cancel();
    _readyTimer = null;
    _currentWord = '';
    _currentColumn = 0;
    _currentGuess = List.filled(wordLength, '');
    _keyboardLetters = {}; // Klavye renklerini sıfırla
    _tokensDeducted = false; // Jeton kesim flag'ini sıfırla
    _firstRowVisible = false; // Görünürlük flag'lerini sıfırla
    _allRowsVisible = false;
    _needsShake = false; // Titreme flag'ini sıfırla
  }

  // Yeni oyun için tamamen sıfırla (public metod)
  void resetForNewGame() {
    // Mevcut subscription'ı temizle
    _gameSubscription?.cancel();
    _gameSubscription = null;
    
    // Oyun durumunu sıfırla
    _resetGameState();
    
    // Notifiers'ı güncelle
    notifyListeners();
    
    debugPrint('DuelViewModel - Yeni oyun için sıfırlandı');
  }

  // Bitmiş oyunu temizle
  Future<void> _cleanupFinishedGame() async {
    try {
      if (_gameId != null) {
        // Firebase'den oyunu sil
        await FirebaseService.deleteGame(_gameId!);
        debugPrint('DuelViewModel - Bitmiş oyun temizlendi: $_gameId');
      }
      
      // Subscription'ı temizle
      _gameSubscription?.cancel();
      _gameSubscription = null;
      
      // State'i sıfırla
      _resetGameState();
      
      // UI'ı güncelle
      notifyListeners();
      
      debugPrint('DuelViewModel - Oyun bitti ve tamamen temizlendi');
    } catch (e) {
      debugPrint('DuelViewModel - Oyun temizleme hatası: $e');
    }
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

  // Başka rakip bul
  Future<bool> findNewOpponent() async {
    try {
      debugPrint('Başka rakip aranıyor...');
      
      // Mevcut oyundan çık
      if (_gameId != null) {
        await FirebaseService.leaveGame(_gameId!);
      }
      
      // Oyun durumunu temizle ama player name'i koru
      final currentPlayerName = _playerName;
      _resetGameState();
      _playerName = currentPlayerName;
      
      // Kelime listesini kontrol et
      if (validWordsSet.isEmpty) {
        await loadValidWords();
      }
      
      // Yeni gizli kelime seç
      final secretWord = _selectRandomWord();
      debugPrint('Yeni gizli kelime seçildi: $secretWord');
      
      // Yeni oyun oluştur veya katıl
      _gameId = await FirebaseService.findOrCreateGame(_playerName, secretWord);
      if (_gameId == null) {
        debugPrint('Yeni oyun oluşturma başarısız');
        return false;
      }
      debugPrint('Yeni oyun ID: $_gameId');

      // Oyun durumunu dinlemeye başla
      _gameSubscription?.cancel(); // Eski subscription'ı temizle
      _gameSubscription = FirebaseService.listenToGame(_gameId!).listen(
        (game) {
          debugPrint('Yeni oyun güncellemesi alındı');
          _currentGame = game;
          _updateGameState();
          notifyListeners();
        },
        onError: (error) {
          debugPrint('Yeni oyun dinleme hatası: $error');
        },
      );

      debugPrint('Başka rakip arama başarılı');
      return true;
    } catch (e) {
      debugPrint('Başka rakip arama hatası: $e');
      return false;
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

  // Oyun sonucuna göre jeton güncelle
  Future<void> _updateTokensForGameResult() async {
    try {
      final user = FirebaseService.getCurrentUser();
      if (user == null || _currentGame == null) return;

      final currentPlayer = this.currentPlayer;
      final opponentPlayer = this.opponentPlayer;
      if (currentPlayer == null) return;

      // Düello sistemi: Her oyuncu 2 jeton öder, kazanan 4 jeton alır
      bool won = currentPlayer.status == PlayerStatus.won;
      bool hasOpponent = opponentPlayer != null && 
                         opponentPlayer.status != PlayerStatus.disconnected;
      
      if (hasOpponent && won) {
        // Kazanan 4 jeton alır (2 kendi + 2 rakipten)
        await FirebaseService.earnTokens(user.uid, 4, 'Düello Kazanma');
        debugPrint('Düello kazandı: +4 jeton');
      } else if (hasOpponent && !won) {
        // Kaybeden zaten başta 2 jeton ödemiş, ek ceza yok
        debugPrint('Düello kaybetti: başta ödenen 2 jeton gitti');
      } else if (!hasOpponent) {
        // Rakip yoksa veya bağlantı kesilirse başta ödenen 2 jeton geri verilir
        await FirebaseService.earnTokens(user.uid, 2, 'Düello İptali - Rakip Yok');
        debugPrint('Düello iptal (rakip yok/disconnected): +2 jeton geri');
      }
      
      debugPrint('Düello jeton güncellemesi: won=$won, hasOpponent=$hasOpponent');
    } catch (e) {
      debugPrint('Düello jeton güncelleme hatası: $e');
    }
  }
} 