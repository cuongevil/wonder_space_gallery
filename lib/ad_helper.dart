import 'dart:io';

/// Lớp AdHelper giúp tách ID quảng cáo cho từng nền tảng
class AdHelper {
  /// App ID (bắt buộc khai báo trong AndroidManifest.xml & Info.plist)
  static String get appId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-4467146889101185~3926719094';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-4467146889101185~7674392415';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  /// Banner Ad Unit ID
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-4467146889101185/9556010791';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-4467146889101185/8360788125';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  /// App Open Ad Unit ID
  static String get appOpenAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-4467146889101185/2617506855';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-4467146889101185/7678261843';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }
}
