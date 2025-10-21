// ⚙️ SettingScreen — TPBank Glass Gradient 2025 + Auto Sync + Update Banner
import 'dart:io';
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

  // 🔔 Cập nhật
  bool _hasUpdate = false;
  String? _updateMessage;
  String? _updateUrl;

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

    _startPhaseLoop();
    _checkForUpdate(); // ✅ Tự động kiểm tra khi mở
  }

  void _startPhaseLoop() {
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

  // 🔔 Kiểm tra bản cập nhật từ Firestore
  Future<void> _checkForUpdate({bool manual = false}) async {
    final info = await PackageInfo.fromPlatform();
    final currentVersion = info.version;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_meta')
          .doc('wonder_space_gallery') // ⚙️ thay bằng tên app
          .get();

      final data = doc.data();
      final latest = data?['latestVersion'];
      final message =
          data?['updateMessage'] ?? '🎉 Có bản cập nhật mới! Nhấn để xem chi tiết.';
      final playUrl = data?['playStoreUrl'];
      final appUrl = data?['appStoreUrl'];

      if (latest != null && latest != currentVersion) {
        setState(() {
          _hasUpdate = true;
          _updateMessage = message;
          _updateUrl = Platform.isAndroid ? playUrl : appUrl;
        });

        if (manual) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎉 Đã có bản cập nhật mới ($latest)!'),
              backgroundColor: Colors.deepPurpleAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else if (manual) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Bạn đang sử dụng phiên bản mới nhất.'),
            backgroundColor: Colors.deepPurpleAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (manual) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ Lỗi kiểm tra cập nhật: $e')),
        );
      }
    }
  }

  // ☁️ Auto sync mỗi ngày 1 lần
  Future<void> _autoSyncFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final lastSync = prefs.getString(_lastSyncKey);
    if (lastSync == _formatDate(today)) return;

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

  // ☁️ Đồng bộ thủ công
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

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('☁️ Đồng bộ hoàn tất!'),
        backgroundColor: Colors.deepPurpleAccent,
      ));
    } catch (e) {
      setState(() {
        _syncing = false;
        _synced = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('⚠️ Lỗi đồng bộ: $e')));
    }
  }

  // 🔐 Google login
  Future<void> _loginWithGoogle() async {
    setState(() => _loading = true);
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email']);
      await googleSignIn.signOut();
      final user = await googleSignIn.signIn();
      if (user == null) return;
      final auth = await user.authentication;
      final cred = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );

      final userCred = await FirebaseAuth.instance.signInWithCredential(cred);
      setState(() => _user = userCred.user);

      await _manualSyncFavorites();
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

  Future<void> _syncFavoritesToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final firestore = FirebaseFirestore.instance;
    final favLocal = prefs.getStringList('favorites_local') ?? [];

    final ref = firestore.collection('favorites').doc(user.uid).collection('items');
    final snapshot = await ref.get();
    final favOnline = snapshot.docs.map((d) => d.id).toList();

    for (final id in favLocal) {
      if (!favOnline.contains(id)) {
        await ref.doc(id).set({'createdAt': FieldValue.serverTimestamp()});
      }
    }
  }

  Future<void> _fetchFavoritesFromFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    final snapshot = await FirebaseFirestore.instance
        .collection('favorites')
        .doc(user.uid)
        .collection('items')
        .get();
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
    final Uri email = Uri(
      scheme: 'mailto',
      path: 'cuongnb318@gmail.com',
      query: Uri.encodeFull('subject=Góp ý & Báo lỗi WonderSpace Thư Viện Ảnh'),
    );
    await launchUrl(email);
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
          _buildShimmer(),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(color: Colors.white.withOpacity(0.06)),
          ),
          FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: WonderScreenWrapper(
                scrollable: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_hasUpdate && _updateMessage != null)
                      _UpdateBanner(message: _updateMessage!, url: _updateUrl),
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
                            Icons.system_update_alt_rounded,
                            'Kiểm tra cập nhật',
                            'Phiên bản $_version',
                                () => _checkForUpdate(manual: true),
                          ),
                          _buildSettingItem(
                            Icons.privacy_tip_outlined,
                            'Chính sách & Quyền riêng tư',
                            'Xem điều khoản sử dụng',
                            _openPrivacyPolicy,
                          ),
                          _buildSettingItem(
                            Icons.email_outlined,
                            'Góp ý & Báo lỗi',
                            'Gửi phản hồi qua email',
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
          if (_syncing || _synced) _buildSyncIndicator(),
          if (_loading)
            Container(
              color: Colors.black.withOpacity(0.25),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildShimmer() => AnimatedBuilder(
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
  );

  Widget _buildHeader() => Row(
    children: [
      CircleAvatar(
        radius: 28,
        backgroundImage: _user?.photoURL != null
            ? NetworkImage(_user!.photoURL!)
            : const AssetImage('assets/logo.png') as ImageProvider,
      ),
      const SizedBox(width: 14),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _user != null
                ? 'Chào ${_user!.displayName?.split(" ").first ?? "bạn"} 👋'
                : 'Xin chào bạn 👋',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18),
          ),
          Text(
            _user != null
                ? 'Cảm ơn bạn đã đồng hành 💫'
                : 'Đăng nhập để lưu ảnh yêu thích!',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    ],
  );

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
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
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
      children: [
        Text(
          _user == null
              ? 'Đăng nhập để lưu trữ và đồng bộ ảnh yêu thích ☁️'
              : _user!.email ?? '',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (_user != null)
            _buildButton(Icons.sync_rounded, 'Đồng bộ ngay', _manualSyncFavorites),
          const SizedBox(width: 12),
          _buildButton(
              _user == null ? Icons.login_rounded : Icons.logout_rounded,
              _user == null ? 'Đăng nhập Google' : 'Đăng xuất',
              _user == null ? _loginWithGoogle : _logout),
        ]),
      ],
    );
  }

  Widget _buildButton(IconData icon, String label, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5E2CED), Color(0xFFFF8B00)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );

  Widget _buildSettingItem(
      IconData icon, String title, String subtitle, VoidCallback onTap) =>
      ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle:
        Text(subtitle, style: const TextStyle(color: Colors.white70)),
        onTap: onTap,
      );

  Widget _buildSyncIndicator() => Center(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (_syncing)
          const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2)),
        if (_synced)
          const Icon(Icons.check_circle_rounded,
              color: Colors.white, size: 24),
        const SizedBox(width: 10),
        Text(_syncing ? 'Đang đồng bộ...' : 'Đồng bộ hoàn tất ✨',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

/// 🔔 Banner cập nhật — Fade + Slide + Nút "Cập nhật ngay"
class _UpdateBanner extends StatefulWidget {
  final String message;
  final String? url;
  const _UpdateBanner({required this.message, this.url});

  @override
  State<_UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<_UpdateBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl =
    AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _slideAnim = Tween<Offset>(
        begin: const Offset(0, -0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fadeAnim,
    child: SlideTransition(
      position: _slideAnim,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5E2CED), Color(0xFFFF8B00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.system_update_rounded,
                color: Colors.white, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.message,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
            ),
            if (widget.url != null)
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse(widget.url!);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Text('Cập nhật',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded,
                          color: Colors.white, size: 13),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
