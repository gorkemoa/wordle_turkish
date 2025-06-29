import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import '../services/avatar_service.dart';
import '../services/haptic_service.dart';
import '../widgets/avatar_selector.dart';

// Profil sayfası

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? userStats;
  bool isLoading = true;
  
  // Responsive boyutlar için getter'lar
  late double _screenWidth;
  late double _screenHeight;

  @override
  void initState() {
    super.initState();
    _loadUserStats();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calculateResponsiveSizes();
  }

  void _calculateResponsiveSizes() {
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;
  }

  // Responsive font boyutu hesaplama
  double _getResponsiveFontSize(double baseSize) {
    return baseSize * (_screenWidth / 375); // iPhone 6/7/8 baz alınarak
  }

  // Responsive padding hesaplama
  EdgeInsets _getResponsivePadding({
    double horizontal = 16.0,
    double vertical = 12.0,
  }) {
    return EdgeInsets.symmetric(
      horizontal: (horizontal * (_screenWidth / 375)).clamp(8.0, 24.0),
      vertical: (vertical * (_screenHeight / 667)).clamp(6.0, 18.0),
    );
  }

  Future<void> _loadUserStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final stats = await FirebaseService.getUserProfile(user.uid);
      setState(() {
        userStats = stats;
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off, size: _getResponsiveFontSize(64), color: Colors.grey),
              SizedBox(height: _screenHeight * 0.02),
              Text(
                'Kullanıcı bulunamadı',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _getResponsiveFontSize(16),
                ),
              ),
              SizedBox(height: _screenHeight * 0.02),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF538D4E),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Geri Dön'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            
            // Content
            Expanded(
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: const Color(0xFF538D4E),
                        strokeWidth: _screenWidth * 0.01,
                      ),
                    )
                  : _buildProfileContent(user),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(_screenWidth * 0.05),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2A2A2D),
            const Color(0xFF1A1A1D),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(_screenWidth * 0.08),
          bottomRight: Radius.circular(_screenWidth * 0.08),
        ),
        border: Border.all(color: const Color(0xFF538D4E), width: 1),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticService.triggerLightHaptic();
              Navigator.of(context).pop();
            },
            child: Container(
              padding: EdgeInsets.all(_screenWidth * 0.025),
              decoration: BoxDecoration(
                color: const Color(0xFF538D4E).withOpacity(0.2),
                borderRadius: BorderRadius.circular(_screenWidth * 0.03),
                border: Border.all(color: const Color(0xFF538D4E), width: 1),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: _getResponsiveFontSize(20),
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Profilim',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: _getResponsiveFontSize(24),
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          SizedBox(width: _screenWidth * 0.12), // Balance için
        ],
      ),
    );
  }

  Widget _buildProfileContent(User user) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(_screenWidth * 0.06),
      child: Column(
        children: [
          // Avatar ve temel bilgiler
          _buildAvatarSection(user),
          SizedBox(height: _screenHeight * 0.04),
          
          // Profil bilgileri kartları
          _buildInfoCards(user),
          SizedBox(height: _screenHeight * 0.04),
          
          // İstatistikler
          if (userStats != null) _buildStatsSection(),
          SizedBox(height: _screenHeight * 0.04),
          
          // Çıkış yap butonu
          _buildSignOutButton(),
          SizedBox(height: _screenHeight * 0.03),
        ],
      ),
    );
  }

  Widget _buildAvatarSection(User user) {
    return Column(
      children: [
        FutureBuilder<String?>(
          future: FirebaseService.getUserAvatar(user.uid),
          builder: (context, snapshot) {
            final userAvatar = snapshot.data ?? AvatarService.generateAvatar(user.uid);
            
            return GestureDetector(
              onTap: () async {
                HapticService.triggerMediumHaptic();
                final newAvatar = await showAvatarSelector(
                  context: context,
                  currentAvatar: userAvatar,
                );
                
                if (newAvatar != null) {
                  final success = await FirebaseService.updateUserAvatar(user.uid, newAvatar);
                  if (success && mounted) {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Avatar güncellendi!'),
                        backgroundColor: const Color(0xFF538D4E),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_screenWidth * 0.03),
                        ),
                      ),
                    );
                  }
                }
              },
              child: Stack(
                children: [
                  Container(
                    width: _screenWidth * 0.3,
                    height: _screenWidth * 0.3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF538D4E),
                          const Color(0xFF6AAA64),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(_screenWidth * 0.15),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF538D4E).withOpacity(0.4),
                          blurRadius: _screenWidth * 0.05,
                          offset: Offset(0, _screenHeight * 0.01),
                        ),
                      ],
                    ),
                    child: Container(
                      margin: EdgeInsets.all(_screenWidth * 0.01),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF2A2A2D),
                            const Color(0xFF1A1A1D),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(_screenWidth * 0.14),
                      ),
                      child: Center(
                        child: Text(
                          userAvatar,
                          style: TextStyle(fontSize: _getResponsiveFontSize(50)),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: _screenWidth * 0.01,
                    right: _screenWidth * 0.01,
                    child: Container(
                      width: _screenWidth * 0.09,
                      height: _screenWidth * 0.09,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF538D4E),
                            const Color(0xFF6AAA64),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(_screenWidth * 0.045),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: _screenWidth * 0.02,
                            offset: Offset(0, _screenHeight * 0.005),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.edit,
                        size: _getResponsiveFontSize(18),
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        SizedBox(height: _screenHeight * 0.02),
        Text(
          userStats?['displayName'] ?? user.displayName ?? 'Oyuncu',
          style: TextStyle(
            fontSize: _getResponsiveFontSize(24),
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: _screenHeight * 0.01),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: _screenWidth * 0.03,
            vertical: _screenHeight * 0.008,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: user.isAnonymous
                  ? [Colors.orange.shade600, Colors.red.shade600]
                  : [const Color(0xFF538D4E), const Color(0xFF6AAA64)],
            ),
            borderRadius: BorderRadius.circular(_screenWidth * 0.05),
          ),
          child: Text(
            user.isAnonymous ? '🎮 Misafir Oyuncu' : '⭐ Kayıtlı Oyuncu',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: _getResponsiveFontSize(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCards(User user) {
    return Column(
      children: [
        if (user.isAnonymous)
          _buildEditableInfoCard(
            icon: Icons.person,
            title: 'İsim',
            value: userStats?['displayName'] ?? user.displayName ?? 'Oyuncu',
            isEditable: true,
            onEdit: () => _showEditNameDialog(user),
          )
        else
          _buildInfoCard(
            icon: Icons.person,
            title: 'İsim',
            value: userStats?['displayName'] ?? user.displayName ?? 'Oyuncu',
          ),
        SizedBox(height: _screenHeight * 0.02),
        _buildInfoCard(
          icon: Icons.email,
          title: 'E-posta',
          value: user.email ?? 'Belirtilmemiş',
        ),
        SizedBox(height: _screenHeight * 0.02),
        _buildInfoCard(
          icon: Icons.verified_user,
          title: 'Hesap Türü',
          value: user.isAnonymous ? 'Misafir Hesap' : 'Kayıtlı Hesap',
        ),
        SizedBox(height: _screenHeight * 0.02),
        _buildHapticToggleCard(),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: _getResponsivePadding(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2A2A2D),
            const Color(0xFF1A1A1D),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(_screenWidth * 0.04),
        border: Border.all(color: const Color(0xFF538D4E), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: _screenWidth * 0.02,
            offset: Offset(0, _screenHeight * 0.005),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: _screenWidth * 0.12,
            height: _screenWidth * 0.12,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF538D4E),
                  const Color(0xFF6AAA64),
                ],
              ),
              borderRadius: BorderRadius.circular(_screenWidth * 0.03),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: _getResponsiveFontSize(24),
            ),
          ),
          SizedBox(width: _screenWidth * 0.04),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(14),
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: _screenHeight * 0.005),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(16),
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required bool isEditable,
    required VoidCallback onEdit,
  }) {
    return Container(
      padding: _getResponsivePadding(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2A2A2D),
            const Color(0xFF1A1A1D),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(_screenWidth * 0.04),
        border: Border.all(color: const Color(0xFF538D4E), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: _screenWidth * 0.02,
            offset: Offset(0, _screenHeight * 0.005),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: _screenWidth * 0.12,
            height: _screenWidth * 0.12,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF538D4E),
                  const Color(0xFF6AAA64),
                ],
              ),
              borderRadius: BorderRadius.circular(_screenWidth * 0.03),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: _getResponsiveFontSize(24),
            ),
          ),
          SizedBox(width: _screenWidth * 0.04),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(14),
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: _screenHeight * 0.005),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(16),
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          if (isEditable)
            GestureDetector(
              onTap: () {
                HapticService.triggerLightHaptic();
                onEdit();
              },
              child: Container(
                padding: EdgeInsets.all(_screenWidth * 0.02),
                decoration: BoxDecoration(
                  color: const Color(0xFF538D4E).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(_screenWidth * 0.02),
                  border: Border.all(color: const Color(0xFF538D4E), width: 1),
                ),
                child: Icon(
                  Icons.edit,
                  size: _getResponsiveFontSize(18),
                  color: const Color(0xFF538D4E),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '📊 Oyun İstatistiklerin',
          style: TextStyle(
            fontSize: _getResponsiveFontSize(20),
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: _screenHeight * 0.02),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Seviye',
                value: userStats!['level']?.toString() ?? '1',
                icon: '🏆',
                color: const Color(0xFFFFD700),
              ),
            ),
            SizedBox(width: _screenWidth * 0.03),
            Expanded(
              child: _buildStatCard(
                title: 'Toplam Oyun',
                value: userStats!['gamesPlayed']?.toString() ?? '0',
                icon: '🎮',
                color: const Color(0xFF3498DB),
              ),
            ),
          ],
        ),
        SizedBox(height: _screenHeight * 0.015),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Kazanma Serisi',
                value: userStats!['currentStreak']?.toString() ?? '0',
                icon: '🔥',
                color: const Color(0xFFFF6B35),
              ),
            ),
            SizedBox(width: _screenWidth * 0.03),
            Expanded(
              child: _buildStatCard(
                title: 'En İyi Seri',
                value: userStats!['bestStreak']?.toString() ?? '0',
                icon: '⭐',
                color: const Color(0xFF538D4E),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String icon,
    required Color color,
  }) {
    return Container(
      padding: _getResponsivePadding(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2A2A2D),
            const Color(0xFF1A1A1D),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(_screenWidth * 0.04),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: _screenWidth * 0.02,
            offset: Offset(0, _screenHeight * 0.005),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            icon,
            style: TextStyle(fontSize: _getResponsiveFontSize(24)),
          ),
          SizedBox(height: _screenHeight * 0.01),
          Text(
            value,
            style: TextStyle(
              fontSize: _getResponsiveFontSize(20),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: _screenHeight * 0.005),
          Text(
            title,
            style: TextStyle(
              fontSize: _getResponsiveFontSize(12),
              color: Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutButton() {
    return Container(
      width: double.infinity,
      height: _screenHeight * 0.07,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.shade700,
            Colors.red.shade900,
          ],
        ),
        borderRadius: BorderRadius.circular(_screenWidth * 0.04),
        border: Border.all(color: Colors.red.shade600, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.red.shade700.withOpacity(0.3),
            blurRadius: _screenWidth * 0.03,
            offset: Offset(0, _screenHeight * 0.006),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          HapticService.triggerMediumHaptic();
          _showSignOutDialog();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_screenWidth * 0.04),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.logout,
              color: Colors.white,
              size: _getResponsiveFontSize(20),
            ),
            SizedBox(width: _screenWidth * 0.02),
            Text(
              'Çıkış Yap',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(16),
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditNameDialog(User user) {
    final currentName = userStats?['displayName'] ?? user.displayName ?? '';
    final controller = TextEditingController(text: currentName);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_screenWidth * 0.04),
          side: BorderSide(color: const Color(0xFF538D4E), width: 2),
        ),
        title: Text(
          'İsim Değiştir',
          style: TextStyle(
            color: Colors.white,
            fontSize: _getResponsiveFontSize(18),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Yeni kullanıcı adınızı girin (2-20 karakter)',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(14),
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            SizedBox(height: _screenHeight * 0.02),
            TextField(
              controller: controller,
              maxLength: 20,
              style: TextStyle(
                color: Colors.white,
                fontSize: _getResponsiveFontSize(16),
              ),
              decoration: InputDecoration(
                labelText: 'Kullanıcı Adı',
                labelStyle: TextStyle(color: const Color(0xFF538D4E)),
                hintText: 'Örn: OyuncuAdım',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: const Color(0xFF538D4E)),
                  borderRadius: BorderRadius.circular(_screenWidth * 0.02),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: const Color(0xFF6AAA64), width: 2),
                  borderRadius: BorderRadius.circular(_screenWidth * 0.02),
                ),
                counterStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'İptal',
              style: TextStyle(
                color: Colors.grey,
                fontSize: _getResponsiveFontSize(16),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Kullanıcı adı boş olamaz!'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_screenWidth * 0.03),
                    ),
                  ),
                );
                return;
              }
              if (newName.length < 2) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Kullanıcı adı en az 2 karakter olmalı!'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_screenWidth * 0.03),
                    ),
                  ),
                );
                return;
              }
              
              // ASCII karakter kontrolü
              if (!_isValidAsciiUsername(newName)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Kullanıcı adı sadece İngilizce harfler, rakamlar ve temel özel karakterler (_.-) içerebilir!'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 4),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_screenWidth * 0.03),
                    ),
                  ),
                );
                return;
              }
              
              // Hem Firebase Auth hem de Firestore'u güncelle
              try {
                final success = await FirebaseService.updateUserDisplayName(user.uid, newName);
                
                if (success && mounted) {
                  await user.updateDisplayName(newName);
                  Navigator.pop(context);
                  await _loadUserStats(); // Verileri yeniden yükle
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('İsim başarıyla güncellendi!'),
                      backgroundColor: const Color(0xFF538D4E),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_screenWidth * 0.03),
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Bu kullanıcı adı zaten kullanımda! Lütfen farklı bir isim deneyin.'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 4),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_screenWidth * 0.03),
                      ),
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Hata: $e'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_screenWidth * 0.03),
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF538D4E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_screenWidth * 0.02),
              ),
            ),
            child: Text(
              'Kaydet',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(16),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_screenWidth * 0.04),
          side: BorderSide(color: Colors.red.shade400, width: 2),
        ),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.red.shade400,
              size: _getResponsiveFontSize(24),
            ),
            SizedBox(width: _screenWidth * 0.02),
            Text(
              'Çıkış Yap',
              style: TextStyle(
                color: Colors.white,
                fontSize: _getResponsiveFontSize(18),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Hesabınızdan çıkmak istediğinizden emin misiniz?',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: _getResponsiveFontSize(16),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'İptal',
              style: TextStyle(
                color: Colors.grey,
                fontSize: _getResponsiveFontSize(16),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseService.signOut();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_screenWidth * 0.02),
              ),
            ),
            child: Text(
              'Çıkış Yap',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(16),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHapticToggleCard() {
    return ValueListenableBuilder<bool>(
      valueListenable: HapticService.hapticEnabledNotifier,
      builder: (context, isEnabled, child) {
        return Container(
          padding: _getResponsivePadding(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF2A2A2D),
                const Color(0xFF1A1A1D),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(_screenWidth * 0.04),
            border: Border.all(
              color: isEnabled ? const Color(0xFF538D4E) : Colors.grey.shade600,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: _screenWidth * 0.02,
                offset: Offset(0, _screenHeight * 0.005),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: _screenWidth * 0.12,
                height: _screenWidth * 0.12,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isEnabled
                        ? [const Color(0xFF538D4E), const Color(0xFF6AAA64)]
                        : [Colors.grey.shade600, Colors.grey.shade700],
                  ),
                  borderRadius: BorderRadius.circular(_screenWidth * 0.03),
                ),
                child: Icon(
                  isEnabled ? Icons.vibration : Icons.phonelink_erase_rounded,
                  color: Colors.white,
                  size: _getResponsiveFontSize(24),
                ),
              ),
              SizedBox(width: _screenWidth * 0.04),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Titreşim',
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(14),
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: _screenHeight * 0.005),
                    Text(
                      isEnabled ? 'Açık' : 'Kapalı',
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(16),
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isEnabled,
                onChanged: (value) {
                  HapticService.triggerLightHaptic();
                  HapticService.toggleHapticSetting();
                },
                activeColor: const Color(0xFF538D4E),
                activeTrackColor: const Color(0xFF538D4E).withOpacity(0.3),
                inactiveThumbColor: Colors.grey.shade500,
                inactiveTrackColor: Colors.grey.shade700,
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isValidAsciiUsername(String username) {
    // ASCII karakter kontrolü - sadece İngilizce karakterler, rakamlar ve temel özel karakterler
    // a-z, A-Z, 0-9, space, underscore, hyphen, period
    final validPattern = RegExp(r'^[a-zA-Z0-9 ._-]+$');
    return validPattern.hasMatch(username);
  }
} 