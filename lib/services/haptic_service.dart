import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

class HapticService {
  static const String _hapticEnabledKey = 'haptic_enabled';
  static bool _isHapticEnabled = true;

  // Titreşim ayarını yükle
  static Future<void> loadHapticSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isHapticEnabled = prefs.getBool(_hapticEnabledKey) ?? true;
  }

  // Titreşim ayarını kaydet
  static Future<void> setHapticEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticEnabledKey, enabled);
    _isHapticEnabled = enabled;
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
    await setHapticEnabled(!_isHapticEnabled);
  }
} 