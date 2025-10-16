import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  String _version = '';
  String _buildDate = '2025-10-16';
  User? _user;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
    _user = FirebaseAuth.instance.currentUser;
  }

  Future<void> _loadAppInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = '${info.version}+${info.buildNumber}';
    });
  }

  Future<void> _loginWithGoogle() async {
    try {
      setState(() => _loading = true);

      final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email']);
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

      setState(() {
        _user = userCred.user;
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🌈 Xin chào ${_user?.displayName ?? "bạn"}!'),
          backgroundColor: Colors.deepPurpleAccent.withOpacity(0.9),
        ),
      );
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi đăng nhập: $e')),
      );
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
      'https://sites.google.com/view/ctmd-wonderforge/home/wonderspace-gallery',
    );
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

  Future<void> _openCommunity() async {
    final url = Uri.parse('https://www.facebook.com/ctmd.wonderforge');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openPlayStore() async {
    final url = Uri.parse('https://play.google.com/store/apps/details?id=com.ctmd.wonderforge.wonderspace.gallery');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 🌈 Nền gradient mềm
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFDF6FF), Color(0xFFFFF8F5)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        // Nội dung chính
        ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 10),
            _buildHeader(),
            const SizedBox(height: 24),

            // --- Tài khoản ---
            const Text('Tài khoản ☁️',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            _buildLoginCard(),

            const SizedBox(height: 24),

            // --- Ứng dụng ---
            const Text('Ứng dụng 📱',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            _buildSettingCard(
              icon: Icons.privacy_tip_outlined,
              color: Colors.pinkAccent,
              title: 'Chính sách & Quyền riêng tư',
              subtitle: 'Xem thông tin thu thập dữ liệu và điều khoản sử dụng.',
              onTap: _openPrivacyPolicy,
            ),
            _buildSettingCard(
              icon: Icons.info_outline,
              color: Colors.blueAccent,
              title: 'Phiên bản ứng dụng',
              subtitle: '$_version  •  Build: $_buildDate',
            ),
            _buildSettingCard(
              icon: Icons.star_border_rounded,
              color: Colors.amber,
              title: 'Đánh giá ứng dụng',
              subtitle: 'Giúp Wonder Space tốt hơn bằng cách đánh giá 5⭐ nhé!',
              onTap: _openPlayStore,
            ),

            const SizedBox(height: 24),

            // --- Hỗ trợ ---
            const Text('Hỗ trợ 💬',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            _buildSettingCard(
              icon: Icons.email_outlined,
              color: Colors.orangeAccent,
              title: 'Góp ý & Báo lỗi',
              subtitle: 'Gửi phản hồi trực tiếp qua email.',
              onTap: _sendFeedback,
            ),
            _buildSettingCard(
              icon: Icons.group_outlined,
              color: Colors.teal,
              title: 'Cộng đồng Wonder Space',
              subtitle: 'Tham gia để chia sẻ ảnh & ý tưởng sáng tạo!',
              onTap: _openCommunity,
            ),

            const SizedBox(height: 40),
            const Center(
              child: Text(
                'Wonder Space Gallery 💫',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),

        if (_loading)
          Container(
            color: Colors.white.withOpacity(0.6),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  // 🌤️ Header với gradient + avatar
  Widget _buildHeader() {
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
            color: Colors.purple.withOpacity(0.08),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
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
                  color: Colors.purpleAccent.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
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
  }

  Widget _buildLoginCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.purple.withOpacity(0.08)),
      ),
      elevation: 1.5,
      shadowColor: Colors.purple.withOpacity(0.1),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.cloud_outlined, color: Colors.deepPurple),
            const SizedBox(width: 12),
            Expanded(
              child: _user == null
                  ? const Text(
                'Đăng nhập bằng Google để lưu danh sách yêu thích.',
              )
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _user!.displayName ?? 'Người dùng',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _user!.email ?? '',
                    style:
                    const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _user == null ? _loginWithGoogle : _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(_user == null ? 'Đăng nhập' : 'Đăng xuất'),
            ),
          ],
        ),
      ),
    );
  }

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
