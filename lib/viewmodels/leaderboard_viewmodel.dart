import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/leaderboard.dart';
import '../services/firebase_service.dart';
import '../services/avatar_service.dart';
import 'dart:math' as math;

class LeaderboardViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<LeaderboardStats> _leaderboard = [];
  LeaderboardStats? _currentUserStats;
  LeaderboardType _currentType = LeaderboardType.totalScore;
  bool _isLoading = false;
  String? _error;

  List<LeaderboardStats> get leaderboard => _leaderboard;
  LeaderboardStats? get currentUserStats => _currentUserStats;
  LeaderboardType get currentType => _currentType;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadLeaderboard({LeaderboardType? type}) async {
    if (type != null) {
      _currentType = type;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      String orderBy;
      bool descending = true;

      switch (_currentType) {
        case LeaderboardType.totalScore:
          orderBy = 'totalScore';
          break;
        case LeaderboardType.winRate:
          orderBy = 'gamesWon';
          break;
        case LeaderboardType.averageAttempts:
          orderBy = 'totalAttempts';
          descending = false;
          break;
      }

      final querySnapshot = await _firestore
          .collection('leaderboard_stats')
          .orderBy(orderBy, descending: descending)
          .limit(100)
          .get();

      _leaderboard = querySnapshot.docs
          .map((doc) => LeaderboardStats.fromFirestore(doc.data()))
          .toList();

      // Win rate için özel sıralama
      if (_currentType == LeaderboardType.winRate) {
        _leaderboard.sort((a, b) {
          if (a.gamesPlayed == 0 && b.gamesPlayed == 0) return 0;
          if (a.gamesPlayed == 0) return 1;
          if (b.gamesPlayed == 0) return -1;
          return b.winRate.compareTo(a.winRate);
        });
      }

      // Average attempts için özel sıralama
      if (_currentType == LeaderboardType.averageAttempts) {
        _leaderboard.sort((a, b) {
          if (a.gamesPlayed == 0 && b.gamesPlayed == 0) return 0;
          if (a.gamesPlayed == 0) return 1;
          if (b.gamesPlayed == 0) return -1;
          return a.averageAttempts.compareTo(b.averageAttempts);
        });
      }

      // Mevcut kullanıcının istatistiklerini yükle
      await _loadCurrentUserStats();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Başarı tablosu yüklenirken hata oluştu: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCurrentUserStats() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore
          .collection('leaderboard_stats')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        _currentUserStats = LeaderboardStats.fromFirestore(doc.data()!);
      }
    } catch (e) {
      print('Kullanıcı istatistikleri yüklenirken hata: $e');
    }
  }

  Future<void> updateUserStats({
    required bool gameWon,
    required int attempts,
    required int timeSpent,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userProfile = await FirebaseService.getUserProfile(user.uid);
      final playerName = userProfile?['displayName'] ?? 'Anonim Oyuncu';

      final docRef = _firestore.collection('leaderboard_stats').doc(user.uid);
      
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        
        if (doc.exists) {
          final currentStats = LeaderboardStats.fromFirestore(doc.data()!);
          
          final updatedStats = LeaderboardStats(
            playerId: user.uid,
            playerName: playerName,
            avatar: currentStats.avatar,
            totalScore: currentStats.totalScore + _calculateScore(gameWon, attempts, timeSpent),
            gamesPlayed: currentStats.gamesPlayed + 1,
            gamesWon: currentStats.gamesWon + (gameWon ? 1 : 0),
            totalAttempts: currentStats.totalAttempts + attempts,
            lastPlayedAt: DateTime.now(),
            createdAt: currentStats.createdAt,
          );
          
          transaction.set(docRef, updatedStats.toFirestore());
        } else {
          // Yeni kullanıcı için avatar oluştur
          final userAvatar = await FirebaseService.getUserAvatar(user.uid) ?? AvatarService.generateAvatar(user.uid);
          
          final newStats = LeaderboardStats(
            playerId: user.uid,
            playerName: playerName,
            avatar: userAvatar,
            totalScore: _calculateScore(gameWon, attempts, timeSpent),
            gamesPlayed: 1,
            gamesWon: gameWon ? 1 : 0,
            totalAttempts: attempts,
            lastPlayedAt: DateTime.now(),
            createdAt: DateTime.now(),
          );
          
          transaction.set(docRef, newStats.toFirestore());
        }
      });

      // Güncel istatistikleri yeniden yükle
      await _loadCurrentUserStats();
      notifyListeners();
    } catch (e) {
      print('Kullanıcı istatistikleri güncellenirken hata: $e');
    }
  }

  int _calculateScore(bool gameWon, int attempts, int timeSpent) {
    if (!gameWon) return 0;
    
    // Temel puan: 100
    int baseScore = 100;
    
    // Deneme bonusu (az denemeyle çözerse daha çok puan)
    int attemptBonus = (7 - attempts) * 10;
    
    // Zaman bonusu (hızlı çözerse daha çok puan)
    int timeBonus = math.max(0, (150 - timeSpent) ~/ 10);
    
    return baseScore + attemptBonus + timeBonus;
  }

  String getTypeDisplayName(LeaderboardType type) {
    switch (type) {
      case LeaderboardType.totalScore:
        return 'Toplam Puan';
      case LeaderboardType.winRate:
        return 'Kazanma Oranı';
      case LeaderboardType.averageAttempts:
        return 'Ortalama Deneme';
    }
  }

  String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String formatWinRate(double winRate) {
    return '${winRate.toStringAsFixed(1)}%';
  }

  int getCurrentUserRank() {
    if (_currentUserStats == null) return -1;
    
    for (int i = 0; i < _leaderboard.length; i++) {
      if (_leaderboard[i].playerId == _currentUserStats!.playerId) {
        return i + 1;
      }
    }
    
    return -1;
  }
} 