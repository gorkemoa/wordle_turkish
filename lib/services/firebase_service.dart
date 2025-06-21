import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:uuid/uuid.dart';
import '../models/duel_game.dart';
import 'package:flutter/services.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();
  static final Uuid _uuid = const Uuid();

  // Email ve şifre ile kayıt ol
  static Future<User?> signUpWithEmailPassword(String email, String password, String displayName) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Kullanıcı profilini güncelle
      await result.user?.updateDisplayName(displayName);
      
      // Firestore'da kullanıcı verilerini sakla
      if (result.user != null) {
        await _saveUserProfile(result.user!, displayName, email);
      }
      
      return result.user;
    } on FirebaseAuthException catch (e) {
      print('Kayıt hatası: ${e.message}');
      return null;
    } catch (e) {
      print('Kayıt hatası: $e');
      return null;
    }
  }

  // Email ve şifre ile giriş yap
  static Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      print('Giriş hatası: ${e.message}');
      return null;
    } catch (e) {
      print('Giriş hatası: $e');
      return null;
    }
  }

  // Google ile giriş yap
  static Future<User?> signInWithGoogle() async {
    try {
      // Google Sign-In paketinin mevcut olduğunu kontrol et
      if (!await _googleSignIn.isSignedIn()) {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          print('Google giriş iptal edildi');
          return null;
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final UserCredential result = await _auth.signInWithCredential(credential);
        
        // İlk kez giriş yapıyorsa kullanıcı verilerini sakla
        if (result.additionalUserInfo?.isNewUser == true && result.user != null) {
          await _saveUserProfile(
            result.user!, 
            result.user!.displayName ?? 'Google Kullanıcısı',
            result.user!.email ?? '',
          );
        }
        
        return result.user;
      } else {
        // Zaten giriş yapmış
        final GoogleSignInAccount? googleUser = _googleSignIn.currentUser;
        if (googleUser != null) {
          final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
          
          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );

          final UserCredential result = await _auth.signInWithCredential(credential);
          return result.user;
        }
      }
      return null;
    } on PlatformException catch (e) {
      print('Google giriş platform hatası: ${e.message}');
      return null;
    } catch (e) {
      print('Google giriş hatası: $e');
      return null;
    }
  }

  // Anonymous olarak giriş yap
  static Future<User?> signInAnonymously() async {
    try {
      final UserCredential result = await _auth.signInAnonymously();
      
      // Anonymous kullanıcı için rastgele isim oluştur
      if (result.user != null) {
        final randomName = generatePlayerName();
        await _saveUserProfile(result.user!, randomName, '');
      }
      
      return result.user;
    } catch (e) {
      print('Anonim giriş hatası: $e');
      return null;
    }
  }

  // Kullanıcı profil bilgilerini Firestore'a kaydet
  static Future<void> _saveUserProfile(User user, String displayName, String email) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'displayName': displayName,
        'email': email,
        'photoURL': user.photoURL,
        'isAnonymous': user.isAnonymous,
        'createdAt': FieldValue.serverTimestamp(),
        'lastActiveAt': FieldValue.serverTimestamp(),
        'gamesPlayed': 0,
        'gamesWon': 0,
      }, SetOptions(merge: true));

      // Kullanıcı istatistiklerini ve günlük görevlerini başlat
      await initializeUserStats(user.uid);
      await initializeDailyTasks(user.uid);
    } catch (e) {
      print('Kullanıcı profil kaydetme hatası: $e');
    }
  }

  // Kullanıcı profil bilgilerini al
  static Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      print('Kullanıcı profil alma hatası: $e');
      return null;
    }
  }

  // Çıkış yap
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print('Çıkış hatası: $e');
    }
  }

  // Şifre sıfırlama e-postası gönder
  static Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      print('Şifre sıfırlama hatası: $e');
      return false;
    }
  }

  // Mevcut kullanıcıyı al
  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Kullanıcı giriş durumunu dinle
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Oyuncu için rastgele isim oluştur
  static String generatePlayerName() {
    final adjectives = ['Hızlı', 'Zeki', 'Güçlü', 'Cesur', 'Akıllı', 'Usta', 'Şanslı', 'Parlak'];
    final nouns = ['Aslan', 'Kartal', 'Ejder', 'Kaplan', 'Kurt', 'Şahin', 'Panter', 'Akrep'];
    
    final random = Random();
    final adjective = adjectives[random.nextInt(adjectives.length)];
    final noun = nouns[random.nextInt(nouns.length)];
    final number = random.nextInt(100);
    
    return '$adjective$noun$number';
  }

  // Yeni oyun odası oluştur veya mevcut odaya katıl
  static Future<String?> findOrCreateGame(String playerName, String secretWord) async {
    try {
      print('Firebase oyun oluşturma başlatılıyor...');
      final user = getCurrentUser();
      if (user == null) {
        print('Kullanıcı null!');
        return null;
      }
      print('Kullanıcı ID: ${user.uid}');

      // Bekleyen oyun ara
      print('Bekleyen oyunlar aranıyor...');
      final waitingGames = await _firestore
          .collection('duel_games')
          .where('status', isEqualTo: 'waiting')
          .limit(10)
          .get();

      print('Bulunan bekleyen oyun sayısı: ${waitingGames.docs.length}');

      // Uygun oyun ara (1 oyunculu)
      DocumentSnapshot? availableGame;
      for (final doc in waitingGames.docs) {
        final game = DuelGame.fromFirestore(doc);
        if (game.players.length == 1) {
          availableGame = doc;
          break;
        }
      }

      if (availableGame != null) {
        // Mevcut oyuna katıl
        final gameId = availableGame.id;
        print('Mevcut oyuna katılıyor: $gameId');

        final player = DuelPlayer(
          playerId: user.uid,
          playerName: playerName,
          status: PlayerStatus.waiting, // Katıldığında bekleme durumunda
          guesses: List.generate(6, (_) => List.filled(5, '_')),
          guessColors: List.generate(6, (_) => List.filled(5, 'empty')),
          currentAttempt: 0,
          score: 0,
        );

        await _firestore.collection('duel_games').doc(gameId).update({
          'players.${user.uid}': player.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print('Mevcut oyuna başarıyla katıldı');
        return gameId;
      } else {
        // Yeni oyun oluştur
        final gameId = _uuid.v4();
        print('Yeni oyun oluşturuluyor: $gameId');

        final player = DuelPlayer(
          playerId: user.uid,
          playerName: playerName,
          status: PlayerStatus.waiting,
          guesses: List.generate(6, (_) => List.filled(5, '_')),
          guessColors: List.generate(6, (_) => List.filled(5, 'empty')),
          currentAttempt: 0,
          score: 0,
        );

        final gameData = DuelGame(
          gameId: gameId,
          secretWord: secretWord,
          status: GameStatus.waiting,
          createdAt: DateTime.now(),
          players: {
            user.uid: player,
          },
        );

        final gameMap = gameData.toFirestore();
        gameMap['updatedAt'] = FieldValue.serverTimestamp();

        await _firestore.collection('duel_games').doc(gameId).set(gameMap);
        print('Yeni oyun başarıyla oluşturuldu');
        
        return gameId;
      }
    } catch (e, s) {
      print('Oyun oluşturma hatası: $e');
      print('Stack Trace: $s');
      return null;
    }
  }

  // Oyun durumunu dinle
  static Stream<DuelGame?> listenToGame(String gameId) {
    return _firestore
        .collection('duel_games')
        .doc(gameId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return DuelGame.fromFirestore(doc);
      }
      return null;
    });
  }

  // Tahmin yap
  static Future<bool> makeGuess(String gameId, List<String> guess, List<String> guessColors) async {
    try {
      final user = getCurrentUser();
      if (user == null) return false;

      final gameDoc = await _firestore.collection('duel_games').doc(gameId).get();
      if (!gameDoc.exists) return false;

      final game = DuelGame.fromFirestore(gameDoc);
      final player = game.players[user.uid];
      if (player == null) return false;

      // Player'ın tahminlerini güncelle
      final updatedGuesses = List<List<String>>.from(player.guesses);
      final updatedGuessColors = List<List<String>>.from(player.guessColors);
      
      updatedGuesses[player.currentAttempt] = guess;
      updatedGuessColors[player.currentAttempt] = guessColors;

      // Kazanma durumunu kontrol et
      final isWinner = guess.join('').toUpperCase() == game.secretWord.toUpperCase();
      final newStatus = isWinner ? PlayerStatus.won : PlayerStatus.playing;
      final newAttempt = isWinner ? player.currentAttempt : player.currentAttempt + 1;

      await _firestore.collection('duel_games').doc(gameId).update({
        'players.${user.uid}.guesses': jsonEncode(updatedGuesses),
        'players.${user.uid}.guessColors': jsonEncode(updatedGuessColors),
        'players.${user.uid}.currentAttempt': newAttempt,
        'players.${user.uid}.status': newStatus.name,
        if (isWinner) 'players.${user.uid}.finishedAt': FieldValue.serverTimestamp(),
        if (isWinner) 'winnerId': user.uid,
        if (isWinner) 'status': 'finished',
        if (isWinner) 'finishedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Tahmin yapma hatası: $e');
      return false;
    }
  }

  // Oyunu terk et
  static Future<void> leaveGame(String gameId) async {
    try {
      final user = getCurrentUser();
      if (user == null) return;

      await _firestore.collection('duel_games').doc(gameId).update({
        'players.${user.uid}.status': PlayerStatus.disconnected.name,
      });
    } catch (e) {
      print('Oyun terk etme hatası: $e');
    }
  }

  // Oyunu sil (temizlik)
  static Future<void> deleteGame(String gameId) async {
    try {
      await _firestore.collection('duel_games').doc(gameId).delete();
    } catch (e) {
      print('Oyun silme hatası: $e');
    }
  }

  // Oyuncunun hazır durumunu ayarla
  static Future<void> setPlayerReady(String gameId) async {
    try {
      final user = getCurrentUser();
      if (user == null) return;

      await _firestore.collection('duel_games').doc(gameId).update({
        'players.${user.uid}.status': PlayerStatus.ready.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Her iki oyuncu da hazır mı kontrol et
      final gameDoc = await _firestore.collection('duel_games').doc(gameId).get();
      if (gameDoc.exists) {
        final game = DuelGame.fromFirestore(gameDoc);
        
        if (game.players.length == 2) {
          final allReady = game.players.values.every(
            (player) => player.status == PlayerStatus.ready
          );
          
          if (allReady) {
            // Oyunu başlat
            await startGame(gameId);
          }
        }
      }
    } catch (e) {
      print('Oyuncu hazır durumu ayarlama hatası: $e');
    }
  }

  // Oyunu başlat
  static Future<void> startGame(String gameId) async {
    try {
      print('Oyun başlatılıyor: $gameId');
      
      // Tüm oyuncuların durumunu 'playing' yap ve oyunu aktif et
      final batch = _firestore.batch();
      final gameRef = _firestore.collection('duel_games').doc(gameId);
      
      // Oyun durumunu güncelle
      batch.update(gameRef, {
        'status': GameStatus.active.name,
        'startedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Oyuncuların durumunu güncelle
      final gameDoc = await gameRef.get();
      if (gameDoc.exists) {
        final game = DuelGame.fromFirestore(gameDoc);
        
        for (final playerId in game.players.keys) {
          batch.update(gameRef, {
            'players.$playerId.status': PlayerStatus.playing.name,
          });
        }
      }
      
      await batch.commit();
      print('Oyun başarıyla başlatıldı: $gameId');
    } catch (e) {
      print('Oyun başlatma hatası: $e');
    }
  }

  // ============= HOME PAGE DYNAMIC DATA METHODS =============

  // Kullanıcı istatistiklerini başlat (ilk kez giriş yapan kullanıcılar için)
  static Future<void> initializeUserStats(String uid) async {
    try {
      final userDoc = await _firestore.collection('user_stats').doc(uid).get();
      
      if (!userDoc.exists) {
        await _firestore.collection('user_stats').doc(uid).set({
          'uid': uid,
          'level': 1,
          'tokens': 100,
          'points': 150,
          'streak': 1,
          'gamesPlayed': 0,
          'gamesWon': 0,
          'winRate': 0.0,
          'bestScore': 0,
          'totalPlayTime': 0,
          'lastGameDate': FieldValue.serverTimestamp(),
          'streakStartDate': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Kullanıcı istatistikleri başlatma hatası: $e');
    }
  }

  // Kullanıcı istatistiklerini al
  static Future<Map<String, dynamic>?> getUserStats(String uid) async {
    try {
      final doc = await _firestore.collection('user_stats').doc(uid).get();
      return doc.data();
    } catch (e) {
      print('Kullanıcı istatistikleri alma hatası: $e');
      return null;
    }
  }

  // Kullanıcı istatistiklerini güncelle
  static Future<void> updateUserStats(String uid, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('user_stats').doc(uid).update(updates);
    } catch (e) {
      print('Kullanıcı istatistikleri güncelleme hatası: $e');
    }
  }

  // Günlük görevleri başlat (her gün yenilenir)
  static Future<void> initializeDailyTasks(String uid) async {
    try {
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      final taskDoc = await _firestore.collection('daily_tasks').doc('$uid-$todayStr').get();
      
      if (!taskDoc.exists) {
        await _firestore.collection('daily_tasks').doc('$uid-$todayStr').set({
          'uid': uid,
          'date': todayStr,
          'tasks': [
            {
              'id': 'find_words',
              'title': '5 kelime bul',
              'description': 'Herhangi bir oyun modunda 5 kelime bul',
              'reward': '50 puan',
              'rewardType': 'points',
              'rewardAmount': 50,
              'current': 0,
              'target': 5,
              'completed': false,
              'type': 'word_count',
            },
            {
              'id': 'score_challenge',
              'title': '3 dakikada 100 puan kazan',
              'description': 'Tek oyunda 3 dakika içinde 100 puan kazan',
              'reward': '20 jeton',
              'rewardType': 'tokens',
              'rewardAmount': 20,
              'current': 0,
              'target': 100,
              'completed': false,
              'type': 'score_in_time',
            },
            {
              'id': 'win_duel',
              'title': 'Bir duello kazan',
              'description': 'Duello modunda bir oyunu kazan',
              'reward': '30 jeton',
              'rewardType': 'tokens',
              'rewardAmount': 30,
              'current': 0,
              'target': 1,
              'completed': false,
              'type': 'duel_win',
            },
          ],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Günlük görevler başlatma hatası: $e');
    }
  }

  // Günlük görevleri al
  static Future<Map<String, dynamic>?> getDailyTasks(String uid) async {
    try {
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      final doc = await _firestore.collection('daily_tasks').doc('$uid-$todayStr').get();
      return doc.data();
    } catch (e) {
      print('Günlük görevler alma hatası: $e');
      return null;
    }
  }

  // Günlük görev ilerlemesini güncelle
  static Future<void> updateTaskProgress(String uid, String taskId, int progress) async {
    try {
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      final taskDocId = '$uid-$todayStr';
      final taskDoc = await _firestore.collection('daily_tasks').doc(taskDocId).get();
      
      if (taskDoc.exists) {
        final data = taskDoc.data()!;
        final tasks = List<Map<String, dynamic>>.from(data['tasks']);
        
        final taskIndex = tasks.indexWhere((task) => task['id'] == taskId);
        if (taskIndex != -1) {
          tasks[taskIndex]['current'] = progress;
          
          // Hedef tamamlandı mı kontrol et
          if (progress >= tasks[taskIndex]['target'] && !tasks[taskIndex]['completed']) {
            tasks[taskIndex]['completed'] = true;
            
            // Ödülü kullanıcıya ver
            final rewardType = tasks[taskIndex]['rewardType'];
            final rewardAmount = tasks[taskIndex]['rewardAmount'];
            
            if (rewardType == 'points') {
              await updateUserStats(uid, {'points': FieldValue.increment(rewardAmount)});
            } else if (rewardType == 'tokens') {
              await updateUserStats(uid, {'tokens': FieldValue.increment(rewardAmount)});
            }
          }
          
          await _firestore.collection('daily_tasks').doc(taskDocId).update({
            'tasks': tasks,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('Görev ilerleme güncelleme hatası: $e');
    }
  }

  // Son oyunları al
  static Future<List<Map<String, dynamic>>> getRecentGames(String uid, {int limit = 10}) async {
    try {
      final query = await _firestore
          .collection('game_history')
          .where('playerId', isEqualTo: uid)
          .orderBy('finishedAt', descending: true)
          .limit(limit)
          .get();
      
      return query.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('Son oyunlar alma hatası: $e');
      return [];
    }
  }

  // Oyun geçmişine kayıt ekle
  static Future<void> addGameToHistory(String uid, Map<String, dynamic> gameData) async {
    try {
      gameData['playerId'] = uid;
      gameData['finishedAt'] = FieldValue.serverTimestamp();
      
      await _firestore.collection('game_history').add(gameData);
    } catch (e) {
      print('Oyun geçmişi ekleme hatası: $e');
    }
  }

  // Arkadaş aktivitelerini al
  static Future<List<Map<String, dynamic>>> getFriendActivities(String uid, {int limit = 10}) async {
    try {
      final query = await _firestore
          .collection('friend_activities')
          .where('targetUserId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      
      return query.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('Arkadaş aktiviteleri alma hatası: $e');
      return [];
    }
  }

  // Arkadaş aktivitesi ekle
  static Future<void> addFriendActivity(String fromUserId, String toUserId, String activityType, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('friend_activities').add({
        'fromUserId': fromUserId,
        'targetUserId': toUserId,
        'activityType': activityType,
        'data': data,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Arkadaş aktivitesi ekleme hatası: $e');
    }
  }

  // Bildirimleri al
  static Future<List<Map<String, dynamic>>> getNotifications(String uid, {int limit = 20}) async {
    try {
      final query = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      
      return query.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('Bildirimler alma hatası: $e');
      return [];
    }
  }

  // Okunmamış bildirim sayısını al
  static Future<int> getUnreadNotificationCount(String uid) async {
    try {
      final query = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .where('read', isEqualTo: false)
          .get();
      
      return query.docs.length;
    } catch (e) {
      print('Okunmamış bildirim sayısı alma hatası: $e');
      return 0;
    }
  }

  // Bildirimi okundu olarak işaretle
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Bildirim okundu işaretleme hatası: $e');
    }
  }

  // ============= ADDITIONAL HELPER METHODS =============

  // Mevcut kullanıcılar için verileri başlat (upgrade için)
  static Future<void> initializeUserDataIfNeeded(String uid) async {
    try {
      // İstatistikler var mı kontrol et
      final statsExists = await _firestore.collection('user_stats').doc(uid).get();
      if (!statsExists.exists) {
        await initializeUserStats(uid);
      }

      // Günlük görevler var mı kontrol et
      final tasksData = await getDailyTasks(uid);
      if (tasksData == null) {
        await initializeDailyTasks(uid);
      }
    } catch (e) {
      print('Kullanıcı verilerini başlatma hatası: $e');
    }
  }

  // Oyun sonucunu kaydet (Wordle, Duello vs.)
  static Future<void> saveGameResult({
    required String uid,
    required String gameType,
    required int score,
    required bool isWon,
    required Duration duration,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Oyun geçmişine ekle
      await addGameToHistory(uid, {
        'gameType': gameType,
        'score': score,
        'isWon': isWon,
        'duration': '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
        'durationSeconds': duration.inSeconds,
        ...?additionalData,
      });

      // Kullanıcı istatistiklerini güncelle
      final updates = <String, dynamic>{
        'gamesPlayed': FieldValue.increment(1),
        'totalPlayTime': FieldValue.increment(duration.inSeconds),
      };

      if (isWon) {
        updates['gamesWon'] = FieldValue.increment(1);
        updates['lastGameDate'] = FieldValue.serverTimestamp();
        
        // Seri kontrolü (son oyun 24 saat içinde mi?)
        final userStats = await getUserStats(uid);
        if (userStats != null) {
          final lastGameDate = userStats['lastGameDate'];
          final now = DateTime.now();
          
          if (lastGameDate != null) {
            DateTime lastDate;
            if (lastGameDate is DateTime) {
              lastDate = lastGameDate;
            } else if (lastGameDate is Timestamp) {
              lastDate = lastGameDate.toDate();
            } else {
              // İlk oyun
              updates['streak'] = 1;
              updates['streakStartDate'] = FieldValue.serverTimestamp();
              return;
            }
            
            final difference = now.difference(lastDate).inHours;
            if (difference <= 24) {
              // Seriyi devam ettir
              updates['streak'] = FieldValue.increment(1);
            } else {
              // Seri kırıldı, yeniden başla
              updates['streak'] = 1;
              updates['streakStartDate'] = FieldValue.serverTimestamp();
            }
          } else {
            // İlk oyun
            updates['streak'] = 1;
            updates['streakStartDate'] = FieldValue.serverTimestamp();
          }
        }
      }

      // En iyi skoru güncelle
      final currentStats = await getUserStats(uid);
      if (currentStats != null) {
        final bestScore = currentStats['bestScore'] ?? 0;
        if (score > bestScore) {
          updates['bestScore'] = score;
          
          // Arkadaşlara bildirim gönder (gelecekte implementasyon için)
          // await notifyFriendsAboutNewRecord(uid, score);
        }
      }

      await updateUserStats(uid, updates);

      // Görev ilerlemelerini güncelle
      await _updateTaskProgressBasedOnGame(uid, gameType, score, isWon, duration);

    } catch (e) {
      print('Oyun sonucu kaydetme hatası: $e');
    }
  }

  // Oyun sonucuna göre görev ilerlemelerini güncelle
  static Future<void> _updateTaskProgressBasedOnGame(
    String uid,
    String gameType,
    int score,
    bool isWon,
    Duration duration,
  ) async {
    try {
      final dailyTasks = await getDailyTasks(uid);
      if (dailyTasks == null) return;

      final tasks = List<Map<String, dynamic>>.from(dailyTasks['tasks']);
      
      for (final task in tasks) {
        if (task['completed'] == true) continue;

        final taskType = task['type'];
        final current = task['current'] ?? 0;
        
        switch (taskType) {
          case 'word_count':
            // Her oyun için 1 kelime say (basitleştirilmiş)
            if (isWon) {
              await updateTaskProgress(uid, task['id'], current + 1);
            }
            break;
            
          case 'score_in_time':
            // 3 dakika içinde 100+ puan
            if (score >= 100 && duration.inMinutes <= 3) {
              await updateTaskProgress(uid, task['id'], score);
            }
            break;
            
          case 'duel_win':
            // Duello kazanma
            if (gameType == 'Duello' && isWon) {
              await updateTaskProgress(uid, task['id'], current + 1);
            }
            break;
        }
      }
    } catch (e) {
      print('Görev ilerlemesi güncelleme hatası: $e');
    }
  }

  // Seviye hesaplama sistemi
  static int calculateLevel(int totalPoints) {
    // Her 500 puan = 1 seviye
    return (totalPoints / 500).floor() + 1;
  }

  // Kullanıcı seviyesini güncelle
  static Future<void> updateUserLevel(String uid) async {
    try {
      final stats = await getUserStats(uid);
      if (stats != null) {
        final points = stats['points'] ?? 0;
        final newLevel = calculateLevel(points);
        final currentLevel = stats['level'] ?? 1;
        
        if (newLevel > currentLevel) {
          await updateUserStats(uid, {
            'level': newLevel,
            'tokens': FieldValue.increment(50), // Seviye başına 50 jeton bonus
          });
          
          // Seviye atlama bildirimi (gelecekte)
          // await addNotification(uid, 'level_up', {'newLevel': newLevel});
        }
      }
    } catch (e) {
      print('Seviye güncelleme hatası: $e');
    }
  }

  // Gerçek oyun sonuçlarını kaydetmek için saveGameResult metodunu kullanın
  // Artık sahte veri oluşturmuyoruz - sadece gerçek oyun verileri saklanacak
} 