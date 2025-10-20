// ⚙️ SettingScreen — TPBank Glass Gradient 2025 + Auto Sync Favorite (local ⇆ Firebase)
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/wonder_screen_wrapper.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen>
    with TickerProviderStateMixin {
  String _version = '';
  User? _user;
  bool _loading = false;
  bool _syncing = false;
  bool _synced = false;
  bool _phase = false;

  static const _lastSyncKey = 'last_favorite_sync_date';

  late final AnimationController _fadeCtrl;
  late final AnimationController _glowCtrl;
  late final AnimationController _shimmerCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
    _user = FirebaseAuth.instance.currentUser;

    // 🔁 Tự động đồng bộ nếu đã đăng nhập và chưa sync hôm nay
    if (_user != null) {
      Future.delayed(const Duration(milliseconds: 600), _autoSyncFavorites);
    }

    _fadeCtrl =
    AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic));

    _glowCtrl =
    AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.4, end: 0.9)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _shimmerCtrl =
    AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat();

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted) return false;
      setState(() => _phase = !_phase);
      return true;
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _glowCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAppInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _version = '${info.version}+${info.buildNumber}');
  }

  // ☁️ Auto sync mỗi ngày 1 lần
  Future<void> _autoSyncFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final lastSync = prefs.getString(_lastSyncKey);

    if (lastSync == _formatDate(today)) return; // Đã sync hôm nay

    setState(() => _syncing = true);
    await _syncFavoritesToFirebase();
    await _fetchFavoritesFromFirebase();
    await prefs.setString(_lastSyncKey, _formatDate(today));

    setState(() {
      _syncing = false;
      _synced = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _synced = false);
    });
  }

  String _formatDate(DateTime d) => '${d.year}-${d.month}-${d.day}';

  // ☁️ Manual sync
  Future<void> _manualSyncFavorites() async {
    setState(() {
      _syncing = true;
      _synced = false;
    });

    try {
      await _syncFavoritesToFirebase();
      await _fetchFavoritesFromFirebase();

      setState(() {
        _syncing = false;
        _synced = true;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _synced = false);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('☁️ Đồng bộ hoàn tất!'),
          backgroundColor: Colors.deepPurpleAccent,
        ),
      );
    } catch (e) {
      setState(() {
        _syncing = false;
        _synced = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('⚠️ Lỗi đồng bộ: $e')));
    }
  }

  // 🔐 Đăng nhập Google
  Future<void> _loginWithGoogle() async {
    setState(() {
      _loading = true;
      _synced = false;
    });

    try {
      final googleSignIn = GoogleSignIn(scopes: ['email']);
      await googleSignIn.signOut();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred =
      await FirebaseAuth.instance.signInWithCredential(credential);
      setState(() => _user = userCred.user);

      await _manualSyncFavorites();

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('🌈 Xin chào ${_user?.displayName ?? "bạn"}!'),
        backgroundColor: Colors.deepPurpleAccent.withOpacity(0.9),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('⚠️ Lỗi đăng nhập: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    final googleSignIn = GoogleSignIn(scopes: ['email']);
    await googleSignIn.signOut();
    await FirebaseAuth.instance.signOut();
    setState(() => _user = null);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('👋 Đã đăng xuất.')));
  }

  // ☁️ Upload local → Firebase
  Future<void> _syncFavoritesToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final firestore = FirebaseFirestore.instance;
    final favLocal = prefs.getStringList('favorites_local') ?? [];

    final userRef = firestore.collection('favorites').doc(user.uid).collection('items');
    final snapshot = await userRef.get();
    final favOnline = snapshot.docs.map((d) => d.id).toList();

    final merged = {...favLocal, ...favOnline}.toList();

    for (final id in favLocal) {
      if (!favOnline.contains(id)) {
        await userRef.doc(id).set({'createdAt': FieldValue.serverTimestamp()});
      }
    }

    await prefs.setStringList('favorites_local', merged);
  }

  // ☁️ Download Firebase → local
  Future<void> _fetchFavoritesFromFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final firestore = FirebaseFirestore.instance;
    final snapshot =
    await firestore.collection('favorites').doc(user.uid).collection('items').get();

    final favIds = snapshot.docs.map((d) => d.id).toList();
    await prefs.setStringList('favorites_local', favIds);
  }

  Future<void> _openPrivacyPolicy() async {
    final url = Uri.parse(
        'https://sites.google.com/view/ctmd-wonderforge/home/wonderspace-gallery');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _sendFeedback() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'cuongnb318@gmail.com',
      query: Uri.encodeFull('subject=Góp ý & Báo lỗi WonderSpace Thư Viện Ảnh'),
    );
    await launchUrl(emailLaunchUri);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(seconds: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _phase
              ? [const Color(0xFF5E2CED), const Color(0xFFFF8B00)]
              : [const Color(0xFFA58CFF), const Color(0xFFFFC480)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // ✨ Nền shimmer
          AnimatedBuilder(
            animation: _shimmerCtrl,
            builder: (context, _) {
              final dx = _shimmerCtrl.value * 2 - 1;
              return ShaderMask(
                shaderCallback: (rect) => LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.25),
                    Colors.white.withOpacity(0.05),
                    Colors.white.withOpacity(0.25),
                  ],
                  begin: Alignment(-1.0 + dx, -1.0),
                  end: Alignment(1.0 + dx, 1.0),
                ).createShader(rect),
                blendMode: BlendMode.srcOver,
                child: Container(color: Colors.transparent),
              );
            },
          ),

          // 💫 Blur nền
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(color: Colors.white.withOpacity(0.06)),
          ),

          // 🌸 Nội dung chính
          FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: WonderScreenWrapper(
                scrollable: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 28),
                    _buildGlassCard(
                      icon: Icons.cloud_outlined,
                      title: 'Tài khoản ☁️',
                      content: _buildLoginCard(),
                    ),
                    const SizedBox(height: 20),
                    _buildGlassCard(
                      icon: Icons.support_agent_rounded,
                      title: 'Hỗ trợ 💬',
                      content: Column(
                        children: [
                          _buildSettingItem(
                            Icons.privacy_tip_outlined,
                            'Chính sách & Quyền riêng tư',
                            'Xem thông tin và điều khoản sử dụng.',
                            _openPrivacyPolicy,
                          ),
                          _buildSettingItem(
                            Icons.email_outlined,
                            'Góp ý & Báo lỗi',
                            'Gửi phản hồi trực tiếp qua email.',
                            _sendFeedback,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 🌈 Hiển thị tiến trình đồng bộ
          if (_syncing || _synced)
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.6)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_syncing)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    if (_synced)
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      _syncing ? 'Đang đồng bộ...' : 'Đồng bộ hoàn tất ✨',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_loading)
            Container(
              color: Colors.black.withOpacity(0.25),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, __) => Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurpleAccent.withOpacity(_glowAnim.value * 0.5),
                  blurRadius: 28 * _glowAnim.value,
                  spreadRadius: 2 * _glowAnim.value,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundImage: _user?.photoURL != null
                  ? NetworkImage(_user!.photoURL!)
                  : const AssetImage('assets/logo.png') as ImageProvider,
            ),
          ),
          const SizedBox(width: 14),
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              colors: [Colors.white, Color(0xFFFFE1A0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(rect),
            blendMode: BlendMode.srcIn,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _user != null
                      ? 'Chào ${_user!.displayName?.split(" ").first ?? "bạn"} 👋'
                      : 'Xin chào bạn 👋',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  _user != null
                      ? 'Cảm ơn bạn đã đồng hành 💫'
                      : 'Đăng nhập để lưu ảnh yêu thích!',
                  style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({
    required IconData icon,
    required String title,
    required Widget content,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.22),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              content,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _user == null
              ? 'Đăng nhập bằng Google để lưu trữ và đồng bộ ảnh yêu thích ☁️'
              : _user!.email ?? '',
          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 12),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🌈 Nút Đồng bộ ngay ☁️ — chỉ hiển thị khi đã đăng nhập
              if (_user != null) ...[
                const SizedBox(width: 10),
                AnimatedBuilder(
                  animation: _glowAnim,
                  builder: (_, __) => GestureDetector(
                    onTap: _manualSyncFavorites,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.25)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurpleAccent
                                .withOpacity(_glowAnim.value * 0.6),
                            blurRadius: 22 * _glowAnim.value,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.sync_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Đồng bộ ngay',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              // 🌈 Nút Đăng nhập / Đăng xuất
              GestureDetector(
                onTap: _user == null ? _loginWithGoogle : _logout,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5E2CED), Color(0xFFFF8B00)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.withOpacity(0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    _user == null ? 'Đăng nhập Google' : 'Đăng xuất',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem(
      IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white.withOpacity(0.9)),
      title: Text(title,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(subtitle,
          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}
