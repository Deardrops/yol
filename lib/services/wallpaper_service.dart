import 'dart:io';
import 'package:flutter/services.dart';
import 'package:async_wallpaper/async_wallpaper.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class WallpaperService {
  static const MethodChannel _channel =
      MethodChannel('com.example.yol_app/wallpaper');

  /// Sets the wallpaper on the current platform.
  /// Returns true on success, false on failure.
  Future<bool> setWallpaper(String imageUrl) async {
    if (Platform.isAndroid) {
      return _setAndroidWallpaper(imageUrl);
    } else if (Platform.isWindows || Platform.isMacOS) {
      return _setDesktopWallpaper(imageUrl);
    }
    return false;
  }

  Future<bool> _setAndroidWallpaper(String imageUrl) async {
    try {
      final bool result = await AsyncWallpaper.setWallpaper(
        url: imageUrl,
        wallpaperLocation: AsyncWallpaper.BOTH_SCREENS,
        goToHome: false,
      );
      return result;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _setDesktopWallpaper(String imageUrl) async {
    final String? localPath = await _downloadToTemp(imageUrl);
    if (localPath == null) return false;

    try {
      final bool? result = await _channel.invokeMethod<bool>(
        'setWallpaper',
        {'path': localPath},
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Downloads [url] into the system temp directory and returns the file path.
  Future<String?> _downloadToTemp(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;

      final dir = await getTemporaryDirectory();
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      final filename =
          segments.isNotEmpty ? segments.last : 'wallpaper.jpg';
      final ext =
          filename.contains('.') ? filename.split('.').last : 'jpg';

      final file = File('${dir.path}/yol_wallpaper.$ext');
      await file.writeAsBytes(response.bodyBytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}
