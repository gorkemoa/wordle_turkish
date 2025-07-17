# 🧪 Çakışmasız Düello Eşleşme Sistemi - Test Cases

## 📋 Test Kategorileri

### 1. 🎯 Kuyruk İşlemleri (Queue Operations)

#### 1.1 Normal Senaryolar
- ✅ **TC001**: Kullanıcı başarıyla kuyruğa eklenir
- ✅ **TC002**: Kullanıcı başarıyla kuyruktan çıkar
- ✅ **TC003**: Kuyrukta bekleyen kullanıcı timeout sonrası otomatik çıkartılır
- ✅ **TC004**: İki kullanıcı aynı anda kuyruğa eklenir ve eşleşir

#### 1.2 Hatalı Senaryolar
- ❌ **TC005**: Zaten kuyrukta olan kullanıcı tekrar kuyruğa eklenmeye çalışır
- ❌ **TC006**: Oturum açmamış kullanıcı kuyruğa eklenmeye çalışır
- ❌ **TC007**: Yetersiz jeton ile kuyruk ekleme
- ❌ **TC008**: Network bağlantısı kesildiğinde kuyruk durumu
- ❌ **TC009**: Firebase transaction timeout durumu
- ❌ **TC010**: Aynı kullanıcı çoklu cihazdan kuyruğa ekleme

### 2. ⚡ Çakışma Senaryoları (Race Conditions)

#### 2.1 Eşzamanlı Kullanıcı Eşleşmeleri
- 🏁 **TC011**: 4 kullanıcı aynı anda kuyruğa eklenir, sadece 2 eşleşme oluşur
- 🏁 **TC012**: 2 kullanıcı aynı millisaniyede eşleşmeye çalışır
- 🏁 **TC013**: Kullanıcı A, B ile eşleşirken C de aynı anda B ile eşleşmeye çalışır
- 🏁 **TC014**: Eşleşme transaction sırasında kullanıcılardan biri çıkar

#### 2.2 Database Transaction Testleri
- 🔄 **TC015**: Transaction abort durumunda rollback kontrolü
- 🔄 **TC016**: Concurrent transaction'lar arasında data consistency
- 🔄 **TC017**: Transaction timeout durumunda retry mekanizması

### 3. 🌐 Network ve Bağlantı Testleri

#### 3.1 Bağlantı Kopma Senaryoları
- 📡 **TC018**: Kuyrukta beklerken internet bağlantısı kesilir
- 📡 **TC019**: Eşleşme sırasında bağlantı kesilir
- 📡 **TC020**: Oyun sırasında rakip bağlantısı kesilir
- 📡 **TC021**: onDisconnect handler'ların doğru çalışması

#### 3.2 Firebase Realtime Database Testleri
- 🔥 **TC022**: Firebase rules ile unauthorized access
- 🔥 **TC023**: Invalid data format ile write attempt
- 🔥 **TC024**: Database quota limit testleri
- 🔥 **TC025**: Multi-region latency testleri

### 4. 📊 State Management Testleri

#### 4.1 UI State Consistency
- 📱 **TC026**: GameState transitions doğru sırada
- 📱 **TC027**: ViewModel dispose sonrası cleanup kontrolü
- 📱 **TC028**: Provider context değişimleri
- 📱 **TC029**: Widget rebuild optimizasyonu

#### 4.2 Data Synchronization
- 🔄 **TC030**: Server ve client state sync
- 🔄 **TC031**: Cache invalidation scenarios
- 🔄 **TC032**: Optimistic update failures

### 5. 💰 Jeton ve İzin Testleri

#### 5.1 Jeton İşlemleri
- 🪙 **TC033**: Yetersiz jeton ile oyun başlatma
- 🪙 **TC034**: Jeton kesimi sırasında hata
- 🪙 **TC035**: Double spending prevention
- 🪙 **TC036**: Jeton restore işlemleri

#### 5.2 Firebase Security Rules
- 🔒 **TC037**: Kullanıcı başkasının queue entry'sine write
- 🔒 **TC038**: Unauthorized match creation
- 🔒 **TC039**: Invalid data validation
- 🔒 **TC040**: Admin-only operations

### 6. ⏱️ Timeout ve Retry Testleri

#### 6.1 Timeout Scenarios
- ⏰ **TC041**: Queue timeout (30 saniye)
- ⏰ **TC042**: Match creation timeout
- ⏰ **TC043**: Game start timeout
- ⏰ **TC044**: Opponent response timeout

#### 6.2 Retry Mechanisms
- 🔄 **TC045**: Failed enqueue retry (3 attempts)
- 🔄 **TC046**: Match attempt retry logic
- 🔄 **TC047**: Network failure retry
- 🔄 **TC048**: Exponential backoff implementation

---

## 🔬 Detaylı Test Senaryoları

### TC011: 4 Kullanıcı Eşzamanlı Kuyruğa Ekleme

```dart
test('4 users enqueue simultaneously - only 2 matches created', () async {
  // Arrange
  final users = ['user1', 'user2', 'user3', 'user4'];
  final futures = <Future>[];
  
  // Act
  for (final user in users) {
    futures.add(matchmakingService.enqueue(
      displayName: user,
      avatar: '👤',
    ));
  }
  
  final results = await Future.wait(futures);
  
  // Assert
  final successCount = results.where((r) => r.isSuccess).length;
  expect(successCount, equals(4)); // Tüm kullanıcılar kuyruğa eklendi
  
  // Wait for matchmaking
  await Future.delayed(Duration(seconds: 2));
  
  final activeMatches = await getActiveMatchesCount();
  expect(activeMatches, equals(2)); // Sadece 2 eşleşme oluştu
  
  final remainingInQueue = await getQueueCount();
  expect(remainingInQueue, equals(0)); // Kuyruk temizlendi
});
```

### TC013: Çakışma Durumu - Aynı Rakiple Eşleşme

```dart
test('User A matches with B while C tries to match with B', () async {
  // Arrange
  await addToQueue('userA');
  await addToQueue('userB');
  await addToQueue('userC');
  
  // Act - Aynı anda eşleşme denemesi
  final futureA = matchmakingService.findMatch('userA');
  final futureC = matchmakingService.findMatch('userC');
  
  final results = await Future.wait([futureA, futureC]);
  
  // Assert
  final successResults = results.where((r) => r.isSuccess).toList();
  expect(successResults.length, equals(1)); // Sadece bir eşleşme başarılı
  
  // Verify database consistency
  final matches = await getAllMatches();
  expect(matches.length, equals(1));
  
  final match = matches.first;
  expect(match.players.length, equals(2));
  expect(match.players.keys, contains('userB')); // userB bir eşleşmede
});
```

### TC018: Bağlantı Kopma Sırasında Cleanup

```dart
test('Internet disconnection during queue - proper cleanup', () async {
  // Arrange
  await matchmakingService.enqueue(
    displayName: 'TestUser',
    avatar: '👤',
  );
  
  // Verify user is in queue
  final inQueueBefore = await isUserInQueue('testUserId');
  expect(inQueueBefore, isTrue);
  
  // Act - Simulate disconnect
  await simulateNetworkDisconnect();
  
  // Wait for onDisconnect handlers
  await Future.delayed(Duration(seconds: 5));
  
  // Assert
  final inQueueAfter = await isUserInQueue('testUserId');
  expect(inQueueAfter, isFalse);
  
  final userStatus = await getUserStatus('testUserId');
  expect(userStatus.status, equals(UserStatus.disconnected));
});
```

---

## 🏗️ Test Implementation Framework

### Test Utilities

```dart
class MatchmakingTestUtils {
  static Future<void> setupFirebaseEmulator() async {
    await Firebase.initializeApp();
    FirebaseDatabase.instance.useDatabaseEmulator('localhost', 9000);
  }
  
  static Future<void> clearDatabase() async {
    await FirebaseDatabase.instance.ref().remove();
  }
  
  static Future<void> createTestUser(String userId) async {
    await FirebaseDatabase.instance
        .ref('userStatus/$userId')
        .set({
          'status': 'online',
          'lastSeen': ServerValue.timestamp,
        });
  }
  
  static Future<int> getQueueCount() async {
    final snapshot = await FirebaseDatabase.instance.ref('queue').get();
    return snapshot.exists ? (snapshot.value as Map).length : 0;
  }
  
  static Future<int> getActiveMatchesCount() async {
    final snapshot = await FirebaseDatabase.instance.ref('matches').get();
    if (!snapshot.exists) return 0;
    
    final matches = snapshot.value as Map;
    return matches.values
        .where((match) => (match as Map)['status'] == 'active')
        .length;
  }
}
```

### Integration Test Example

```dart
void main() {
  group('Matchmaking Integration Tests', () {
    setUpAll(() async {
      await MatchmakingTestUtils.setupFirebaseEmulator();
    });
    
    setUp(() async {
      await MatchmakingTestUtils.clearDatabase();
    });
    
    testWidgets('Full matchmaking flow', (WidgetTester tester) async {
      // Test implementation
    });
  });
}
```

---

## 📈 Performance Test Scenarios

### Load Testing
- **PT001**: 100 kullanıcı aynı anda kuyruğa ekleme
- **PT002**: 1000 eşleşme/saniye capacity testi
- **PT003**: Database connection pool limits
- **PT004**: Memory usage during peak load

### Stress Testing
- **ST001**: Firebase quota limit testleri
- **ST002**: Network bandwidth limitations
- **ST003**: Device memory pressure
- **ST004**: Background app state transitions

---

## 🔧 Mock ve Stub Strategies

### Firebase Mocks
```dart
class MockFirebaseDatabase extends Mock implements FirebaseDatabase {
  @override
  DatabaseReference ref([String? path]) {
    return MockDatabaseReference();
  }
}

class MockDatabaseReference extends Mock implements DatabaseReference {
  final Map<String, dynamic> _data = {};
  
  @override
  Future<TransactionResult> runTransaction(
    TransactionHandler transactionHandler
  ) async {
    // Simulate transaction logic
    final result = transactionHandler(_data);
    if (result is Transaction) {
      return TransactionResult(
        committed: result.success,
        snapshot: MockDataSnapshot(),
      );
    }
    return TransactionResult(committed: false, snapshot: MockDataSnapshot());
  }
}
```

---

## 📋 Test Checklist

### Pre-Test Setup ✅
- [ ] Firebase emulator setup
- [ ] Test user accounts created
- [ ] Database rules deployed
- [ ] Network simulation tools ready

### During Testing ✅
- [ ] All race conditions tested
- [ ] Network failure scenarios covered
- [ ] Security rules validated
- [ ] Performance metrics collected

### Post-Test Validation ✅
- [ ] Database consistency verified
- [ ] Memory leaks checked
- [ ] Error logs analyzed
- [ ] Performance benchmarks met

---

## 🚨 Critical Test Scenarios

### Must-Pass Tests
1. **Çakışmasız Eşleşme**: Aynı anda 10+ kullanıcı
2. **Bağlantı Kopma**: onDisconnect cleanup
3. **Security Rules**: Unauthorized access prevention
4. **State Consistency**: UI ve server sync
5. **Resource Cleanup**: Memory ve listener management

### Performance Benchmarks
- Queue response time: < 100ms
- Match creation: < 500ms
- Database consistency: 99.9%
- Memory usage: < 50MB per user
- Network efficiency: < 10KB per operation

Bu test suite'i, çakışmasız düello eşleşme sisteminin güvenilirliğini ve performansını garanti eder. 