import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:wonderspace.gallery/screens/favorite_screen.dart';
import 'package:wonderspace.gallery/screens/gallery_screen.dart';
import 'package:wonderspace.gallery/screens/setting_screen.dart';

import '../theme/app_theme.dart';

/// 🌈 MainScreen — giữ AppBar + BottomNavigationBar dùng chung cho toàn bộ app
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  final List<Widget> _screens = const [
    GalleryScreen(),
    FavoriteScreen(),
    SettingScreen(),
  ];

  final List<String> _titles = const [
    '🎨 Thư viện ảnh',
    '💖 Ảnh yêu thích',
    '⚙️ Cài đặt',
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _scaleAnim = Tween<double>(
      begin: 0.97,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _animCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light(),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: AppTheme.bg,
        // 🌸 AppBar mờ nền kiểu TPBank
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: AppBar(
                backgroundColor: Colors.white.withOpacity(0.5),
                elevation: 0,
                centerTitle: true,
                title: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _titles[_currentIndex],
                    key: ValueKey(_titles[_currentIndex]),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // ✨ Nội dung với hiệu ứng chuyển tab mượt
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) {
            final fade = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            );
            return FadeTransition(
              opacity: fade,
              child: ScaleTransition(scale: _scaleAnim, child: child),
            );
          },
          child: IndexedStack(
            key: ValueKey(_currentIndex),
            index: _currentIndex,
            children: _screens,
          ),
        ),

        // 🌈 Bottom Navigation Bar nổi nhẹ + gradient icon động
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            boxShadow: [
              BoxShadow(
                color: Colors.deepPurple.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onTabSelected,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            selectedItemColor: AppTheme.primary,
            unselectedItemColor: AppTheme.inkSoft.withOpacity(0.5),
            showUnselectedLabels: true,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
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
      ),
    );
  }
}
