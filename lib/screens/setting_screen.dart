import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/wonder_screen_wrapper.dart'; // 👈 Thêm dòng này

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

  late final AnimationController _fadeCtrl;
  late final AnimationController _glowCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
    _user = FirebaseAuth.instance.currentUser;

    // Animation fade-in
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic));
    _fadeCtrl.forward();

    // 🌈 Glow động quanh avatar
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(
      begin: 0.4,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAppInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = '${info.version}+${info.buildNumber}';
    });
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _loading = true);

    try {
      final googleSignIn = GoogleSignIn(scopes: ['email']);
      await googleSignIn.signOut();

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _loading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred =
      await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCred.user;

      setState(() {
        _user = user;
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🌈 Xin chào ${user?.displayName ?? "bạn"}!'),
          backgroundColor: Colors.deepPurpleAccent.withOpacity(0.9),
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ FirebaseAuth lỗi: ${e.message}')),
      );
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('⚠️ Lỗi đăng nhập: $e')));
    }
  }

  Future<void> _logout() async {
    final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email']);
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
        // 🌈 Nền pastel gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFDF6FF), Color(0xFFFFF8F5)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        // 🌸 Nội dung chính — tự động canh lề tránh AppBar
        FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: WonderScreenWrapper(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Tài khoản ☁️'),
                  _buildLoginCard(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Hỗ trợ 💬'),
                  _buildSettingCard(
                    icon: Icons.privacy_tip_outlined,
                    color: Colors.pinkAccent,
                    title: 'Chính sách & Quyền riêng tư',
                    subtitle:
                    'Xem thông tin thu thập dữ liệu và điều khoản sử dụng.',
                    onTap: _openPrivacyPolicy,
                  ),
                  _buildSettingCard(
                    icon: Icons.email_outlined,
                    color: Colors.orangeAccent,
                    title: 'Góp ý & Báo lỗi',
                    subtitle: 'Gửi phản hồi trực tiếp qua email.',
                    onTap: _sendFeedback,
                  ),
                ],
              ),
            ),
          ),
        ),

        if (_loading)
          Container(
            color: Colors.white.withOpacity(0.6),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  // 🌤️ Header với glow động quanh avatar
  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE8DFFF), Color(0xFFFFF5E1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color:
                Colors.deepPurpleAccent.withOpacity(_glowAnim.value * 0.3),
                blurRadius: 25 * _glowAnim.value,
                spreadRadius: 2 * _glowAnim.value,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purpleAccent
                          .withOpacity(_glowAnim.value * 0.5),
                      blurRadius: 20 * _glowAnim.value,
                      spreadRadius: 3 * _glowAnim.value,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 30,
                  backgroundImage: _user?.photoURL != null
                      ? NetworkImage(_user!.photoURL!)
                      : const AssetImage('assets/logo.png') as ImageProvider,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
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
                          ? 'Cảm ơn bạn đã ghé Wonder Space 💫'
                          : 'Đăng nhập để đồng bộ ảnh yêu thích nhé!',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ☁️ Login card
  Widget _buildLoginCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.deepPurple.withOpacity(0.1)),
      ),
      elevation: 1.5,
      shadowColor: Colors.purple.withOpacity(0.08),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE8DFFF), Color(0xFFFFF5E1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.withOpacity(0.1),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.cloud_outlined,
                    color: Colors.deepPurple,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _user == null
                      ? const Text(
                    'Đăng nhập bằng Google để lưu trữ và đồng bộ ảnh yêu thích của bạn ☁️',
                    style: TextStyle(fontSize: 14, height: 1.4),
                  )
                      : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _user!.displayName ?? 'Người dùng',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _user!.email ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: const [
                          Icon(
                            Icons.verified_rounded,
                            color: Colors.green,
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Đã đồng bộ tài khoản Google',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: Icon(
                  _user == null ? Icons.login_rounded : Icons.logout_rounded,
                  size: 18,
                ),
                label: Text(_user == null ? 'Đăng nhập Google' : 'Đăng xuất'),
                onPressed: _user == null ? _loginWithGoogle : _logout,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
        color: Colors.black87,
      ),
    ),
  );

  Widget _buildSettingCard({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.05)),
      ),
      elevation: 0.8,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: color, size: 26),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        onTap: onTap,
      ),
    );
  }
}
