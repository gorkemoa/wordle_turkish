import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'firebase_service.dart';

class AdService {
  static RewardedAd? _rewardedAd;
  static bool _isRewardedAdReady = false;
  static bool _isLoading = false;

  // Gerçek reklam ID'leri
  static String get _rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'app-pub-7601198457132530/6133429357'; // ReklamJetonVideoca (Android)
    } else if (Platform.isIOS) {
      return 'app-pub-7601198457132530/6540623462'; // JetonKazanVideoca (iOS)
    }
    throw UnsupportedError('Desteklenmeyen platform');
  }

  /// AdMob'u başlat
  static Future<void> initialize() async {
    try {
      // iOS için App Tracking Transparency izni iste
      if (Platform.isIOS) {
        final ConsentRequestParameters params = ConsentRequestParameters();
        ConsentInformation.instance.requestConsentInfoUpdate(
          params,
          () async {
            if (await ConsentInformation.instance.isConsentFormAvailable()) {
              _loadConsentForm();
            }
          },
          (FormError error) {
            print('Consent form error: $error');
          },
        );
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
    ConsentForm.loadConsentForm(
      (ConsentForm consentForm) async {
        var status = await ConsentInformation.instance.getConsentStatus();
        if (status == ConsentStatus.required) {
          consentForm.show(
            (FormError? formError) {
              _loadConsentForm();
            },
          );
        }
      },
      (FormError formError) {
        print('Consent form load error: $formError');
      },
    );
  }

  /// Ödüllü reklam yükle
  static void loadRewardedAd() {
    if (_isLoading) return;
    
    _isLoading = true;
    print('Ödüllü reklam yükleniyor...');

    try {
      RewardedAd.load(
        adUnitId: _rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            print('Ödüllü reklam yüklendi');
            _rewardedAd = ad;
            _isRewardedAdReady = true;
            _isLoading = false;
            _setFullScreenContentCallback();
          },
          onAdFailedToLoad: (LoadAdError error) {
            print('Ödüllü reklam yükleme hatası: $error');
            _rewardedAd = null;
            _isRewardedAdReady = false;
            _isLoading = false;
            
            // 30 saniye sonra tekrar dene
            Future.delayed(const Duration(seconds: 30), () {
              loadRewardedAd();
            });
          },
        ),
      );
    } catch (e) {
      print('Reklam yükleme exception: $e');
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

      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) async {
          print('Kullanıcı ödül kazandı: ${reward.amount} ${reward.type}');
          rewardEarned = true;
          
          // Firebase'e jeton ekle
          await FirebaseService.earnTokensFromAd(userId);
        },
      );

      return rewardEarned;
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