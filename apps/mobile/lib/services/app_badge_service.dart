import 'package:app_badge_plus/app_badge_plus.dart';

/// Launcher icon badge (WeChat-style red dot when [count] > 0).
class AppBadgeService {
  Future<void> syncUnreadCount(int count) async {
    try {
      final supported = await AppBadgePlus.isSupported();
      if (!supported) return;
      if (count > 0) {
        await AppBadgePlus.updateBadge(1);
      } else {
        await AppBadgePlus.updateBadge(0);
      }
    } catch (_) {
      // Badge APIs vary by OEM; ignore failures.
    }
  }
}
