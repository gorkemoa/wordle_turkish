import 'dart:async';
import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'firebase_service.dart';

class AdService {
  static RewardedAd? _rewardedAd;
  static bool _isRewardedAdReady = false;
  static bool _isLoading = false;

  // Test ve gerçek reklam ID'leri
  static String get _rewardedAdUnitId {
    // Geliştirme sırasında test ID'leri kullan
    const bool isDebug = true; // Test reklamlarını kullan - gerçek reklamlar henüz hazır değil
    
    if (isDebug) {
      // Test reklam ID'leri
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/5224354917'; // Android test rewarded ad unit ID
      } else if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/1712485313'; // iOS test rewarded ad unit ID
      }
    } else {
      // Gerçek reklam ID'leri
      if (Platform.isAndroid) {
        return 'app-pub-7601198457132530/6133429357'; // ReklamJetonVideoca (Android)
      } else if (Platform.isIOS) {
        return 'app-pub-7601198457132530/6540623462'; // JetonKazanVideoca (iOS)
      }
    }
    
    throw UnsupportedError('Desteklenmeyen platform');
  }

  /// AdMob'u başlat
  static Future<void> initialize() async {
    try {
      // iOS için App Tracking Transparency izni iste
      if (Platform.isIOS) {
        try {
          final ConsentRequestParameters params = ConsentRequestParameters();
          ConsentInformation.instance.requestConsentInfoUpdate(
            params,
            () async {
              try {
                if (await ConsentInformation.instance.isConsentFormAvailable()) {
                  _loadConsentForm();
                }
              } catch (e) {
                print('Consent form availability check error: $e');
              }
            },
            (FormError error) {
              print('Consent info update error: ${error.errorCode} - ${error.message}');
              // Consent hatası olsa bile AdMob'u başlat
            },
          );
        } catch (e) {
          print('Consent request setup error: $e');
        }
      }
      
      await MobileAds.instance.initialize();
      print('AdMob başlatıldı');
      loadRewardedAd();
    } catch (e) {
      print('AdMob başlatma hatası: $e');
      // Plugin yüklenmemişse sessizce devam et
      return;
    }
  }

  /// iOS için consent form yükle
  static void _loadConsentForm() {
    try {
      ConsentForm.loadConsentForm(
        (ConsentForm consentForm) async {
          try {
            var status = await ConsentInformation.instance.getConsentStatus();
            if (status == ConsentStatus.required) {
              consentForm.show(
                (FormError? formError) {
                  if (formError != null) {
                    print('Consent form show error: ${formError.errorCode} - ${formError.message}');
                  }
                  // Hata olsa bile devam et
                },
              );
            }
          } catch (e) {
            print('Consent status check error: $e');
          }
        },
        (FormError formError) {
          print('Consent form load error: ${formError.errorCode} - ${formError.message}');
          // Form yüklenemese bile AdMob'u devam ettir
        },
      );
    } catch (e) {
      print('Consent form setup error: $e');
    }
  }

  /// Ödüllü reklam yükle
  static void loadRewardedAd() {
    if (_isLoading) return;
    
    _isLoading = true;
    print('DEBUG - Ödüllü reklam yükleniyor...');
    print('DEBUG - Platform: ${Platform.operatingSystem}');
    print('DEBUG - Ad Unit ID: $_rewardedAdUnitId');

    try {
      RewardedAd.load(
        adUnitId: _rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            print('DEBUG - Ödüllü reklam başarıyla yüklendi');
            _rewardedAd = ad;
            _isRewardedAdReady = true;
            _isLoading = false;
            _setFullScreenContentCallback();
          },
          onAdFailedToLoad: (LoadAdError error) {
            print('DEBUG - Ödüllü reklam yükleme hatası:');
            print('  Code: ${error.code}');
            print('  Domain: ${error.domain}');
            print('  Message: ${error.message}');
            print('  Response Info: ${error.responseInfo}');
            _rewardedAd = null;
            _isRewardedAdReady = false;
            _isLoading = false;
            
            // 30 saniye sonra tekrar dene
            Future.delayed(const Duration(seconds: 30), () {
              print('DEBUG - 30 saniye sonra reklam yeniden yüklenecek');
              loadRewardedAd();
            });
          },
        ),
      );
    } catch (e) {
      print('DEBUG - Reklam yükleme exception: $e');
      print('DEBUG - Exception type: ${e.runtimeType}');
      _isLoading = false;
      _isRewardedAdReady = false;
    }
  }

  /// Reklam callback'lerini ayarla
  static void _setFullScreenContentCallback() {
    if (_rewardedAd == null) return;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (RewardedAd ad) {
        print('Ödüllü reklam gösterildi');
      },
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        print('Ödüllü reklam kapatıldı');
        ad.dispose();
        _rewardedAd = null;
        _isRewardedAdReady = false;
        
        // Yeni reklam yükle
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        print('Ödüllü reklam gösterme hatası: $error');
        ad.dispose();
        _rewardedAd = null;
        _isRewardedAdReady = false;
        
        // Yeni reklam yükle
        loadRewardedAd();
      },
    );
  }

  /// Ödüllü reklam göster
  static Future<bool> showRewardedAd(String userId) async {
    if (!_isRewardedAdReady || _rewardedAd == null) {
      print('Ödüllü reklam hazır değil');
      return false;
    }

    try {
      bool rewardEarned = false;
      final completer = Completer<bool>();

      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) async {
          print('Kullanıcı ödül kazandı: ${reward.amount} ${reward.type}');
          rewardEarned = true;
          
          // Firebase'e jeton ekle
          await FirebaseService.earnTokensFromAd(userId);
          
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        },
      );

      // Reklam kapanmasını bekle
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (RewardedAd ad) {
          print('Ödüllü reklam gösterildi');
        },
        onAdDismissedFullScreenContent: (RewardedAd ad) {
          print('Ödüllü reklam kapatıldı');
          ad.dispose();
          _rewardedAd = null;
          _isRewardedAdReady = false;
          
          if (!completer.isCompleted) {
            completer.complete(rewardEarned);
          }
          
          // Yeni reklam yükle
          loadRewardedAd();
        },
        onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
          print('Ödüllü reklam gösterme hatası: $error');
          ad.dispose();
          _rewardedAd = null;
          _isRewardedAdReady = false;
          
          if (!completer.isCompleted) {
            completer.complete(false);
          }
          
          // Yeni reklam yükle
          loadRewardedAd();
        },
      );

      return await completer.future;
    } catch (e) {
      print('Reklam gösterme exception: $e');
      return false;
    }
  }

  /// Reklam hazır mı kontrol et
  static bool isRewardedAdReady() {
    return _isRewardedAdReady && _rewardedAd != null;
  }

  /// Kaynakları temizle
  static void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isRewardedAdReady = false;
  }
} 