import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:tray_manager/tray_manager.dart';
import '../services/reddit_service.dart';
import '../services/wallpaper_service.dart';
import '../services/storage_service.dart';

/// Holds everything the tray icon needs while it is shown.
///
/// A nativeapi wrapper releases its native handle when it is collected, which
/// would take the icon, its menu, or a single menu entry off the tray.  The
/// objects are therefore kept reachable for the lifetime of the process.
class _TrayState {
  TrayIcon? icon;
  Menu? menu;
  Image? iconImage;
  final List<MenuItem> menuItems = <MenuItem>[];
}

final _TrayState _tray = _TrayState();

/// Initialises the system tray icon and starts the hourly daily auto-refresh
/// timer for Windows and macOS. Call once from main() after
/// WidgetsFlutterBinding.ensureInitialized().
Future<void> initTrayAndDailyTimer() async {
  assert(Platform.isWindows || Platform.isMacOS);

  final trayIcon = TrayIcon.create();
  if (trayIcon == null) {
    throw StateError('Unable to create the system tray icon.');
  }
  _tray.icon = trayIcon;

  final iconImage = ImageAsset.fromAsset('assets/tray_icon.png');
  if (iconImage == null) {
    throw ArgumentError.value(
      'assets/tray_icon.png',
      'iconPath',
      'Unable to load tray icon',
    );
  }
  _tray.iconImage = iconImage;

  // iconSize and iconPosition are macOS only; other platforms ignore them.
  trayIcon
    ..isIconTemplate = false
    ..iconSize = ui.Size.square(18)
    ..iconPosition = TrayIconPosition.left
    ..icon = iconImage
    ..setVisible(true);

  final menu = Menu.create();
  if (menu == null) {
    throw StateError('Unable to create the tray context menu.');
  }
  _tray.menu = menu;

  menu.addItem(_trayMenuItem('Open Yol Wallpaper'));
  menu.addSeparator();
  menu.addItem(_trayMenuItem('Set Wallpaper Now', _checkAndAutoSet));
  menu.addSeparator();
  menu.addItem(_trayMenuItem('Quit', () async => exit(0)));

  trayIcon.setContextMenu(menu);

  // Immediate check on startup, then hourly so midnight date changes
  // are caught within one hour.
  await _checkAndAutoSet();
  Timer.periodic(const Duration(hours: 1), (_) => _checkAndAutoSet());
}

/// Creates a tray menu entry labelled [label] that runs [onSelected] when it
/// is clicked.
///
/// An entry created without a callback stays inert: 'Open Yol Wallpaper' is
/// kept as a plain label because the window is never hidden, so there has
/// never been anything to bring back.
MenuItem _trayMenuItem(String label, [Future<void> Function()? onSelected]) {
  final item = MenuItem.createWithLabelAndType(label, MenuItemType.normal);
  if (item == null) {
    throw StateError('Unable to create the menu item "$label".');
  }
  if (onSelected != null) {
    item.addListener((event) {
      if (event is MenuItemClickedEvent) {
        unawaited(onSelected());
      }
    });
  }
  _tray.menuItems.add(item);
  return item;
}

/// Returns true when the primary display (or the first Flutter view) is
/// landscape.  Falls back to landscape == true when no view is available.
bool _isLandscapeFromDisplay() {
  final views = ui.PlatformDispatcher.instance.views;
  if (views.isEmpty) return true;
  final view = views.first;
  final size = view.physicalSize / view.devicePixelRatio;
  return size.width >= size.height;
}

Future<void> _checkAndAutoSet() async {
  final storage = StorageService();
  if (!(await storage.shouldRefreshToday())) return;

  try {
    final landscapeOnly = _isLandscapeFromDisplay();
    final post =
        await RedditService().fetchTopWallpaper(landscapeOnly: landscapeOnly);
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