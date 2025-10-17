import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/wonder_screen_wrapper.dart';

class SettingScreen extends StatefulWidget {
  final bool gradientPhase;
  const SettingScreen({super.key, this.gradientPhase = false});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen>
    with TickerProviderStateMixin {
  String _version = '';
  User? _user;
  bool _loading = false;

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

    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic));

    _glowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.4, end: 0.9).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    // 🌈 Ánh sáng shimmer quét nhẹ trên nền gradient
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
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

  Future<void> _loginWithGoogle() async {
    setState(() => _loading = true);
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
      setState(() {
        _user = userCred.user;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('🌈 Xin chào ${_user?.displayName ?? "bạn"}!'),
        backgroundColor: Colors.deepPurpleAccent.withOpacity(0.9),
      ));
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('⚠️ Lỗi đăng nhập: $e')));
    }
  }

  Future<void> _logout() async {
    final googleSignIn = GoogleSignIn(scopes: ['email']);
    await googleSignIn.signOut();
    await FirebaseAuth.instance.signOut();
    setState(() => _user = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('👋 Đã đăng xuất khỏi Wonder Space.')),
    );
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
      query: Uri.encodeFull('subject=Góp ý & Báo lỗi Wonder Space Gallery'),
    );
    await launchUrl(emailLaunchUri);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 🌈 Gradient + shimmer ánh sáng động
        AnimatedBuilder(
          animation: _shimmerCtrl,
          builder: (context, _) {
            final dx = _shimmerCtrl.value * 2 - 1;
            return ShaderMask(
              shaderCallback: (rect) => LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.2),
                  Colors.white.withOpacity(0.05),
                  Colors.white.withOpacity(0.2)
                ],
                begin: Alignment(-1.0 + dx, -1.0),
                end: Alignment(1.0 + dx, 1.0),
              ).createShader(rect),
              blendMode: BlendMode.srcOver,
              child: AnimatedContainer(
                duration: const Duration(seconds: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.gradientPhase
                        ? [const Color(0xFF5E2CED), const Color(0xFFFF8B00)]
                        : [const Color(0xFFA58CFF), const Color(0xFFFFC480)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            );
          },
        ),

        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(color: Colors.white.withOpacity(0.08)),
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
                  const SizedBox(height: 40),
                  Center(
                    child: Text(
                      'Phiên bản $_version',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        if (_loading)
          Container(
            color: Colors.black.withOpacity(0.25),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
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
                  color: Colors.deepPurpleAccent
                      .withOpacity(_glowAnim.value * 0.5),
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
                      ? 'Cảm ơn bạn đã đồng hành cùng Wonder Space 💫'
                      : 'Đăng nhập để đồng bộ ảnh yêu thích nhé!',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
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
          child: GestureDetector(
            onTap: _user == null ? _loginWithGoogle : _logout,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
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
              child: const Text(
                'Đăng nhập Google',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3),
              ),
            ),
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
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15)),
      subtitle: Text(subtitle,
          style:
          TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}
