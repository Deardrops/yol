import 'package:workmanager/workmanager.dart';
import '../services/reddit_service.dart';
import '../services/wallpaper_service.dart';
import '../services/storage_service.dart';

const String kDailyWallpaperTask = 'daily_wallpaper_task';

// @pragma prevents the Dart tree-shaker from removing this function in
// release mode. WorkManager's headless engine needs this entrypoint.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask(
      (String taskName, Map<String, dynamic>? inputData) async {
    if (taskName == kDailyWallpaperTask) {
      try {
        final post = await RedditService().fetchTopWallpaper();
        if (post != null) {
          final ok = await WallpaperService().setWallpaper(post.imageUrl);
          if (ok) {
            final storage = StorageService();
            await storage.saveLastWallpaperUrl(post.imageUrl);
            await storage.saveLastSetDate(DateTime.now());
          }
        }
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  });
}
