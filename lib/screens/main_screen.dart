import 'package:flutter/material.dart';
import 'package:wonderspace.gallery/screens/setting_screen.dart';

import '../theme/app_theme.dart';
import 'favorite_screen.dart';
import 'gallery_screen.dart';

/// 🌈 MainScreen — giữ AppBar + BottomNavigationBar dùng chung cho toàn bộ app
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Các màn hình con
  final List<Widget> _screens = const [
    GalleryScreen(),
    FavoriteScreen(),
    SettingsScreen(),
  ];

  final List<String> _titles = const [
    '🎨 Thư viện ảnh',
    '💖 Ảnh yêu thích',
    '⚙️ Cài đặt',
  ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _titles[_currentIndex],
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          centerTitle: true,
        ),

        // 🧩 Giữ lại các tab trong IndexedStack (không reload mỗi lần chuyển)
        body: IndexedStack(index: _currentIndex, children: _screens),

        // 🌸 Bottom Navigation Bar dùng chung
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          selectedItemColor: AppTheme.primary,
          unselectedItemColor: AppTheme.inkSoft.withOpacity(0.5),
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.photo_library_rounded),
              label: 'Thư viện',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite_rounded),
              label: 'Yêu thích',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              label: 'Cài đặt',
            ),
          ],
        ),
      ),
    );
  }
}
