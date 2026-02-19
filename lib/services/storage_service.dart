import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyLastUrl = 'last_wallpaper_url';
  static const String _keyLastDate = 'last_set_date';

  Future<String?> getLastWallpaperUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastUrl);
  }

  Future<void> saveLastWallpaperUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastUrl, url);
  }

  Future<DateTime?> getLastSetDate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyLastDate);
    return raw != null ? DateTime.tryParse(raw) : null;
  }

  Future<void> saveLastSetDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastDate, date.toIso8601String());
  }

  /// Returns true if no wallpaper has been set today (by calendar date).
  Future<bool> shouldRefreshToday() async {
    final last = await getLastSetDate();
    if (last == null) return true;
    final now = DateTime.now();
    return now.year != last.year ||
        now.month != last.month ||
        now.day != last.day;
  }
}
