import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:wonderspace.gallery/screens/main_screen.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initFirebase();
  await _initAdMob();
  await _initAppCheck();

  runApp(const WonderSpaceGalleryApp());
}

/// ✅ Khởi tạo Firebase
Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('🔥 [Firebase] Initialized successfully');
  } catch (e, st) {
    debugPrint('❌ [Firebase] Initialization failed: $e\n$st');
  }
}

/// ✅ Khởi tạo Google Mobile Ads SDK
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

    debugPrint('✅ [AdMob] SDK initialized successfully');
  } catch (e, st) {
    debugPrint('❌ [AdMob] Initialization failed: $e\n$st');
  }
}

/// ✅ Bật Firebase App Check (Play Integrity trên release)
Future<void> _initAppCheck() async {
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode
          ? AppleProvider.debug
          : AppleProvider.deviceCheck,
    );
    debugPrint('🔒 [AppCheck] Activated successfully');
  } catch (e, st) {
    debugPrint('⚠️ [AppCheck] Activation failed: $e\n$st');
  }
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
      home: const MainScreen(),
    );
  }
}
