import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/duel_game.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final Uuid _uuid = const Uuid();

  // Anonymous olarak giriş yap
  static Future<User?> signInAnonymously() async {
    try {
      final UserCredential result = await _auth.signInAnonymously();
      return result.user;
    } catch (e) {
      print('Anonim giriş hatası: $e');
      return null;
    }
  }

  // Mevcut kullanıcıyı al
  static User? getCurrentUser() {
    return _auth.currentUser;
  }

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
      final user = getCurrentUser();
      if (user == null) return null;

      // Bekleyen oyun ara
      final waitingGames = await _firestore
          .collection('duel_games')
          .where('status', isEqualTo: 'waiting')
          .limit(1)
          .get();

      if (waitingGames.docs.isNotEmpty) {
        // Mevcut oyuna katıl
        final gameDoc = waitingGames.docs.first;
        final gameId = gameDoc.id;
        
        await _firestore.collection('duel_games').doc(gameId).update({
          'players.${user.uid}': DuelPlayer(
            playerId: user.uid,
            playerName: playerName,
            status: PlayerStatus.waiting,
            guesses: List.generate(6, (_) => List.filled(5, '')),
            guessColors: List.generate(6, (_) => List.filled(5, 'transparent')),
            currentAttempt: 0,
            score: 0,
          ).toMap(),
          'status': 'active',
          'startedAt': FieldValue.serverTimestamp(),
        });
        
        return gameId;
      } else {
        // Yeni oyun oluştur
        final gameId = _uuid.v4();
        
        await _firestore.collection('duel_games').doc(gameId).set(
          DuelGame(
            gameId: gameId,
            secretWord: secretWord,
            status: GameStatus.waiting,
            createdAt: DateTime.now(),
            players: {
              user.uid: DuelPlayer(
                playerId: user.uid,
                playerName: playerName,
                status: PlayerStatus.waiting,
                guesses: List.generate(6, (_) => List.filled(5, '')),
                guessColors: List.generate(6, (_) => List.filled(5, 'transparent')),
                currentAttempt: 0,
                score: 0,
              ),
            },
          ).toFirestore(),
        );
        
        return gameId;
      }
    } catch (e) {
      print('Oyun oluşturma hatası: $e');
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
        'players.${user.uid}.guesses': updatedGuesses,
        'players.${user.uid}.guessColors': updatedGuessColors,
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
} 