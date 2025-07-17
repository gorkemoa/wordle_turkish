import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// 🌐 Güvenilir online kullanıcı takip servisi
/// 
/// Bu servis şu özellikleri sağlar:
/// - Firebase onDisconnect() otomatik offline yapma
/// - Periyodik heartbeat (30 saniye)
/// - Zaman bazlı online kontrolü
/// - Güvenilir online kullanıcı sayma
class PresenceService {
  static final FirebaseDatabase _database = FirebaseDatabase.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Presence yolları
  static final DatabaseReference _presenceRef = _database.ref('presence');
  static final DatabaseReference _connectInfoRef = _database.ref('.info/connected');
  
  // Timer ve subscription yönetimi
  static Timer? _heartbeatTimer;
  static StreamSubscription<DatabaseEvent>? _connectionSubscription;
  static String? _currentUserId;
  static bool _isInitialized = false;
  
  // Ayarlar
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  static const Duration _onlineThreshold = Duration(minutes: 2); // 2 dakika içinde görülmüşse online

  /// 🚀 Presence servisini başlat
  /// 
  /// Kullanıcı giriş yaptığında bu metodu çağırın
  static Future<bool> initialize() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ PresenceService: Kullanıcı giriş yapmamış');
        return false;
      }

      if (_isInitialized && _currentUserId == user.uid) {
        debugPrint('✅ PresenceService: Zaten başlatılmış');
        return true;
      }

      // Önceki servisi temizle
      await dispose();

      _currentUserId = user.uid;
      debugPrint('🚀 PresenceService başlatılıyor: ${user.uid}');

      // Bağlantı durumunu dinle ve presence ayarla
      await _setupConnectionListener();
      
      // İlk presence ayarını yap
      await _setPresenceOnline();
      
      // Heartbeat başlat
      _startHeartbeat();
      
      _isInitialized = true;
      debugPrint('✅ PresenceService başarıyla başlatıldı');
      return true;
      
    } catch (e) {
      debugPrint('❌ PresenceService başlatma hatası: $e');
      return false;
    }
  }

  /// 🔌 Bağlantı durumunu dinle ve otomatik presence ayarla
  static Future<void> _setupConnectionListener() async {
    _connectionSubscription = _connectInfoRef.onValue.listen((event) async {
      final isConnected = event.snapshot.value as bool? ?? false;
      debugPrint('🔌 Bağlantı durumu: ${isConnected ? "Bağlı" : "Bağlantı kesildi"}');
      
      if (isConnected && _currentUserId != null) {
        // Bağlantı kurulduğunda presence ayarla
        await _setPresenceOnline();
      }
    });
  }

  /// 📡 Kullanıcıyı online olarak işaretle ve onDisconnect ayarla
  static Future<void> _setPresenceOnline() async {
    if (_currentUserId == null) return;

    try {
      final userPresenceRef = _presenceRef.child(_currentUserId!);
      final now = ServerValue.timestamp;
      
      // Online durumunu ayarla (sadece 'online' field'ı kullan)
      final onlineData = {
        'online': true,
        'lastSeen': now,
        'lastHeartbeat': now,
        'platform': _getPlatform(),
        'connectedAt': now,
      };
      await userPresenceRef.set(onlineData).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Online durumu ayarlama timeout'),
      );
      // Bağlantı kesildiğinde otomatik offline yap
      final offlineData = {
        'online': false,
        'lastSeen': now,
        'lastHeartbeat': now,
        'platform': _getPlatform(),
        'disconnectedAt': now,
      };
      await userPresenceRef.onDisconnect().set(offlineData).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('OnDisconnect ayarlama timeout'),
      );
      
      debugPrint('✅ Presence online ayarlandı: $_currentUserId');
      
    } catch (e) {
      debugPrint('❌ Presence online ayarlama hatası: $e');
      rethrow;
    }
  }

  /// 💓 Periyodik heartbeat başlat
  static void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) async {
      await _sendHeartbeat();
    });
    
    debugPrint('💓 Heartbeat başlatıldı (${_heartbeatInterval.inSeconds}s aralık)');
  }

  /// 💓 Heartbeat gönder
  static Future<void> _sendHeartbeat() async {
    if (_currentUserId == null || !_isInitialized) {
      debugPrint('⚠️ Heartbeat: Servis başlatılmamış');
      return;
    }

    try {
      final user = _auth.currentUser;
      if (user == null || user.uid != _currentUserId) {
        debugPrint('⚠️ Heartbeat: Kullanıcı değişti, servisi yeniden başlat');
        await dispose();
        return;
      }

      final userPresenceRef = _presenceRef.child(_currentUserId!);
      
      // Sadece lastHeartbeat ve lastSeen güncelle, online durumunu değiştirme
      await userPresenceRef.update({
        'lastHeartbeat': ServerValue.timestamp,
        'lastSeen': ServerValue.timestamp,
      }).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Heartbeat timeout'),
      );
      
      debugPrint('💓 Heartbeat gönderildi: $_currentUserId');
      
    } catch (e) {
      debugPrint('❌ Heartbeat hatası: $e');
      // Heartbeat hataları kritik değil, servisi durdurmaz
    }
  }

  /// 🔴 Kullanıcıyı manuel olarak offline yap
  static Future<void> setOffline() async {
    if (_currentUserId == null) return;

    try {
      final userPresenceRef = _presenceRef.child(_currentUserId!);
      
      await userPresenceRef.update({
        'online': false,
        'lastSeen': ServerValue.timestamp,
        'lastHeartbeat': ServerValue.timestamp,
        'disconnectedAt': ServerValue.timestamp,
      }).timeout(const Duration(seconds: 5));
      
      debugPrint('🔴 Kullanıcı manuel offline yapıldı: $_currentUserId');
      
    } catch (e) {
      debugPrint('❌ Offline yapma hatası: $e');
    }
  }

  /// 🧹 Servisi temizle ve kaynakları serbest bırak
  static Future<void> dispose() async {
    debugPrint('🧹 PresenceService temizleniyor...');
    
    // Manuel offline yap
    if (_isInitialized && _currentUserId != null) {
      await setOffline();
    }
    
    // Timer'ı durdur
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    
    // Subscription'ları kapat
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    
    // Değişkenleri sıfırla
    _currentUserId = null;
    _isInitialized = false;
    
    debugPrint('✅ PresenceService temizlendi');
  }

  /// 📊 Gerçek zamanlı online kullanıcı sayısını dinle
  /// 
  /// Bu stream zaman bazlı kontrol yaparak güvenilir sonuç verir
  static Stream<int> getOnlineUsersCountStream() {
    return _presenceRef.onValue.map((event) {
      return _calculateOnlineUsersCount(event.snapshot);
    }).handleError((error) {
      debugPrint('❌ Online kullanıcı sayısı dinleme hatası: $error');
      return 0;
    });
  }

  /// 📊 Anlık online kullanıcı sayısını al
  static Future<int> getOnlineUsersCount() async {
    try {
      final snapshot = await _presenceRef.get();
      return _calculateOnlineUsersCount(snapshot);
    } catch (e) {
      debugPrint('❌ Online kullanıcı sayısı alma hatası: $e');
      return 0;
    }
  }

  /// 📊 Online kullanıcı sayısını hesapla (zaman bazlı kontrol ile)
  static int _calculateOnlineUsersCount(DataSnapshot snapshot) {
    if (!snapshot.exists || snapshot.value == null) {
      return 0;
    }

    try {
      final presenceData = snapshot.value as Map<dynamic, dynamic>;
      final now = DateTime.now().millisecondsSinceEpoch;
      final thresholdTime = now - _onlineThreshold.inMilliseconds;
      
      int onlineCount = 0;
      
      for (final entry in presenceData.entries) {
        final userData = entry.value;
        if (userData is! Map<dynamic, dynamic>) continue;
        
        final isOnline = userData['online'] as bool? ?? false;
        final lastSeen = userData['lastSeen'] as int?;
        final lastHeartbeat = userData['lastHeartbeat'] as int?;
        
        // Çift kontrol: hem online flag'i hem de zaman kontrolü
        if (isOnline) {
          // Son görülme veya heartbeat zamanını kontrol et
          final latestActivity = [lastSeen, lastHeartbeat]
              .where((time) => time != null)
              .cast<int>()
              .fold<int?>(null, (prev, current) => 
                  prev == null ? current : (current > prev ? current : prev));
          
          if (latestActivity != null && latestActivity >= thresholdTime) {
            onlineCount++;
          }
        }
      }
      
      debugPrint('📊 Online kullanıcı sayısı: $onlineCount (toplam presence: ${presenceData.length})');
      return onlineCount;
      
    } catch (e) {
      debugPrint('❌ Online kullanıcı sayısı hesaplama hatası: $e');
      return 0;
    }
  }

  /// 👥 Online kullanıcıların listesini al
  static Future<List<OnlineUser>> getOnlineUsers() async {
    try {
      final snapshot = await _presenceRef.get();
      return _extractOnlineUsers(snapshot);
    } catch (e) {
      debugPrint('❌ Online kullanıcı listesi alma hatası: $e');
      return [];
    }
  }

  /// 👥 Online kullanıcıların listesini çıkar
  static List<OnlineUser> _extractOnlineUsers(DataSnapshot snapshot) {
    if (!snapshot.exists || snapshot.value == null) {
      return [];
    }

    try {
      final presenceData = snapshot.value as Map<dynamic, dynamic>;
      final now = DateTime.now().millisecondsSinceEpoch;
      final thresholdTime = now - _onlineThreshold.inMilliseconds;
      
      final onlineUsers = <OnlineUser>[];
      
      for (final entry in presenceData.entries) {
        final userId = entry.key as String;
        final userData = entry.value;
        if (userData is! Map<dynamic, dynamic>) continue;
        
        final isOnline = userData['online'] as bool? ?? false;
        final lastSeen = userData['lastSeen'] as int?;
        final lastHeartbeat = userData['lastHeartbeat'] as int?;
        final platform = userData['platform'] as String? ?? 'unknown';
        
        if (isOnline && lastSeen != null && lastSeen >= thresholdTime) {
          onlineUsers.add(OnlineUser(
            userId: userId,
            lastSeen: DateTime.fromMillisecondsSinceEpoch(lastSeen),
            lastHeartbeat: lastHeartbeat != null 
                ? DateTime.fromMillisecondsSinceEpoch(lastHeartbeat) 
                : null,
            platform: platform,
          ));
        }
      }
      
      return onlineUsers;
      
    } catch (e) {
      debugPrint('❌ Online kullanıcı listesi çıkarma hatası: $e');
      return [];
    }
  }

  /// 🧹 Eski presence verilerini temizle
  static Future<void> cleanupOldPresenceData() async {
    try {
      final snapshot = await _presenceRef.get();
      if (!snapshot.exists || snapshot.value == null) return;
      
      final presenceData = snapshot.value as Map<dynamic, dynamic>;
      final now = DateTime.now().millisecondsSinceEpoch;
      final cleanupThreshold = now - const Duration(days: 7).inMilliseconds;
      
      final updates = <String, dynamic>{};
      int cleanupCount = 0;
      
      for (final entry in presenceData.entries) {
        final userId = entry.key as String;
        final userData = entry.value;
        if (userData is! Map<dynamic, dynamic>) continue;
        
        final lastSeen = userData['lastSeen'] as int?;
        if (lastSeen != null && lastSeen < cleanupThreshold) {
          updates['presence/$userId'] = null; // Sil
          cleanupCount++;
        }
      }
      
      if (updates.isNotEmpty) {
        await _database.ref().update(updates);
        debugPrint('🧹 $cleanupCount eski presence verisi temizlendi');
      }
      
    } catch (e) {
      debugPrint('❌ Presence temizleme hatası: $e');
    }
  }

  /// 🌐 Platform bilgisini al
  static String _getPlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  /// 📱 Servis durumu bilgisi
  static Map<String, dynamic> getServiceStatus() {
    return {
      'isInitialized': _isInitialized,
      'currentUserId': _currentUserId,
      'isHeartbeatRunning': _heartbeatTimer?.isActive ?? false,
      'isConnectionListening': _connectionSubscription != null,
      'heartbeatInterval': _heartbeatInterval.inSeconds,
      'onlineThreshold': _onlineThreshold.inMinutes,
    };
  }
}

/// 📱 Online kullanıcı veri modeli
class OnlineUser {
  final String userId;
  final DateTime lastSeen;
  final DateTime? lastHeartbeat;
  final String platform;

  OnlineUser({
    required this.userId,
    required this.lastSeen,
    this.lastHeartbeat,
    required this.platform,
  });

  /// Son aktivite zamanını al (lastHeartbeat veya lastSeen'den en güncel)
  DateTime get lastActivity {
    if (lastHeartbeat == null) return lastSeen;
    return lastHeartbeat!.isAfter(lastSeen) ? lastHeartbeat! : lastSeen;
  }

  /// Kullanıcının ne kadar süredir online olduğunu al
  Duration get timeSinceLastActivity {
    return DateTime.now().difference(lastActivity);
  }

  @override
  String toString() {
    return 'OnlineUser(userId: $userId, lastSeen: $lastSeen, platform: $platform)';
  }
} 