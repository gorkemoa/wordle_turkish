import 'package:flutter/material.dart';
import '../services/avatar_service.dart';

class AvatarSelector extends StatefulWidget {
  final String currentAvatar;
  final Function(String) onAvatarSelected;
  final bool showRandomButton;

  const AvatarSelector({
    Key? key,
    required this.currentAvatar,
    required this.onAvatarSelected,
    this.showRandomButton = true,
  }) : super(key: key);

  @override
  State<AvatarSelector> createState() => _AvatarSelectorState();
}

class _AvatarSelectorState extends State<AvatarSelector>
    with TickerProviderStateMixin {
  late TabController _tabController;
  AvatarCategory _selectedCategory = AvatarCategory.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: AvatarCategory.values.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF4285F4),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Mevcut avatar
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          widget.currentAvatar,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Avatar Seç',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Mevcut: ${widget.currentAvatar}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.showRandomButton)
                      ElevatedButton(
                        onPressed: () {
                          final randomAvatar = AvatarService.changeAvatar(widget.currentAvatar);
                          widget.onAvatarSelected(randomAvatar);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF4285F4),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shuffle, size: 16),
                            SizedBox(width: 4),
                            Text('Rastgele'),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Kategori tabları
          Container(
            color: Colors.grey.shade100,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: const Color(0xFF4285F4),
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: const Color(0xFF4285F4),
              tabs: [
                Tab(text: 'Tümü'),
                Tab(text: 'Hayvanlar'),
                Tab(text: 'Yiyecek'),
                Tab(text: 'Spor'),
                Tab(text: 'Müzik'),
                Tab(text: 'Doğa'),
                Tab(text: 'Nesneler'),
                Tab(text: 'Şekiller'),
                Tab(text: 'Meslek'),
                Tab(text: 'Simgeler'),
              ],
              onTap: (index) {
                setState(() {
                  _selectedCategory = AvatarCategory.values[index];
                });
              },
            ),
          ),

          // Avatar grid
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: AvatarCategory.values.map((category) {
                final avatars = AvatarService.getAvatarsByCategory(category);
                return _buildAvatarGrid(avatars);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarGrid(List<String> avatars) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: avatars.length,
      itemBuilder: (context, index) {
        final avatar = avatars[index];
        final isSelected = avatar == widget.currentAvatar;

        return GestureDetector(
          onTap: () {
            widget.onAvatarSelected(avatar);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF4285F4).withOpacity(0.2)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF4285F4)
                    : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Center(
              child: Text(
                avatar,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Avatar seçici dialog'unu göster
Future<String?> showAvatarSelector({
  required BuildContext context,
  required String currentAvatar,
  bool showRandomButton = true,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return AvatarSelector(
        currentAvatar: currentAvatar,
        showRandomButton: showRandomButton,
        onAvatarSelected: (avatar) {
          Navigator.of(context).pop(avatar);
        },
      );
    },
  );
} 