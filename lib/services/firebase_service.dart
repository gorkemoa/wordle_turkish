import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:uuid/uuid.dart';
import '../models/duel_game.dart';
import 'package:flutter/services.dart';
import 'avatar_service.dart';
import 'package:firebase_core/firebase_core.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL:
          'https://kelimebul-5a4d0-default-rtdb.europe-west1.firebasedatabase.app/');
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    hostedDomain: null,
    clientId: null, // Platform-specific konfigürasyon dosyalarından alınacak
  );
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
      throw _handleAuthException(e);
    } catch (e) {
      print('Kayıt hatası: $e');
      throw Exception('Kayıt işlemi başarısız: $e');
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
      throw _handleAuthException(e);
    } catch (e) {
      print('Giriş hatası: $e');
      throw Exception('Giriş işlemi başarısız: $e');
    }
  }

  // Google ile giriş yap
  static Future<User?> signInWithGoogle() async {
    try {
      print('Google Sign-In başlatılıyor...');
      
      // Google Sign-In instance'ı zaten null olamaz çünkü sabit bir değere atanmış
      print('Google Sign-In instance hazır');
      
      // Önceki oturumu temizle
      try {
        await _googleSignIn.signOut();
        print('Önceki Google oturumu temizlendi');
      } catch (e) {
        print('Google signOut hatası (göz ardı edilebilir): $e');
      }
      
      // Google hesabı seç
      print('Google hesap seçimi başlatılıyor...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print('Google giriş iptal edildi');
        return null;
      }

      print('Google kullanıcısı seçildi: ${googleUser.email}');

      // Google authentication bilgilerini al
      print('Google authentication bilgileri alınıyor...');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        print('Google authentication token\'ları alınamadı');
        print('Access Token: ${googleAuth.accessToken != null ? "Var" : "Yok"}');
        print('ID Token: ${googleAuth.idToken != null ? "Var" : "Yok"}');
        throw Exception('Google authentication başarısız');
      }

      print('Google auth token\'ları alındı');

      // Firebase credential oluştur
      print('Firebase credential oluşturuluyor...');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('Firebase credential oluşturuldu');

      // Firebase ile giriş yap
      print('Firebase ile giriş yapılıyor...');
      final UserCredential result = await _auth.signInWithCredential(credential);
      
      print('Firebase giriş başarılı: ${result.user?.email}');

      // İlk kez giriş yapıyorsa kullanıcı verilerini sakla
      if (result.additionalUserInfo?.isNewUser == true && result.user != null) {
        print('Yeni kullanıcı, profil oluşturuluyor...');
        try {
          await _saveUserProfile(
            result.user!, 
            result.user!.displayName ?? 'Google Kullanıcısı',
            result.user!.email ?? '',
          );
          print('Kullanıcı profili oluşturuldu');
        } catch (e) {
          print('Kullanıcı profili oluşturma hatası: $e');
          // Profil oluşturma hatası giriş işlemini engellemez
        }
      }
      
      return result.user;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth hatası: ${e.code} - ${e.message}');
      print('Firebase Auth detay: ${e.toString()}');
      throw _handleAuthException(e);
    } on PlatformException catch (e) {
      print('Platform hatası: ${e.code} - ${e.message}');
      print('Platform detay: ${e.toString()}');
      throw Exception('Google Sign-In platform hatası: ${e.message}');
    } catch (e) {
      print('Google giriş genel hatası: $e');
      print('Hata tipi: ${e.runtimeType}');
      print('Stack trace: ${StackTrace.current}');
      throw Exception('Google ile giriş başarısız: $e');
    }
  }

  // Auth exception handler
  static Exception _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return Exception('Bu e-posta adresiyle kayıtlı kullanıcı bulunamadı');
      case 'wrong-password':
        return Exception('Hatalı şifre');
      case 'email-already-in-use':
        return Exception('Bu e-posta adresi zaten kullanımda');
      case 'weak-password':
        return Exception('Şifre çok zayıf');
      case 'invalid-email':
        return Exception('Geçersiz e-posta adresi');
      case 'user-disabled':
        return Exception('Bu hesap devre dışı bırakılmış');
      case 'too-many-requests':
        return Exception('Çok fazla başarısız deneme. Lütfen daha sonra tekrar deneyin');
      case 'operation-not-allowed':
        return Exception('Bu giriş yöntemi etkinleştirilmemiş');
      case 'account-exists-with-different-credential':
        return Exception('Bu e-posta adresi farklı bir giriş yöntemiyle kayıtlı');
      default:
        return Exception('Giriş hatası: ${e.message}');
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
      // Kullanıcı için deterministik avatar oluştur
      String userAvatar = AvatarService.generateAvatar(user.uid);
      
      // Önce mevcut kullanıcı profilini kontrol et
      final existingDoc = await _firestore.collection('users').doc(user.uid).get();
      
      final profileData = {
        'uid': user.uid,
        'displayName': displayName,
        'email': email,
        'photoURL': user.photoURL,
        'avatar': userAvatar,
        'isAnonymous': user.isAnonymous,
        'lastActiveAt': FieldValue.serverTimestamp(),
      };
      
      // Sadece yeni kullanıcılar için varsayılan değerleri ekle
      if (!existingDoc.exists) {
        profileData.addAll({
          'createdAt': FieldValue.serverTimestamp(),
          'gamesPlayed': 0,
          'gamesWon': 0,
          'tokens': 2, // Yeni üyeler 2 jetonla başlar
        });
      }
      
      await _firestore.collection('users').doc(user.uid).set(profileData, SetOptions(merge: true));

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

  // Avatar yönetimi fonksiyonları
  
  /// Kullanıcının mevcut avatarını al (Realtime Database)
  static Future<String?> getUserAvatar(String uid) async {
    try {
      print('DEBUG - Avatar alınıyor UID: $uid');
      final user = getCurrentUser();
      print('DEBUG - Current user: ${user?.uid}, Auth: ${user != null}');
      
      final snapshot = await _database.ref('users/$uid/avatar').get();
      
      if (snapshot.exists) {
        final savedAvatar = snapshot.value as String?;
        if (savedAvatar != null && savedAvatar.isNotEmpty) {
          print('DEBUG - Avatar Realtime DB\'den alındı: $savedAvatar');
          return savedAvatar;
        }
      }
      
      // Avatar yoksa oluştur ve kaydet
      print('DEBUG - Avatar bulunamadı, yeni oluşturuluyor...');
      final newAvatar = AvatarService.generateAvatar(uid);
      await updateUserAvatar(uid, newAvatar);
      print('DEBUG - Yeni avatar Realtime DB\'ye kaydedildi: $newAvatar');
      return newAvatar;
    } catch (e) {
      print('Avatar alma hatası: $e');
      print('DEBUG - Database URL: ${_database.app.options.databaseURL}');
      // Hata durumunda bile bir avatar döndür
      return AvatarService.generateAvatar(uid);
    }
  }

  /// Kullanıcının avatarını güncelle (Realtime Database)
  static Future<bool> updateUserAvatar(String uid, String newAvatar) async {
    try {
      // Avatar'ın geçerli olup olmadığını kontrol et
      if (!AvatarService.isValidAvatar(newAvatar)) {
        print('Geçersiz avatar: $newAvatar');
        return false;
      }

      // Realtime Database'de güncelle
      await _database.ref('users/$uid').update({
        'avatar': newAvatar,
        'lastActiveAt': ServerValue.timestamp,
      });

      print('DEBUG - Avatar Realtime DB\'de güncellendi: $newAvatar');
      return true;
    } catch (e) {
      print('Avatar güncelleme hatası: $e');
      return false;
    }
  }

  /// Kullanıcının adını güncelle
  static Future<bool> updateUserDisplayName(String uid, String newDisplayName) async {
    try {
      // Kullanıcı adını temizle
      final cleanName = newDisplayName.trim();
      if (cleanName.isEmpty || cleanName.length < 2) {
        print('Geçersiz kullanıcı adı: çok kısa');
        return false;
      }
      
      if (cleanName.length > 20) {
        print('Geçersiz kullanıcı adı: çok uzun');
        return false;
      }

      await _firestore.collection('users').doc(uid).update({
        'displayName': cleanName,
        'lastActiveAt': FieldValue.serverTimestamp(),
      });

      // Leaderboard stats'ta da güncelle
      await _firestore.collection('leaderboard_stats').doc(uid).update({
        'playerName': cleanName,
      });

      return true;
    } catch (e) {
      print('Kullanıcı adı güncelleme hatası: $e');
      return false;
    }
  }

  /// Kullanıcı için yeni rastgele avatar oluştur
  static Future<String?> generateNewAvatar(String uid) async {
    try {
      final currentAvatar = await getUserAvatar(uid);
      final newAvatar = AvatarService.changeAvatar(currentAvatar);
      
      final success = await updateUserAvatar(uid, newAvatar);
      return success ? newAvatar : null;
    } catch (e) {
      print('Yeni avatar oluşturma hatası: $e');
      return null;
    }
  }

  /// Kullanıcının avatar'ını deterministik olarak sıfırla
  static Future<String?> resetUserAvatar(String uid) async {
    try {
      final defaultAvatar = AvatarService.generateAvatar(uid);
      final success = await updateUserAvatar(uid, defaultAvatar);
      return success ? defaultAvatar : null;
    } catch (e) {
      print('Avatar sıfırlama hatası: $e');
      return null;
    }
  }

  // Yeni oyun odası oluştur veya mevcut odaya katıl (Realtime Database)
  static Future<String?> findOrCreateGame(String playerName, String secretWord) async {
    try {
      print('=== DÜELLO OYUNU OLUŞTURMA BAŞLADI ===');
      print('Realtime DB oyun oluşturma başlatılıyor...');
      print('Database URL: ${_database.app.options.databaseURL}');
      
      final user = getCurrentUser();
      if (user == null) {
        print('HATA: Kullanıcı null - giriş yapılmamış!');
        return null;
      }
      print('✓ Kullanıcı ID: ${user.uid}');
      print('✓ Oyuncu adı: $playerName');
      print('✓ Gizli kelime: $secretWord');

      // Bekleyen oyunları ara
      print('Bekleyen oyunlar aranıyor...');
      final waitingGamesSnapshot = await _database
          .ref('duel_games')
          .orderByChild('status')
          .equalTo('waiting')
          .limitToFirst(10)
          .get();

      if (waitingGamesSnapshot.exists) {
        final waitingGames = waitingGamesSnapshot.value as Map<dynamic, dynamic>;
        print('Bulunan bekleyen oyun sayısı: ${waitingGames.length}');

        // 1 oyunculu oyun ara
        for (final entry in waitingGames.entries) {
          final gameId = entry.key as String;
          final gameData = entry.value as Map<dynamic, dynamic>;
          final players = gameData['players'] as Map<dynamic, dynamic>? ?? {};
          
          if (players.length == 1) {
            print('Mevcut oyuna katılıyor: $gameId');
            
            // Oyuna katıl
            final userAvatar = await getUserAvatar(user.uid);
            await _database.ref('duel_games/$gameId/players/${user.uid}').set({
              'playerId': user.uid,
              'playerName': playerName,
              'status': 'waiting',
              'guesses': List.generate(6, (_) => List.filled(5, '_')),
              'guessColors': List.generate(6, (_) => List.filled(5, 'empty')),
              'currentAttempt': 0,
              'score': 0,
              'avatar': userAvatar,
            });

            await _database.ref('duel_games/$gameId/updatedAt').set(ServerValue.timestamp);
            
            print('Mevcut oyuna başarıyla katıldı');
            
            // İki oyuncu da katıldıysa oyunu başlat
            await _checkAndStartGame(gameId);
            return gameId;
          }
        }
      }

      // Yeni oyun oluştur
      final gameId = _uuid.v4();
      print('Yeni oyun oluşturuluyor: $gameId');

      final userAvatar = await getUserAvatar(user.uid);
      await _database.ref('duel_games/$gameId').set({
        'gameId': gameId,
        'secretWord': secretWord,
        'status': 'waiting',
        'createdAt': ServerValue.timestamp,
        'updatedAt': ServerValue.timestamp,
        'players': {
          user.uid: {
            'playerId': user.uid,
            'playerName': playerName,
            'status': 'waiting',
            'guesses': List.generate(6, (_) => List.filled(5, '_')),
            'guessColors': List.generate(6, (_) => List.filled(5, 'empty')),
            'currentAttempt': 0,
            'score': 0,
            'avatar': userAvatar,
          }
        },
      });

      print('Yeni oyun başarıyla oluşturuldu');
      return gameId;
    } catch (e, s) {
      print('Oyun oluşturma hatası: $e');
      print('Stack Trace: $s');
      return null;
    }
  }

  // Oyun başlatılabilir mi kontrol et ve başlat
  static Future<void> _checkAndStartGame(String gameId) async {
    try {
      final gameSnapshot = await _database.ref('duel_games/$gameId').get();
      if (gameSnapshot.exists) {
        final gameData = gameSnapshot.value as Map<dynamic, dynamic>;
        final players = gameData['players'] as Map<dynamic, dynamic>? ?? {};
        
        if (players.length == 2) {
          print('İki oyuncu da katıldı, oyun başlatılıyor...');
          await _database.ref('duel_games/$gameId').update({
            'status': 'active',
            'startedAt': ServerValue.timestamp,
            'updatedAt': ServerValue.timestamp,
          });
          
          // Oyuncuları playing durumuna getir
          for (final playerId in players.keys) {
            await _database.ref('duel_games/$gameId/players/$playerId/status').set('playing');
          }
        }
      }
    } catch (e) {
      print('Oyun başlatma kontrol hatası: $e');
    }
  }

  // Oyun durumunu dinle (Realtime Database)
  static Stream<DuelGame?> listenToGame(String gameId) {
    return _database.ref('duel_games/$gameId').onValue.map((event) {
      if (event.snapshot.exists) {
        try {
          final gameData = event.snapshot.value as Map<dynamic, dynamic>;
          return DuelGame.fromRealtimeDatabase(gameData);
        } catch (e) {
          print('Oyun parse hatası: $e');
          return null;
        }
      }
      return null;
    });
  }

  // Tahmin yap (Realtime Database)
  static Future<bool> makeGuess(String gameId, List<String> guess, List<String> guessColors) async {
    try {
      final user = getCurrentUser();
      if (user == null) return false;

      final gameSnapshot = await _database.ref('duel_games/$gameId').get();
      if (!gameSnapshot.exists) return false;

      final gameData = gameSnapshot.value as Map<dynamic, dynamic>;
      final game = DuelGame.fromRealtimeDatabase(gameData);
      final player = game.players[user.uid];
      if (player == null) return false;

      // Player'ın tahminlerini güncelle
      final updatedGuesses = List<List<String>>.from(player.guesses);
      final updatedGuessColors = List<List<String>>.from(player.guessColors);
      
      updatedGuesses[player.currentAttempt] = guess;
      updatedGuessColors[player.currentAttempt] = guessColors;

      // Kazanma durumunu kontrol et
      final isWinner = guess.join('').toUpperCase() == game.secretWord.toUpperCase();
      final isLastAttempt = player.currentAttempt >= 5; // 6 tahmin (0-5 index)
      
      PlayerStatus newStatus;
      if (isWinner) {
        newStatus = PlayerStatus.won;
      } else if (isLastAttempt) {
        newStatus = PlayerStatus.lost;
      } else {
        newStatus = PlayerStatus.playing;
      }
      
      final newAttempt = (isWinner || isLastAttempt) ? player.currentAttempt : player.currentAttempt + 1;

      // Oyun bitip bitmediğini kontrol et
      bool gameFinished = false;
      String? winnerId;
      
      if (isWinner) {
        // Bu oyuncu kazandı
        gameFinished = true;
        winnerId = user.uid;
      } else if (isLastAttempt) {
        // Bu oyuncu son tahminini yaptı ve kelimeyi bulamadı
        gameFinished = true;
        
        // Diğer oyuncunun durumunu kontrol et
        final opponentPlayer = game.players.values.firstWhere(
          (p) => p.playerId != user.uid,
          orElse: () => DuelPlayer(
            playerId: '',
            playerName: '',
            status: PlayerStatus.waiting,
            guesses: [],
            guessColors: [],
            currentAttempt: 0,
            score: 0,
          ),
        );
        
        // Eğer rakip daha önce kelimeyi bilmişse onun kazanması
        if (opponentPlayer.status == PlayerStatus.won) {
          winnerId = opponentPlayer.playerId;
        } else if (opponentPlayer.status == PlayerStatus.lost) {
          // Her iki oyuncu da kelimeyi bulamadı - berabere
          winnerId = null;
        } else {
          // Rakip hala oynuyor, bu oyuncu kaybetti - rakip kazandı
          winnerId = opponentPlayer.playerId;
          
          // Rakip oyuncunun durumunu da güncelle
          await _database.ref('duel_games/$gameId/players/${opponentPlayer.playerId}').update({
            'status': PlayerStatus.won.name,
            'finishedAt': ServerValue.timestamp,
          });
        }
      }

      final updateData = <String, dynamic>{
        'players/${user.uid}/guesses': updatedGuesses,
        'players/${user.uid}/guessColors': updatedGuessColors,
        'players/${user.uid}/currentAttempt': newAttempt,
        'players/${user.uid}/status': newStatus.name,
        'updatedAt': ServerValue.timestamp,
      };

      if (isWinner || isLastAttempt) {
        updateData['players/${user.uid}/finishedAt'] = ServerValue.timestamp;
      }

      if (gameFinished) {
        updateData['status'] = 'finished';
        updateData['finishedAt'] = ServerValue.timestamp;
        if (winnerId != null) {
          updateData['winnerId'] = winnerId;
        }
      }

      await _database.ref('duel_games/$gameId').update(updateData);

      print('Tahmin yapıldı - isWinner: $isWinner, gameFinished: $gameFinished, winnerId: $winnerId');
      
      // Oyun bittiyse geçmişe kaydet
      if (gameFinished) {
        await _saveDuelGameToHistory(gameId, game, winnerId);
      }
      
      return true;
    } catch (e) {
      print('Tahmin yapma hatası: $e');
      return false;
    }
  }

  // Bitmiş düello oyununu geçmişe kaydet (Firestore)
  static Future<void> _saveDuelGameToHistory(String gameId, DuelGame game, String? winnerId) async {
    try {
      final gameHistoryData = {
        'gameId': gameId,
        'gameType': 'Duello',
        'secretWord': game.secretWord,
        'players': game.players.map((playerId, player) => MapEntry(playerId, {
          'playerId': player.playerId,
          'playerName': player.playerName,
          'status': player.status.name,
          'score': player.score,
          'avatar': player.avatar,
          'currentAttempt': player.currentAttempt,
        })),
        'winnerId': winnerId,
        'status': 'finished',
        'createdAt': game.createdAt,
        'finishedAt': FieldValue.serverTimestamp(),
      };
      
      // Firestore'a oyun geçmişi olarak kaydet
      await _firestore.collection('duel_game_history').add(gameHistoryData);
      
      // Her oyuncu için ayrı kayıt ekle
      for (final player in game.players.values) {
        final isWinner = player.playerId == winnerId;
        await addGameToHistory(player.playerId, {
          'gameType': 'Duello',
          'secretWord': game.secretWord,
          'isWon': isWinner,
          'score': player.score,
          'attempts': player.currentAttempt,
          'opponentName': game.players.values
              .firstWhere((p) => p.playerId != player.playerId, 
                         orElse: () => DuelPlayer(
                           playerId: '', 
                           playerName: 'Bilinmeyen', 
                           status: PlayerStatus.waiting,
                           guesses: [], 
                           guessColors: [], 
                           currentAttempt: 0, 
                           score: 0
                         )).playerName,
        });
      }
      
      print('Düello oyunu geçmişe kaydedildi: $gameId');
    } catch (e) {
      print('Düello oyunu geçmişe kaydetme hatası: $e');
    }
  }

  // Oyunu terk et (Realtime Database)
  static Future<void> leaveGame(String gameId) async {
    try {
      final user = getCurrentUser();
      if (user == null) return;

      final gameSnapshot = await _database.ref('duel_games/$gameId').get();
      if (gameSnapshot.exists) {
        final gameData = gameSnapshot.value as Map<dynamic, dynamic>;
        final players = gameData['players'] as Map<dynamic, dynamic>? ?? {};
        
        if (players.length <= 1) {
          // Son oyuncu çıkıyorsa oyunu sil
          await _database.ref('duel_games/$gameId').remove();
          print('Son oyuncu çıktı, oyun silindi: $gameId');
        } else {
          // Oyuncunun durumunu disconnected yap
          await _database.ref('duel_games/$gameId/players/${user.uid}/status').set('disconnected');
          await _database.ref('duel_games/$gameId/updatedAt').set(ServerValue.timestamp);
          print('Oyuncu bağlantısı kesildi: ${user.uid}');
        }
      }
    } catch (e) {
      print('Oyun terk etme hatası: $e');
    }
  }

  // Oyunu sil (Realtime Database temizlik)
  static Future<void> deleteGame(String gameId) async {
    try {
      await _database.ref('duel_games/$gameId').remove();
    } catch (e) {
      print('Oyun silme hatası: $e');
    }
  }

  // Oyuncunun hazır durumunu ayarla (Realtime Database)
  static Future<void> setPlayerReady(String gameId) async {
    try {
      final user = getCurrentUser();
      if (user == null) return;

      await _database.ref('duel_games/$gameId/players/${user.uid}/status').set('ready');
      await _database.ref('duel_games/$gameId/updatedAt').set(ServerValue.timestamp);

      // Her iki oyuncu da hazır mı kontrol et
      await _checkAndStartGame(gameId);
    } catch (e) {
      print('Oyuncu hazır durumu ayarlama hatası: $e');
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
          'currentStreak': 0,
          'bestStreak': 0,
          'gamesPlayed': 0,
          'gamesWon': 0,
          'winRate': 0.0,
          'bestScore': 0,
          'totalPlayTime': 0,
          'lastGameDate': FieldValue.serverTimestamp(),
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
              // Jetonları hem user_stats hem de users koleksiyonunda güncelle
              await updateUserStats(uid, {'tokens': FieldValue.increment(rewardAmount)});
              await _firestore.collection('users').doc(uid).update({
                'tokens': FieldValue.increment(rewardAmount),
                'lastActiveAt': FieldValue.serverTimestamp(),
              });
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
      
      // Kullanıcı profili ve avatar var mı kontrol et
      await _ensureUserProfileExists(uid);
    } catch (e) {
      print('Kullanıcı verilerini başlatma hatası: $e');
    }
  }

  // Kullanıcı profilinin var olduğundan emin ol
  static Future<void> _ensureUserProfileExists(String uid) async {
    try {
      final user = getCurrentUser();
      if (user == null) return;
      
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        print('DEBUG - Kullanıcı profili yok, oluşturuluyor...');
        await _saveUserProfile(user, user.displayName ?? generatePlayerName(), user.email ?? '');
      } else {
        // Profil var ama avatar yoksa ekle
        final data = userDoc.data();
        final avatar = data?['avatar'] as String?;
        if (avatar == null || avatar.isEmpty) {
          print('DEBUG - Avatar eksik, ekleniyor...');
          final newAvatar = AvatarService.generateAvatar(uid);
          await _firestore.collection('users').doc(uid).update({
            'avatar': newAvatar,
            'lastActiveAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('Kullanıcı profil kontrol hatası: $e');
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
        
        // Kazanma serisi kontrolü
        final userStats = await getUserStats(uid);
        if (userStats != null) {
          final currentStreak = userStats['currentStreak'] ?? 0;
          final bestStreak = userStats['bestStreak'] ?? 0;
          final newStreak = currentStreak + 1;
          
          updates['currentStreak'] = newStreak;
          
          // En iyi seriyi güncelle
          if (newStreak > bestStreak) {
            updates['bestStreak'] = newStreak;
          }
        } else {
          // İlk kazanma
          updates['currentStreak'] = 1;
          updates['bestStreak'] = 1;
        }
      } else {
        // Kaybedince seriyi sıfırla
        updates['currentStreak'] = 0;
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
      
      // Jeton sistemini güncelle
      await updateTokensForGameResult(uid, isWon, gameType);

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

  // Realtime Database ile aktif kullanıcı sayısını dinle
  static Stream<int> getActiveUsersCount() {
    return _database.ref('presence').onValue.map((event) {
      if (event.snapshot.value == null) {
        print('DEBUG - Aktif kullanıcı sayısı: 0');
        return 0;
      }
      
      final presence = event.snapshot.value as Map<dynamic, dynamic>;
      int activeCount = 0;
      
      // DEBUG: Aktif kullanıcıları listele
      print('DEBUG - Presence verileri:');
      for (final entry in presence.entries) {
        final userData = entry.value as Map<dynamic, dynamic>;
        final isOnline = userData['isOnline'] as bool? ?? false;
        final lastSeen = userData['lastSeen'];
        print('  UID: ${entry.key}, Online: $isOnline, LastSeen: $lastSeen');
        if (isOnline) {
          activeCount++;
        }
      }
      
      print('DEBUG - Aktif kullanıcı sayısı: $activeCount');
      return activeCount;
    });
  }

  // Test için presence verilerini temizle
  static Future<void> clearAllPresenceData() async {
    try {
      await _database.ref('presence').remove();
      print('DEBUG - Tüm presence verileri temizlendi');
    } catch (e) {
      print('DEBUG - Presence temizleme hatası: $e');
    }
  }

  // Kullanıcının online durumunu kaydet (Realtime Database)
  static Future<void> setUserOnline() async {
    try {
      final user = getCurrentUser();
      if (user == null) return;

      final userPresenceRef = _database.ref('presence/${user.uid}');
      
      // Online durumunu kaydet
      await userPresenceRef.set({
        'isOnline': true,
        'lastSeen': ServerValue.timestamp,
        'deviceInfo': 'flutter_app',
      });
      
      // Bağlantı kesildiğinde otomatik offline yap
      await userPresenceRef.onDisconnect().set({
        'isOnline': false,
        'lastSeen': ServerValue.timestamp,
      });
      
      print('DEBUG - Kullanıcı online olarak işaretlendi (Realtime DB)');
      
      // İlk giriş yapılırken eski oyunları temizle
      cleanupOldDuelGames();
    } catch (e) {
      print('Online durumu kaydetme hatası: $e');
    }
  }

  // Kullanıcının offline durumunu kaydet (Realtime Database)
  static Future<void> setUserOffline() async {
    try {
      final user = getCurrentUser();
      if (user == null) return;

      await _database.ref('presence/${user.uid}').set({
        'isOnline': false,
        'lastSeen': ServerValue.timestamp,
      });
      
      print('DEBUG - Kullanıcı offline olarak işaretlendi (Realtime DB)');
    } catch (e) {
      print('Offline durumu kaydetme hatası: $e');
    }
  }

  // Presence heartbeat artık gerekli değil - onDisconnect otomatik yapıyor
  static Future<void> updateUserPresence() async {
    // Realtime Database otomatik presence yönetimi kullandığı için bu metod artık boş
    // Ama uyumluluk için bırakıyoruz
  }

  // Eski düello oyunlarını temizle (Realtime Database)
  static Future<void> cleanupOldDuelGames() async {
    try {
      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch;
      
      final allGamesSnapshot = await _database.ref('duel_games').get();
      if (!allGamesSnapshot.exists) return;
      
      final allGames = allGamesSnapshot.value as Map<dynamic, dynamic>;
      final gamesToDelete = <String>[];
      final finishedGamesToSave = <String, Map<dynamic, dynamic>>{};
      
      for (final entry in allGames.entries) {
        final gameId = entry.key as String;
        final gameData = entry.value as Map<dynamic, dynamic>;
        final status = gameData['status'] as String?;
        final createdAt = gameData['createdAt'] as int?;
        
        // Bitmiş oyunları geçmişe kaydet
        if (status == 'finished') {
          finishedGamesToSave[gameId] = gameData;
          gamesToDelete.add(gameId);
        }
        // 1 saatten eski aktif oyunları da temizle
        else if (createdAt != null && createdAt < oneHourAgo) {
          gamesToDelete.add(gameId);
        }
      }
      
      print('DEBUG - Temizlenecek eski oyun sayısı: ${gamesToDelete.length}');
      print('DEBUG - Geçmişe kaydedilecek bitmiş oyun sayısı: ${finishedGamesToSave.length}');
      
      // Önce bitmiş oyunları geçmişe kaydet
      for (final entry in finishedGamesToSave.entries) {
        try {
          final gameId = entry.key;
          final gameData = entry.value;
          final game = DuelGame.fromRealtimeDatabase(gameData);
          final winnerId = gameData['winnerId'] as String?;
          
          await _saveDuelGameToHistory(gameId, game, winnerId);
        } catch (e) {
          print('DEBUG - Oyun geçmişe kaydetme hatası ($entry.key): $e');
        }
      }
      
      // Sonra Realtime Database'den sil
      if (gamesToDelete.isNotEmpty) {
        final updates = <String, dynamic>{};
        for (final gameId in gamesToDelete) {
          updates['duel_games/$gameId'] = null; // null = sil
        }
        
        await _database.ref().update(updates);
        print('DEBUG - ${gamesToDelete.length} eski oyun temizlendi');
      }
    } catch (e) {
      print('DEBUG - Eski oyun temizleme hatası: $e');
    }
  }

  // Tüm düello oyunlarını sil (acil durum için - Realtime Database)
  static Future<void> clearAllDuelGames() async {
    try {
      await _database.ref('duel_games').remove();
      print('DEBUG - Tüm düello oyunları silindi (Realtime Database)');
    } catch (e) {
      print('DEBUG - Tüm oyunları silme hatası: $e');
    }
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

  // ============= JETON YÖNETİMİ =============
  
  /// Kullanıcının mevcut jeton sayısını al
  static Future<int> getUserTokens(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        return data['tokens'] ?? 0;
      }
      return 0;
    } catch (e) {
      print('Jeton alma hatası: $e');
      return 0;
    }
  }
  
  /// Jeton harca (ipucu, güçlendirme vs.)
  static Future<bool> spendTokens(String uid, int amount, String reason) async {
    try {
      final currentTokens = await getUserTokens(uid);
      if (currentTokens < amount) {
        print('Yetersiz jeton: $currentTokens < $amount');
        return false;
      }
      
      await _firestore.collection('users').doc(uid).update({
        'tokens': FieldValue.increment(-amount),
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
      
      // Jeton harcama geçmişi kaydet
      await _logTokenTransaction(uid, -amount, reason);
      print('$amount jeton harcandı: $reason');
      return true;
    } catch (e) {
      print('Jeton harcama hatası: $e');
      return false;
    }
  }
  
  /// Jeton kazan (oyun kazanma, reklam izleme vs.)
  static Future<void> earnTokens(String uid, int amount, String reason) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'tokens': FieldValue.increment(amount),
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
      
      // Jeton kazanma geçmişi kaydet
      await _logTokenTransaction(uid, amount, reason);
      print('$amount jeton kazanıldı: $reason');
    } catch (e) {
      print('Jeton kazanma hatası: $e');
    }
  }
  
  /// Jeton işlem geçmişi kaydet
  static Future<void> _logTokenTransaction(String uid, int amount, String reason) async {
    try {
      await _firestore.collection('token_transactions').add({
        'uid': uid,
        'amount': amount,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Jeton işlem kaydı hatası: $e');
    }
  }
  
  /// Reklam izleyerek jeton kazan
  static Future<void> earnTokensFromAd(String uid) async {
    try {
      const int adTokenReward = 1; // Reklam başına 1 jeton
      await earnTokens(uid, adTokenReward, 'Reklam İzleme');
      
      // Reklam izleme istatistiği
      await _firestore.collection('users').doc(uid).update({
        'adsWatched': FieldValue.increment(1),
      });
    } catch (e) {
      print('Reklam jeton kazanma hatası: $e');
    }
  }
  
  /// Günlük bonus jeton kazan (reklam alternatifi)
  static Future<bool> earnDailyBonus(String uid) async {
    try {
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month}-${today.day}';
      
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};
      final lastBonusDate = userData['lastBonusDate'] as String?;
      
      // Bugün zaten bonus aldı mı kontrol et
      if (lastBonusDate == todayStr) {
        return false; // Bugün zaten aldı
      }
      
      // Bonus ver
      await earnTokens(uid, 1, 'Günlük Bonus');
      
      // Son bonus tarihini güncelle
      await _firestore.collection('users').doc(uid).update({
        'lastBonusDate': todayStr,
      });
      
      return true;
    } catch (e) {
      print('Günlük bonus hatası: $e');
      return false;
    }
  }
  
  /// Günlük bonus alınabilir mi kontrol et
  static Future<bool> canEarnDailyBonus(String uid) async {
    try {
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month}-${today.day}';
      
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};
      final lastBonusDate = userData['lastBonusDate'] as String?;
      
      return lastBonusDate != todayStr;
    } catch (e) {
      print('Günlük bonus kontrol hatası: $e');
      return false;
    }
  }
  
  /// Oyun sonucuna göre jeton güncelle
  static Future<void> updateTokensForGameResult(String uid, bool won, String gameType) async {
    try {
      if (won) {
        await earnTokens(uid, 1, '$gameType Kazanma');
      } else {
        // Sadece tek oyuncu modunda kaybedince jeton kes
        if (!gameType.contains('Düello')) {
          final currentTokens = await getUserTokens(uid);
          if (currentTokens > 0) {
            await spendTokens(uid, 1, '$gameType Kaybetme');
          }
        }
        // Düello modunda jeton kesimi oyun başında yapılır
      }
    } catch (e) {
      print('Oyun sonucu jeton güncelleme hatası: $e');
    }
  }
} 