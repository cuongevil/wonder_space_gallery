import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:wonderspace.gallery/screens/main_screen.dart';

import 'app_open_ad_manager.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🛡 Bắt lỗi toàn cục Flutter (chỉ log ra console)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  // 🛡 Bắt lỗi toàn cục Platform (chỉ log ra console)
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint("❌ [Platform Error] $error\n$stack");
    return true;
  };

  // 🔥 Khởi tạo Firebase
  await _initFirebase();

  // 📡 Khởi tạo quảng cáo (không block UI)
  unawaited(_initAdMob());

  // 🚀 Render UI càng sớm càng tốt
  runApp(const WonderSpaceGalleryApp());

  // 🔒 AppCheck chạy sau UI để tránh duplicate-app
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initAppCheck();
  });

  // ⚡ Preload AppOpenAd để mở app lần sau nhanh hơn
  AppOpenAdManager.preloadAd();

  // 🧠 Tăng cache ảnh để Gallery scroll mượt (ảnh AI nặng)
  PaintingBinding.instance.imageCache.maximumSizeBytes =
      120 * 1024 * 1024;
}

/// =============================================================
/// 🔥 Firebase Init
/// =============================================================
Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('🔥 [Firebase] Initialized');
  } catch (e, st) {
    debugPrint('❌ [Firebase] Failed: $e\n$st');
  }
}

/// =============================================================
/// 📡 AdMob Init
/// =============================================================
Future<void> _initAdMob() async {
  try {
    final status = await MobileAds.instance.initialize();
    for (final entry in status.adapterStatuses.entries) {
      debugPrint(
        '📢 [AdMob] Adapter: ${entry.key}, '
            'State: ${entry.value.state}, '
            'Latency: ${entry.value.latency} ms',
      );
    }

    // 🚀 Hiển thị AppOpenAd nếu đủ điều kiện
    AppOpenAdManager.showAdIfAllowed();

    debugPrint('🟢 [AdMob] Initialized');
  } catch (e, st) {
    debugPrint('❌ [AdMob] Error: $e\n$st');
  }
}

/// =============================================================
/// 🔒 Firebase App Check (Play Integrity ở release)
/// =============================================================
Future<void> _initAppCheck() async {
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider:
      kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider:
      kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
    );
    debugPrint('🔒 [AppCheck] Activated');
  } catch (e, st) {
    debugPrint('⚠️ [AppCheck] Failed: $e\n$st');
  }
}

/// =============================================================
/// 🌈 APP ROOT
/// =============================================================
class WonderSpaceGalleryApp extends StatelessWidget {
  const WonderSpaceGalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WonderSpace Gallery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme:
        ColorScheme.fromSeed(seedColor: const Color(0xffa855f7)),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}
