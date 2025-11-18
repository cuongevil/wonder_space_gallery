import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_helper.dart';

/// Quản lý App Open Ad — hiển thị 1 lần/ngày + preload chuẩn nhất.
class AppOpenAdManager {
  static AppOpenAd? _appOpenAd;
  static bool _isShowingAd = false;
  static bool _isLoading = false; // tránh load trùng
  static const _lastShownKey = 'last_app_open_ad_date';

  /// ⭐ Gọi hàm này khi app mở (trong main.dart)
  static Future<void> showAdIfAllowed() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _formatDate(DateTime.now());
    final lastShown = prefs.getString(_lastShownKey);

    // Nếu đã hiển thị hôm nay → bỏ qua
    if (lastShown == today) {
      debugPrint("📢 [AOA] Already shown today → skip");
      return;
    }

    // Load trước nếu chưa có
    if (_appOpenAd == null) {
      await _loadAd();
    }

    if (_appOpenAd == null) {
      debugPrint("⚠️ [AOA] No ad loaded.");
      return;
    }

    if (_isShowingAd) {
      debugPrint("⚠️ [AOA] Ad is already showing.");
      return;
    }

    _isShowingAd = true;

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        debugPrint("📢 [AOA] Ad SHOW");
      },
      onAdDismissedFullScreenContent: (ad) async {
        debugPrint("📢 [AOA] Ad DISMISSED");

        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;

        final prefs = await SharedPreferences.getInstance();
        prefs.setString(_lastShownKey, today);

        // Preload lại cho lần sau
        preloadAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint("❌ [AOA] Failed to show: $error");

        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;

        // Preload lại
        preloadAd();
      },
    );

    // Hiển thị quảng cáo
    _appOpenAd!.show();
  }

  /// 🔄 Load App Open Ad (API mới KHÔNG có orientation)
  static Future<void> _loadAd() async {
    if (_isLoading) return; // tránh load trùng
    _isLoading = true;

    debugPrint("🔄 [AOA] Loading AppOpenAd...");

    await AppOpenAd.load(
      adUnitId: AdHelper.appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint("✅ [AOA] Ad LOADED");
          _appOpenAd = ad;
          _isLoading = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint("❌ [AOA] Failed to load: $error");
          _appOpenAd = null;
          _isLoading = false;
        },
      ),
    );
  }

  /// ⭐ Preload cho lần sau
  static void preloadAd() {
    if (_appOpenAd == null && !_isLoading) {
      _loadAd();
    }
  }

  /// Format ngày YYYY-MM-DD
  static String _formatDate(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-"
          "${d.month.toString().padLeft(2, '0')}-"
          "${d.day.toString().padLeft(2, '0')}";
}
