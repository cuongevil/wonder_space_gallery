import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'firebase_options.dart';
import 'screens/gallery_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Khởi tạo Google Mobile Ads SDK
  try {
    final status = await MobileAds.instance.initialize();
    for (final entry in status.adapterStatuses.entries) {
      debugPrint(
        '📢 [AdMob] Adapter: ${entry.key}, '
            'state: ${entry.value.state}, '
            'latency: ${entry.value.latency} ms',
      );
    }
    debugPrint('✅ Google Mobile Ads SDK initialized thành công');
  } catch (e, st) {
    debugPrint('❌ Lỗi khởi tạo MobileAds: $e\n$st');
  }

  // ✅ Khởi tạo Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('🔥 Firebase initialized thành công');
  } catch (e, st) {
    debugPrint('❌ Lỗi khởi tạo Firebase: $e\n$st');
  }

  // ✅ Bật App Check (Play Integrity ở release)
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider:
      kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider:
      kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
    );
    debugPrint('🔒 Firebase App Check activated');
  } catch (e, st) {
    debugPrint('⚠️ Không thể kích hoạt App Check: $e\n$st');
  }

  // ✅ Khởi chạy ứng dụng
  runApp(const WonderSpaceGalleryApp());
}

class WonderSpaceGalleryApp extends StatelessWidget {
  const WonderSpaceGalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wonder Space Gallery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
        useMaterial3: true,
      ),
      home: const GalleryScreen(),
    );
  }
}
