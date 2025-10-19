import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_helper.dart';

/// Quản lý App Open Ad hiển thị 1 lần/ngày.
class AppOpenAdManager {
  static AppOpenAd? _appOpenAd;
  static bool _isShowingAd = false;
  static const _lastShownKey = 'last_app_open_ad_date';

  /// Hiển thị quảng cáo nếu đủ điều kiện (1 lần/ngày).
  static Future<void> showAdIfAllowed() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final lastShown = prefs.getString(_lastShownKey);

    // Nếu đã hiển thị hôm nay thì bỏ qua
    if (lastShown == _formatDate(today)) return;

    await _loadAd();

    if (_appOpenAd != null && !_isShowingAd) {
      _isShowingAd = true;
      _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          _isShowingAd = false;
          ad.dispose();
          prefs.setString(_lastShownKey, _formatDate(today));
          _loadAd(); // preload lại cho lần sau
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          _isShowingAd = false;
          ad.dispose();
          _appOpenAd = null;
        },
      );
      _appOpenAd!.show();
    }
  }

  /// Load quảng cáo AppOpenAd
  static Future<void> _loadAd() async {
    await AppOpenAd.load(
      adUnitId: AdHelper.appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) => _appOpenAd = ad,
        onAdFailedToLoad: (error) => _appOpenAd = null,
      ),
    );
  }

  static String _formatDate(DateTime d) => "${d.year}-${d.month}-${d.day}";
}
