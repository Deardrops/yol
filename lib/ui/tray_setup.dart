import 'dart:async';
import 'dart:io';
import 'package:tray_manager/tray_manager.dart';
import '../services/reddit_service.dart';
import '../services/wallpaper_service.dart';
import '../services/storage_service.dart';

/// Initialises the system tray icon and starts the hourly daily auto-refresh
/// timer for Windows and macOS. Call once from main() after
/// WidgetsFlutterBinding.ensureInitialized().
Future<void> initTrayAndDailyTimer() async {
  assert(Platform.isWindows || Platform.isMacOS);

  await trayManager.setIcon('assets/tray_icon.png');

  final menu = Menu(items: [
    MenuItem(key: 'show', label: 'Open Yol Wallpaper'),
    MenuItem.separator(),
    MenuItem(key: 'set_now', label: 'Set Wallpaper Now'),
    MenuItem.separator(),
    MenuItem(key: 'quit', label: 'Quit'),
  ]);
  await trayManager.setContextMenu(menu);

  trayManager.addListener(_TrayHandler.instance);

  // Immediate check on startup, then hourly so midnight date changes
  // are caught within one hour.
  await _checkAndAutoSet();
  Timer.periodic(const Duration(hours: 1), (_) => _checkAndAutoSet());
}

Future<void> _checkAndAutoSet() async {
  final storage = StorageService();
  if (!(await storage.shouldRefreshToday())) return;

  try {
    final post = await RedditService().fetchTopWallpaper();
    if (post == null) return;
    final ok = await WallpaperService().setWallpaper(post.imageUrl);
    if (ok) {
      await storage.saveLastWallpaperUrl(post.imageUrl);
      await storage.saveLastSetDate(DateTime.now());
    }
  } catch (_) {
    // Silent failure; will retry on the next hourly tick.
  }
}

class _TrayHandler with TrayListener {
  _TrayHandler._();
  static final _TrayHandler instance = _TrayHandler._();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'set_now':
        _checkAndAutoSet();
        break;
      case 'quit':
        exit(0);
    }
  }
}
