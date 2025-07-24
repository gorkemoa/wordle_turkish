import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/matchmaking_entry.dart';
import '../services/duel_service.dart';

class MatchmakingViewModel extends ChangeNotifier {
  // Matchmaking durumu
  bool _isLoading = false;
  bool _isMatched = false;
  bool _isExpired = false;
  bool _isCancelled = false;
  String? _errorMessage;
  String? _gameId;
  
  // Zamanlayıcı ve süreç
  Timer? _waitTimer;
  int _waitTime = 0;
  final int _maxWaitTimeSeconds = 300; // 5 dakika
  
  // Stream subscription
  StreamSubscription? _matchmakingSubscription;

  // Getters
  bool get isLoading => _isLoading;
  bool get isMatched => _isMatched;
  bool get isExpired => _isExpired;
  bool get isCancelled => _isCancelled;
  bool get isSearching => _isLoading && !_isMatched && !_isExpired && !_isCancelled;
  bool get hasError => _errorMessage != null;
  String? get errorMessage => _errorMessage;
  String? get gameId => _gameId;
  
  // UI için ek getter'lar
  int get searchProgress => ((_waitTime / _maxWaitTimeSeconds) * 100).round();
  int get estimatedWaitTime => _maxWaitTimeSeconds - _waitTime;
  int get waitingPlayersCount => 5; // Demo değer
  int get averageMatchTime => 15; // Demo değer

  /// Matchmaking başlat
  Future<void> startMatchmaking() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _errorMessage = 'Kullanıcı giriş yapmamış';
        notifyListeners();
        return;
      }

      _clearState();
      _isLoading = true;
      notifyListeners();

      // DuelService'ten matchmaking kuyruğuna katıl
      await DuelService.joinMatchmakingQueue(
        user.uid,
        user.displayName ?? 'Oyuncu'
      );

      // Matchmaking durumunu dinle
      _listenForMatchmaking(user.uid);

      _startWaitTimer();
      
      print('✅ Matchmaking başlatıldı');
    } catch (e) {
      _errorMessage = 'Matchmaking hatası: $e';
      _isLoading = false;
      notifyListeners();
      print('❌ Matchmaking hatası: $e');
    }
  }

  /// Matchmaking iptal et
  Future<void> cancelMatchmaking() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await DuelService.leaveMatchmakingQueue(user.uid);
      }
      
      _stopWaitTimer();
      _isCancelled = true;
      _isLoading = false;
      notifyListeners();
      
      print('✅ Matchmaking iptal edildi');
    } catch (e) {
      _errorMessage = 'İptal hatası: $e';
      notifyListeners();
      print('❌ Matchmaking iptal hatası: $e');
    }
  }

  /// Durumu sıfırla
  void reset() {
    _stopWaitTimer();
    _clearState();
    notifyListeners();
  }

  /// Bekleme zamanlayıcısını başlat
  void _startWaitTimer() {
    _waitTime = 0;
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _waitTime++;
      
      // Maksimum süre aşıldı
      if (_waitTime >= _maxWaitTimeSeconds) {
        _isExpired = true;
        _isLoading = false;
        _stopWaitTimer();
      }
      
      notifyListeners();
    });
    
    print('⏱️ Bekleme zamanlayıcısı başlatıldı');
  }

  /// Bekleme zamanlayıcısını durdur
  void _stopWaitTimer() {
    _waitTimer?.cancel();
    _waitTimer = null;
  }

  /// Matchmaking durumunu dinle
  void _listenForMatchmaking(String userId) {
    _matchmakingSubscription?.cancel();
    
    _matchmakingSubscription = DuelService.getMatchmakingEntryStream(userId).listen(
      (entry) {
        if (entry != null) {
          if (entry.status == MatchmakingStatus.matched && entry.gameId != null) {
            _gameId = entry.gameId;
            _isMatched = true;
            _isLoading = false;
            _stopWaitTimer();
            notifyListeners();
            print('🎯 Eşleştirme bulundu! Oyun ID: $_gameId');
          } else if (entry.status == MatchmakingStatus.expired) {
            _isExpired = true;
            _isLoading = false;
            _stopWaitTimer();
            notifyListeners();
            print('⏰ Matchmaking süresi doldu');
          } else if (entry.status == MatchmakingStatus.cancelled) {
            _isCancelled = true;
            _isLoading = false;
            _stopWaitTimer();
            notifyListeners();
            print('❌ Matchmaking iptal edildi');
          }
        }
      },
      onError: (error) {
        _errorMessage = 'Matchmaking dinleme hatası: $error';
        notifyListeners();
        print('❌ Matchmaking dinleme hatası: $error');
      },
    );
  }

  /// Matchmaking durumunu dinle (eski API uyumluluğu için)
  Stream<bool> listenForMatch() async* {
    // Bu metod eski API uyumluluğu için basitleştirildi
    // Gerçek implementasyon için DuelService.getDuelGameStream kullanın
    yield false;
  }

  /// Test modu başlat
  Future<void> startTestMode() async {
    try {
      print('🤖 Test modu başlatılıyor...');
      _clearState();
      _isLoading = true;
      notifyListeners();

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Kullanıcı girişi bulunamadı');

      // Test için kısa bekleme
      await Future.delayed(const Duration(seconds: 2));

      // Test oyun ID'si oluştur
      _gameId = await DuelService.createTestGame(
        user.uid,
        user.displayName ?? 'Test Oyuncusu'
      );
      
      _isMatched = true;
      _isLoading = false;
      
      notifyListeners();
      print('✅ Test modu hazır: $_gameId');
    } catch (e) {
      _errorMessage = 'Test modu başlatılamadı: $e';
      _isLoading = false;
      notifyListeners();
      print('❌ Test modu hatası: $e');
    }
  }

  /// İstatistikleri güncelle
  Future<void> updateStats() async {
    try {
      final stats = await DuelService.getMatchmakingStats();
      // İstatistikleri güncelle (UI için kullanılabilir)
      print('📊 İstatistikler güncellendi: $stats');
    } catch (e) {
      print('❌ İstatistik güncelleme hatası: $e');
    }
  }

  /// Durumu temizle
  void _clearState() {
    _isLoading = false;
    _isMatched = false;
    _isExpired = false;
    _isCancelled = false;
    _errorMessage = null;
    _gameId = null;
    _waitTime = 0;
  }

  @override
  void dispose() {
    _stopWaitTimer();
    _matchmakingSubscription?.cancel();
    super.dispose();
  }
} 