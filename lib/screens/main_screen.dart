import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:wonderspace.gallery/screens/favorite_screen.dart';
import 'package:wonderspace.gallery/screens/gallery_screen.dart';
import 'package:wonderspace.gallery/screens/setting_screen.dart';
import '../theme/app_theme.dart';

/// 🌈 MainScreen — phiên bản đồng bộ màu tím–cam premium
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isNavVisible = true;
  bool _phase = false;

  late final AnimationController _navCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  late final List<AnimationController> _iconCtrls;

  @override
  void initState() {
    super.initState();
    _navCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _navCtrl, curve: Curves.easeInOut);
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _navCtrl, curve: Curves.easeInOut));
    _navCtrl.value = 1.0;

    _iconCtrls = List.generate(
      3,
          (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );
    _iconCtrls[_currentIndex].forward();

    // 🌈 Gradient phase animation (chuyển màu nhẹ)
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted) return false;
      setState(() => _phase = !_phase);
      return true;
    });
  }

  @override
  void dispose() {
    _navCtrl.dispose();
    for (final c in _iconCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _onScrollDirection(ScrollDirection direction) {
    if (direction == ScrollDirection.reverse && _isNavVisible) {
      setState(() => _isNavVisible = false);
      _navCtrl.reverse();
    } else if (direction == ScrollDirection.forward && !_isNavVisible) {
      setState(() => _isNavVisible = true);
      _navCtrl.forward();
    }
  }

  void _onTabSelected(int index) async {
    if (index == _currentIndex) return;
    for (final c in _iconCtrls) {
      c.reverse();
    }
    _iconCtrls[index].forward();
    setState(() => _currentIndex = index);
    await Future.delayed(const Duration(milliseconds: 50));
    Feedback.forTap(context);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      GalleryScreen(onScrollDirectionChanged: _onScrollDirection),
      const FavoriteScreen(),
      const SettingScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: AnimatedContainer(
        duration: const Duration(seconds: 5),
        onEnd: () => setState(() => _phase = !_phase),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _phase
                ? [const Color(0xFF5E2CED), const Color(0xFFFF8B00)]
                : [const Color(0xFFA58CFF), const Color(0xFFFFC480)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(scale: _scaleAnim, child: child),
          ),
          child: IndexedStack(
            key: ValueKey(_currentIndex),
            index: _currentIndex,
            children: screens,
          ),
        ),
      ),

      // 🌈 Floating Gradient Nav Bar — đồng màu với GalleryScreen
      bottomNavigationBar: SizeTransition(
        sizeFactor: _fadeAnim,
        axisAlignment: -1.0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: AnimatedContainer(
                duration: const Duration(seconds: 2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _phase
                        ? [
                      const Color(0xFF6C3DFF).withOpacity(0.75),
                      const Color(0xFFFF8B00).withOpacity(0.7)
                    ]
                        : [
                      const Color(0xFFA58CFF).withOpacity(0.7),
                      const Color(0xFFFFC480).withOpacity(0.65)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.18),
                      blurRadius: 40,
                      offset: const Offset(0, -4),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25),
                    width: 0.8,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(Icons.photo_library_rounded, 'Thư viện', 0),
                      _buildNavItem(Icons.favorite_rounded, 'Yêu thích', 1),
                      _buildNavItem(Icons.settings_rounded, 'Cài đặt', 2),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 💫 Icon có hiệu ứng gradient & pulse sáng
  Widget _buildNavItem(IconData icon, String label, int index) {
    final isActive = _currentIndex == index;
    final anim = CurvedAnimation(
      parent: _iconCtrls[index],
      curve: Curves.easeOutBack,
    );

    final gradient = const LinearGradient(
      colors: [Color(0xFF5E2CED), Color(0xFFFF8B00)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return GestureDetector(
      onTap: () => _onTabSelected(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: EdgeInsets.all(isActive ? 8 : 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: isActive
                  ? [
                BoxShadow(
                  color: const Color(0xFF5E2CED).withOpacity(0.4),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
                  : [],
            ),
            child: ScaleTransition(
              scale: Tween(begin: 1.0, end: 1.25).animate(anim),
              child: ShaderMask(
                shaderCallback: (bounds) => gradient.createShader(bounds),
                child: Icon(
                  icon,
                  size: isActive ? 28 : 24,
                  color: isActive ? Colors.white : Colors.white70,
                ),
              ),
            ),
          ),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(
              fontSize: 12,
              color:
              isActive ? Colors.white : Colors.white.withOpacity(0.7),
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
