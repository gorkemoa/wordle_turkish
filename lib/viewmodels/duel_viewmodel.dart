import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../models/duel_game.dart';
import '../services/duel_service.dart';
import '../services/haptic_service.dart';
import '../utils/turkish_case_extension.dart';

class DuelViewModel extends ChangeNotifier {
  // Oyun durumu
  DuelGame? _currentGame;
  String? _gameId;
  String? _currentPlayerId;
  bool _isLoading = false;
  String? _errorMessage;

  // Kelime listesi
  List<String> _wordList = [];
  String _secretWord = '';

  // Gerçek zamanlı dinleme
  StreamSubscription? _gameSubscription;

  // Oyuncu giriş durumu
  String _currentGuess = '';
  bool _canSubmitGuess = false;
  List<String> _currentLetters = [];

  // Animasyon ve UI durumu
  bool _showShakeAnimation = false;
  bool _showWinAnimation = false;
  bool _showLoseAnimation = false;

  // Zaman takibi
  DateTime? _startTime;
  DateTime? _endTime;

  int get elapsedSeconds {
    if (_startTime == null) return 0;
    final end = _endTime ?? DateTime.now();
    return end.difference(_startTime!).inSeconds;
  }

  // Getters
  DuelGame? get currentGame => _currentGame;
  String? get gameId => _gameId;
  String? get currentPlayerId => _currentPlayerId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get currentGuess => _currentGuess;
  bool get canSubmitGuess => _canSubmitGuess;
  List<String> get currentLetters => _currentLetters;
  bool get showShakeAnimation => _showShakeAnimation;
  bool get showWinAnimation => _showWinAnimation;
  bool get showLoseAnimation => _showLoseAnimation;

  /// Oyun durumu getters
  bool get isGameFinished => _currentGame?.status == GameStatus.finished;
  bool get isMyTurn => true; // Düello modunda her zaman sıra sizde
  bool get connectionLost => false;
  bool get opponentLeft => false;
  bool get hasUsedJoker => false;

  // Rakip tahminlerini gösterme durumu
  bool _isOpponentRevealed = false;
  bool get isOpponentRevealed => _isOpponentRevealed;

  // Harf jokeri kullanım sayacı
  int letterHintUsedCount = 0;
  final int maxLetterHint = 3;

  // first_guess jokeri için kullanım kontrolü
  bool _isFirstGuessJokerUsed = false;
  bool get isFirstGuessJokerUsed => _isFirstGuessJokerUsed;

  // letter_hint ve opponent_words jokerleri için disable kontrolü
  bool get isLetterHintJokerDisabled => letterHintUsedCount >= maxLetterHint;
  bool _isOpponentWordsJokerUsed = false;
  bool get isOpponentWordsJokerDisabled => _isOpponentWordsJokerUsed;

  // Oyuncu getters
  DuelPlayer? get currentPlayer {
    if (_currentGame == null || _currentPlayerId == null) return null;
    return _currentGame!.players
        .cast<DuelPlayer?>()
        .firstWhere((p) => p?.playerId == _currentPlayerId, orElse: () => null);
  }

  DuelPlayer? get opponentPlayer {
    if (_currentGame == null || _currentPlayerId == null) return null;
    return _currentGame!.players
        .cast<DuelPlayer?>()
        .firstWhere((p) => p?.playerId != _currentPlayerId, orElse: () => null);
  }

  int tokens = 0;

  /// Oyunu başlat
  Future<void> startGame(String gameId) async {
    try {
      _gameId = gameId;
      _currentPlayerId = FirebaseAuth.instance.currentUser?.uid;

      if (_currentPlayerId == null) {
        throw Exception('Kullanıcı girişi bulunamadı');
      }

      print('🎮 Oyun başlatılıyor:');
      print('  - GameId: $gameId');
      print('  - Current Player ID: $_currentPlayerId');

      // Kelime listesini yükle
      await _loadWordList();

      // Jeton bakiyesini güncelle
      tokens = await DuelService.getTokens();
      notifyListeners();

      _setupGameStream();
      _startTime = DateTime.now(); // Oyun başında zamanı başlat
      _endTime = null;
      print('✅ Düello oyunu başlatıldı: $gameId');
    } catch (e) {
      _errorMessage = 'Oyun başlatılamadı: $e';
      notifyListeners();
      print('❌ Oyun başlatma hatası: $e');
    }
  }

  /// Test oyunu başlat
  Future<void> startTestGame() async {
    try {
      _currentPlayerId = FirebaseAuth.instance.currentUser?.uid;

      if (_currentPlayerId == null) {
        throw Exception('Kullanıcı girişi bulunamadı');
      }

      // Kelime listesini yükle
      await _loadWordList();

      // Test oyunu oluştur
      final gameId =
          await DuelService.createTestGame(_currentPlayerId!, 'Test Player');

      await startGame(gameId);
      print('✅ Test oyunu başlatıldı: $gameId');
    } catch (e) {
      _errorMessage = 'Test oyunu başlatılamadı: $e';
      notifyListeners();
      print('❌ Test oyunu başlatma hatası: $e');
    }
  }

  /// Kelime listesini yükle
  Future<void> _loadWordList() async {
    try {
      final String response =
          await rootBundle.loadString('assets/kelimeler.json');
      final List<dynamic> jsonList = json.decode(response);
      _wordList =
          jsonList.map((e) => e.toString().toTurkishUpperCase()).toList();
      print('✅ ${_wordList.length} kelime yüklendi');
    } catch (e) {
      print('❌ Kelime listesi yükleme hatası: $e');
      // Fallback kelimeler
      _wordList = ['KALEM', 'KITAP', 'MASA', 'KAPI', 'PENCERE'];
    }
  }

  /// Oyun stream'ini dinle
  void _setupGameStream() {
    if (_gameId == null) return;

    _gameSubscription = DuelService.getDuelGameStream(_gameId!).listen(
      (game) {
        if (game != null) {
          _currentGame = game;
          // Gizli kelimeyi oyundan al
          if (_secretWord.isEmpty && game.secretWord.isNotEmpty) {
            _secretWord = game.secretWord;
            print('🎯 Oyundan gizli kelime alındı: $_secretWord');
          }

          // Debug: Oyun durumunu logla
          print('🎮 Oyun durumu güncellendi:');
          print('  - GameId: ${game.gameId}');
          print('  - Status: ${game.status}');
          print('  - Secret Word: ${game.secretWord}');
          print('  - Current Player ID: $_currentPlayerId');
          print(
              '  - Players in game: ${game.players.map((p) => '${p.playerName}(${p.playerId})').join(', ')}');

          _checkGameStatus();
          notifyListeners();
        }
      },
      onError: (error) {
        _errorMessage = 'Oyun dinleme hatası: $error';
        notifyListeners();
        print('❌ Oyun dinleme hatası: $error');
      },
    );
  }

  /// Oyun durumunu kontrol et
  void _checkGameStatus() {
    if (_currentGame == null) return;

    // Oyun bitti mi kontrol et
    if (_currentGame!.status == GameStatus.finished) {
      _endTime ??= DateTime.now(); // Oyun bitişinde zamanı kaydet

      // Matchmaking kuyruğundan çıkar
      _cleanupAfterGame();

      // Kazanma durumunu kontrol et - hem winnerId hem de player.isWinner
      final gameWinnerId = _currentGame!.winnerId;
      final currentPlayerData = currentPlayer;
      final isWinnerByGameId = gameWinnerId == _currentPlayerId;
      final isWinnerByPlayerData = currentPlayerData?.isWinner == true;

      print('🏆 Kazanma durumu kontrolü:');
      print('  - Game Winner ID: $gameWinnerId');
      print('  - Current Player ID: $_currentPlayerId');
      print('  - Is Winner by Game ID: $isWinnerByGameId');
      print('  - Is Winner by Player Data: $isWinnerByPlayerData');
      print('  - Current Player: ${currentPlayerData?.toMap()}');

      // Her iki kontrol de true olmalı
      final isWinner = isWinnerByGameId || isWinnerByPlayerData;

      if (isWinner) {
        _showWinAnimation = true;
        HapticService.triggerMediumHaptic();
        print('✅ KAZANDIN!');
      } else {
        _showLoseAnimation = true;
        HapticService.triggerErrorHaptic();
        print('❌ Kaybettin!');
      }
      notifyListeners();
    }
  }

  /// Oyun sonrası temizlik
  Future<void> _cleanupAfterGame() async {
    try {
      if (_currentPlayerId != null) {
        // Matchmaking kuyruğundan çıkar
        await DuelService.leaveMatchmakingQueue(_currentPlayerId!);
        // Aktif kullanıcı durumunu kapat
        await DuelService.setUserActiveInDuel(_currentPlayerId!, false);
      }
    } catch (e) {
      print('❌ Oyun sonrası temizlik hatası: $e');
    }
  }

  /// Oyun bitişi animasyonu
  void _showGameFinishedAnimation() {
    final isWinner = currentPlayer?.isWinner == true;

    if (isWinner) {
      _showWinAnimation = true;
      HapticService.triggerMediumHaptic();
    } else {
      _showLoseAnimation = true;
      HapticService.triggerErrorHaptic();
    }

    notifyListeners();
  }

  /// Harf ekle
  void addLetter(String letter) {
    print('🔤 addLetter çağrıldı: $letter, currentGuess: $_currentGuess');
    if (_currentGuess.length < 5 && !isGameFinished) {
      _currentGuess += letter;
      _currentLetters = _currentGuess.split('');
      _canSubmitGuess = _currentGuess.length == 5;
      print(
          '✅ Harf eklendi: $_currentGuess, letters: $_currentLetters, canSubmit: $_canSubmitGuess');
      notifyListeners();
    } else {
      print(
          '❌ Harf eklenemedi: length=${_currentGuess.length}, gameFinished: $isGameFinished');
    }
  }

  /// Harf sil
  void removeLetter() {
    if (_currentGuess.isNotEmpty) {
      _currentGuess = _currentGuess.substring(0, _currentGuess.length - 1);
      _currentLetters = _currentGuess.split('');
      _canSubmitGuess = _currentGuess.length == 5;
      notifyListeners();
    }
  }

  /// Tahmini gönder
  Future<void> submitGuess() async {
    print(
        '🚀 submitGuess çağrıldı: $_currentGuess, canSubmit: $_canSubmitGuess');
    if (!_canSubmitGuess || _gameId == null || _currentPlayerId == null) {
      print(
          '❌ Submit edilemedi: canSubmit=$_canSubmitGuess, gameId=$_gameId, playerId=$_currentPlayerId');
      return;
    }

    try {
      _isLoading = true;
      notifyListeners();

      final guess = _currentGuess.toTurkishUpperCase();
      print('📤 Tahmin gönderiliyor: $guess, secretWord: $_secretWord');

      // Wordle kontrolü - kelime listesinde var mı?
      if (guess.length != 5 || !_wordList.contains(guess)) {
        _showShakeAnimation = true;
        _errorMessage = 'Bu kelime sözlükte yok!';
        print('❌ Kelime sözlükte yok: $guess');
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Gerçek tahmin gönderimi
      final guessList = guess.split('').map((c) => c.toTurkishUpperCase()).toList();
      await DuelService.submitGuess(
          _gameId!, _currentPlayerId!, guessList);

      // Tahmini temizle
      _currentGuess = '';
      _currentLetters = [];
      _canSubmitGuess = false;

      print('✅ Tahmin gönderildi: $guess');
    } catch (e) {
      _showShakeAnimation = true;
      _errorMessage = 'Tahmin gönderilemedi: $e';
      print('❌ Tahmin gönderme hatası: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Shake animasyonunu sıfırla
  void resetShake() {
    _showShakeAnimation = false;
    notifyListeners();
  }

  /// Joker kullanımı
  Future<String?> useJoker(String jokerType) async {
    try {
      if (_gameId == null) return null;
      int tokenCost = 0;
      if (jokerType == 'letter_hint') tokenCost = 10;
      if (jokerType == 'opponent_words') tokenCost = 20;
      if (jokerType == 'first_guess') tokenCost = 8;
      // letter_hint için işlemleri pop-up'tan sonra başlat
      if (jokerType == 'letter_hint') {
        if (letterHintUsedCount >= maxLetterHint) {
          return null;
        }
        final revealed = _revealRandomLetterHint();
        if (revealed != null) {
          // Önce harfi hemen döndür
          letterHintUsedCount++;
          // Sonra işlemleri başlat (asenkron, beklemeden)
          Future(() async {
            tokens = await DuelService.getTokens();
            final success = await DuelService.decrementTokens(tokenCost);
            if (success) {
              await DuelService.useJoker(_gameId!, jokerType);
            }
            tokens = await DuelService.getTokens();
            notifyListeners();
          });
          notifyListeners(); // ANINDA UI güncelle
          return revealed;
        }
        return null;
      }
      // first_guess jokeri sadece bir kez kullanılabilir
      if (jokerType == 'first_guess') {
        if (_isFirstGuessJokerUsed) {
          return null;
        }
      }
      // opponent_words jokeri sadece bir kez kullanılabilir
      if (jokerType == 'opponent_words') {
        if (_isOpponentWordsJokerUsed) {
          return null;
        }
      }
      // Diğer jokerler için eski akış
      tokens = await DuelService.getTokens();
      notifyListeners();
      if (tokenCost > 0) {
        final success = await DuelService.decrementTokens(tokenCost);
        if (!success) {
          tokens = await DuelService.getTokens();
          notifyListeners();
          return null; // Yeterli jeton yok
        }
      }
      await DuelService.useJoker(_gameId!, jokerType);
      if (jokerType == 'opponent_words') {
        _isOpponentRevealed = true;
        _isOpponentWordsJokerUsed = true;
        tokens = await DuelService.getTokens();
        notifyListeners(); // ANINDA UI güncelle
        return null;
      }
      if (jokerType == 'first_guess') {
        _isFirstGuessJokerUsed = true;
        notifyListeners();
      }
      // Eğer first_guess için de anında bir state gerekiyorsa burada ekle
      tokens = await DuelService.getTokens();
      notifyListeners();
      HapticService.triggerMediumHaptic();
      print('✅ Joker kullanıldı: $jokerType');
      return null;
    } catch (e) {
      print('❌ Joker kullanma hatası: $e');
      return null;
    }
  }

  String? _revealRandomLetterHint() {
    if (_secretWord.isEmpty || _currentGuess.length >= 5) return null;
    final guessLetters = _currentGuess.split('');
    final secretLetters = _secretWord.split('');
    // Kullanıcıya henüz yazmadığı veya yanlış yazdığı harflerin indexlerini bul
    final List<int> availableIndexes = [];
    for (int i = 0; i < secretLetters.length; i++) {
      if (i >= guessLetters.length || guessLetters[i] != secretLetters[i]) {
        availableIndexes.add(i);
      }
    }
    if (availableIndexes.isEmpty) return null;
    final randomIndex = availableIndexes[Random().nextInt(availableIndexes.length)];
    // currentGuess veya currentLetters'a MÜDAHALE ETME!
    return secretLetters[randomIndex];
  }

  /// Oyunu terk et
  Future<void> leaveGame() async {
    try {
      if (_gameId != null) {
        await DuelService.leaveGameNew(_gameId!);
      }
      await _cleanup();
    } catch (e) {
      print('❌ Oyun terk etme hatası: $e');
    }
  }

  // Helper metodlar
  List<String> get correctGuesses => [];
  int get currentAttempt => currentPlayer?.guesses.length ?? 0;
  int get maxAttempts => 6;
  String get secretWord => _secretWord;

  bool _isCleaned = false;

  /// Temizlik
  Future<void> _cleanup() async {
    if (_isCleaned) return;
    _isCleaned = true;
    try {
      _gameSubscription?.cancel();

      // Matchmaking kuyruğundan çıkar
      if (_currentPlayerId != null) {
        await DuelService.leaveMatchmakingQueue(_currentPlayerId!);
        await DuelService.setUserActiveInDuel(_currentPlayerId!, false);
      }

      // Değişkenleri sıfırla
      _currentGame = null;
      _gameId = null;
      _currentPlayerId = null;
      _currentGuess = '';
      _currentLetters = [];
      _isLoading = false;
      _errorMessage = null;
      _secretWord = '';
      _isOpponentRevealed = false;
      letterHintUsedCount = 0;
      _showShakeAnimation = false;
      _showWinAnimation = false;
      _showLoseAnimation = false;
      _startTime = null;
      _endTime = null;
      _isFirstGuessJokerUsed = false;
      _isOpponentWordsJokerUsed = false;
    } catch (e) {
      print('❌ Temizlik hatası: $e');
    }
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}
