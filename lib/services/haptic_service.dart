import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class HapticService {
  static const String _hapticEnabledKey = 'haptic_enabled';
  static bool _isHapticEnabled = true;

  static final ValueNotifier<bool> hapticEnabledNotifier = ValueNotifier(_isHapticEnabled);

  // Titreşim ayarını yükle
  static Future<void> loadHapticSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isHapticEnabled = prefs.getBool(_hapticEnabledKey) ?? true;
      hapticEnabledNotifier.value = _isHapticEnabled;
    } catch (e) {
      debugPrint('Titreşim ayarları yüklenemedi: $e');
      _isHapticEnabled = true; // Hata durumunda varsayılan olarak aç
      hapticEnabledNotifier.value = true;
    }
  }

  // Titreşim ayarını kaydet
  static Future<void> setHapticEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticEnabledKey, enabled);
    _isHapticEnabled = enabled;
    hapticEnabledNotifier.value = _isHapticEnabled;
  }

  // Titreşim durumunu al
  static bool get isHapticEnabled => _isHapticEnabled;

  // Hata titreşimi (yanlış kelime)
  static void triggerErrorHaptic() {
    if (!_isHapticEnabled) return;
    
    try {
      if (Platform.isIOS) {
        // iOS için çoklu darbe
        HapticFeedback.mediumImpact();
        Future.delayed(const Duration(milliseconds: 100), () {
          HapticFeedback.mediumImpact();
        });
      } else {
        // Android için güçlü titreşim
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      print('Haptic feedback desteklenmiyor: $e');
    }
  }

  // Hafif titreşim (buton dokunma)
  static void triggerLightHaptic() {
    if (!_isHapticEnabled) return;
    
    try {
      HapticFeedback.lightImpact();
    } catch (e) {
      print('Haptic feedback desteklenmiyor: $e');
    }
  }

  // Orta titreşim (önemli aksiyonlar)
  static void triggerMediumHaptic() {
    if (!_isHapticEnabled) return;
    
    try {
      HapticFeedback.mediumImpact();
    } catch (e) {
      print('Haptic feedback desteklenmiyor: $e');
    }
  }

  // Ayar değiştirme 
  static Future<void> toggleHapticSetting() async {
    _isHapticEnabled = !_isHapticEnabled;
    hapticEnabledNotifier.value = _isHapticEnabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hapticEnabledKey, _isHapticEnabled);
      // Ayar değiştiğinde hafif bir titreşimle geri bildirim ver
      if (_isHapticEnabled) {
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      debugPrint('Titreşim ayarı kaydedilemedi: $e');
    }
  }
} 