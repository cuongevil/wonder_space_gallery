import 'dart:async';
import 'dart:ui';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app_open_ad_manager.dart';
import 'firebase_options.dart';
import 'screens/main_screen.dart';

/// =============================================================
/// 🚀 MAIN — cấu trúc tối ưu chuẩn FlutterFire 2025
/// =============================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 1. Khởi tạo Firebase (duy nhất)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 📡 2. Bắt đầu init AdMob (không block UI)
  unawaited(_initAdMob());

  // 🚀 3. Render UI càng sớm càng tốt
  runApp(const WonderSpaceRootApp());

  // 🔒 4. Delay AppCheck → tránh duplicate-app
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (Firebase.apps.isNotEmpty) {
      _initAppCheck();
    }
  });

  // ⚡ 5. Preload AppOpenAd sau khi UI đã lên
  WidgetsBinding.instance.addPostFrameCallback((_) {
    AppOpenAdManager.preloadAd();
  });

  // 🧠 6. Boost cache ảnh (ảnh AI rất nặng)
  PaintingBinding.instance.imageCache.maximumSizeBytes =
      120 * 1024 * 1024;
}

/// =============================================================
/// 🔒 Firebase App Check — Play Integrity / Device Check
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
/// 🌈 APP ROOT — AppStarter để tránh FirebaseAuth race
/// =============================================================
class WonderSpaceRootApp extends StatelessWidget {
  const WonderSpaceRootApp({super.key});

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
      home: const AppStarter(), // 👈 Chờ 200ms → tránh duplicate-app
    );
  }
}

/// =============================================================
/// 🌟 Splash ngắn 200ms để tránh FirebaseAuth chạy quá sớm
/// =============================================================
class AppStarter extends StatefulWidget {
  const AppStarter({super.key});

  @override
  State<AppStarter> createState() => _AppStarterState();
}

class _AppStarterState extends State<AppStarter> {
  bool ready = false;

  @override
  void initState() {
    super.initState();
    _blockRaceConditions();
  }

  /// Delay nhỏ giúp:
  /// - FirebaseCore → hoàn tất init
  /// - AppCheck → activate xong
  /// - AdMob → không gây blocking
  Future<void> _blockRaceConditions() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) setState(() => ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.expand(),
      );
    }

    return const MainScreen();
  }
}
