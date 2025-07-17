import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../services/firebase_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  bool _isConnecting = false;
  String _statusMessage = '';
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _autoSignIn();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuart,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _autoSignIn() async {
    setState(() {
      _isConnecting = true;
      _statusMessage = 'Oyun merkezine bağlanılıyor...';
    });

    await Future.delayed(const Duration(milliseconds: 500));

    try {
      if (Platform.isIOS) {
        // iOS için Firebase Game Center Auth kullan
        await _signInWithGameCenter();
      } else {
        // Android için Google Sign-In
        await _signInWithGoogle();
      }
    } catch (e) {
      debugPrint('❌ Platform authentication failed: $e');
      setState(() {
        _statusMessage = 'Misafir modunda devam ediliyor...';
      });
      await Future.delayed(const Duration(milliseconds: 1000));
      _showGuestLoginDialog();
    }
  }

  /// iOS Game Center Authentication (Firebase ile entee)
  Future<void> _signInWithGameCenter() async {
    try {
      setState(() {
        _statusMessage = 'Game Center\'a bağlanılıyor...';
      });

      debugPrint('🎮 iOS Game Center + Firebase authentication başlatılıyor...');

      // Firebase service üzerinden Game Center authentication
      final user = await FirebaseService.signInWithGameCenter();
      
      if (user != null && mounted) {
        setState(() {
          _statusMessage = 'Hoş geldiniz, ${user.displayName ?? "Game Center Oyuncusu"}!';
        });
        
        await Future.delayed(const Duration(milliseconds: 1500));
        // ignore: use_build_context_synchronously
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        throw Exception('Game Center girişi iptal edildi');
      }
    } catch (e) {
      debugPrint('❌ iOS Game Center authentication error: $e');
      rethrow;
    }
  }

  /// Android Google Sign-In
  Future<void> _signInWithGoogle() async {
    try {
      setState(() {
        _statusMessage = 'Google Play Games\'e bağlanılıyor...';
      });

      final user = await FirebaseService.signInWithGoogle();
      
      if (user != null && mounted) {
        setState(() {
          _statusMessage = 'Hoş geldiniz, ${user.displayName ?? "Oyuncu"}!';
        });
        
        await Future.delayed(const Duration(milliseconds: 1500));
        // ignore: use_build_context_synchronously
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        throw Exception('Google giriş iptal edildi');
      }
    } catch (e) {
      debugPrint('❌ Google Sign-In error: $e');
      rethrow;
    }
  }



  Future<void> _showGuestLoginDialog() async {
    setState(() {
      _isConnecting = false;
      _statusMessage = '';
    });

    final playerName = await _showPlayerNameDialog();
    
    if (playerName == null) {
      // Kullanıcı iptal etti, tekrar dene
      _autoSignIn();
      return;
    }

    await _signInAsGuest(playerName);
  }

  Future<String?> _showPlayerNameDialog() async {
    final nameController = TextEditingController();
    
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.games, color: Colors.blue.shade600),
              const SizedBox(width: 10),
              const Text(
                'Oyuncu Adınız',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Platform.isIOS 
                  ? 'Game Center bağlantısı kurulamadı. Misafir olarak devam etmek için oyuncu adınızı girin.'
                  : 'Google Play Games bağlantısı kurulamadı. Misafir olarak devam etmek için oyuncu adınızı girin.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: nameController,
                maxLength: 20,
                decoration: InputDecoration(
                  labelText: 'Oyuncu Adı',
                  hintText: 'Örn: ProOyuncu123',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                onFieldSubmitted: (value) {
                  if (value.trim().isNotEmpty && value.trim().length >= 2) {
                    Navigator.of(context).pop(value.trim());
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tekrar Dene'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  _showError('Oyuncu adı boş olamaz!');
                  return;
                }
                if (name.length < 2) {
                  _showError('Oyuncu adı en az 2 karakter olmalı!');
                  return;
                }
                
                // Benzersizlik kontrolü
                try {
                  final existingUsers = await FirebaseFirestore.instance
                      .collection('users')
                      .where('displayName', isEqualTo: name)
                      .get();
                  
                  if (existingUsers.docs.isNotEmpty) {
                    _showError('Bu oyuncu adı zaten kullanımda! Farklı bir isim deneyin.');
                    return;
                  }
                  
                  // ignore: use_build_context_synchronously
                  Navigator.of(context).pop(name);
                } catch (e) {
                  _showError('Kontrol hatası: $e');
                }
              },
              child: const Text(
                'Devam Et',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _signInAsGuest(String playerName) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Misafir profili oluşturuluyor...';
    });

    try {
      final user = await FirebaseService.signInAnonymously(playerName);
      
      if (user != null && mounted) {
        setState(() {
          _statusMessage = 'Hoş geldiniz, $playerName!';
        });
        
        await Future.delayed(const Duration(milliseconds: 1500));
        // ignore: use_build_context_synchronously
        Navigator.of(context).pushReplacementNamed('/home');
      } else if (mounted) {
        _showError('Misafir girişi başarısız!');
        _showGuestLoginDialog();
      }
    } catch (e) {
      if (mounted) {
        _showError('Giriş hatası: $e');
        _showGuestLoginDialog();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = '';
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.9),
                              Colors.white.withValues(alpha: 0.7),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.games,
                          color: Color(0xFF667eea),
                          size: 60,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Başlık
                    const Text(
                      'Türkçe Wordle',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            offset: Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    Text(
                      Platform.isIOS 
                        ? 'Firebase Game Center ile güvenli giriş'
                        : 'Google Play Games ile güvenli giriş',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.4,
                      ),
                    ),
                    
                    const SizedBox(height: 60),
                    
                    // Loading ve Status
                    if (_isConnecting || _isLoading) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              strokeWidth: 3,
                            ),
                            if (_statusMessage.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text(
                                _statusMessage,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 40),
                    
                    // Platform bilgisi
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        // ignore: deprecated_member_use
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          // ignore: deprecated_member_use
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Platform.isIOS ? Icons.apple : Icons.android,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            Platform.isIOS ? 'Firebase Game Center' : 'Google Play Games',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 