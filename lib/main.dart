import 'dart:io';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'background/background_task.dart';
import 'ui/home_screen.dart';
import 'ui/tray_setup.dart';
import 'utils/proxy_overrides.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Detect and apply system proxy settings for all platforms.
  HttpOverrides.global = await ProxyHttpOverrides.detect();

  if (Platform.isAndroid) {
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      'daily-wallpaper-unique-id',
      kDailyWallpaperTask,
      frequency: const Duration(hours: 24),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  if (Platform.isWindows || Platform.isMacOS) {
    // Initialize window_manager so we can resize/reposition the window.
    await windowManager.ensureInitialized();

    // Retrieve the primary display size and compute a window that has the same
    // aspect ratio while fitting comfortably on screen (≤ 80 % of each axis).
    final primaryDisplay = await screenRetriever.getPrimaryDisplay();
    final screenSize = primaryDisplay.size;

    const double targetFraction = 0.75;
    double winW = screenSize.width * targetFraction;
    double winH = screenSize.height * targetFraction;

    // Clamp so it still fits within 80 % of the screen on both sides.
    const double maxFraction = 0.80;
    if (winW / screenSize.width > maxFraction)
      winW = screenSize.width * maxFraction;
    if (winH / screenSize.height > maxFraction)
      winH = screenSize.height * maxFraction;

    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: Size(winW, winH),
        center: true,
        titleBarStyle: TitleBarStyle.normal,
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );

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
