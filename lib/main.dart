import 'dart:io';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'background/background_task.dart';
import 'ui/home_screen.dart';
import 'ui/tray_setup.dart';
import 'utils/proxy_overrides.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Detect and apply system proxy settings for all platforms.
  HttpOverrides.global = await ProxyHttpOverrides.detect();

  if (Platform.isAndroid) {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
    await Workmanager().registerPeriodicTask(
      'daily-wallpaper-unique-id',
      kDailyWallpaperTask,
      frequency: const Duration(hours: 24),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  if (Platform.isWindows || Platform.isMacOS) {
    await initTrayAndDailyTimer();
  }

  runApp(const YolApp());
}

class YolApp extends StatelessWidget {
  const YolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yol Wallpaper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          surface: Colors.black,
        ),
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
