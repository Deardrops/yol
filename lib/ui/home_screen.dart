import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/wallpaper_post.dart';
import '../services/reddit_service.dart';
import '../services/wallpaper_service.dart';
import '../services/storage_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _reddit = RedditService();
  final _wallpaperSvc = WallpaperService();
  final _storage = StorageService();

  WallpaperPost? _post;
  bool _loading = true;
  bool _setting = false;
  bool _setToday = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final post = await _reddit.fetchTopWallpaper();
      final lastUrl = await _storage.getLastWallpaperUrl();
      setState(() {
        _post = post;
        _loading = false;
        _setToday = lastUrl != null && lastUrl == post?.imageUrl;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Could not load wallpaper: $e';
      });
    }
  }

  Future<void> _onSetPressed() async {
    if (_post == null || _setting) return;
    setState(() => _setting = true);

    final ok = await _wallpaperSvc.setWallpaper(_post!.imageUrl);
    if (ok) {
      await _storage.saveLastWallpaperUrl(_post!.imageUrl);
      await _storage.saveLastSetDate(DateTime.now());
    }

    setState(() {
      _setting = false;
      _setToday = ok;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Wallpaper set successfully.' : 'Failed to set wallpaper.'),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildImage(),
          const Align(
            alignment: Alignment.bottomCenter,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.4, 1],
                  colors: [Colors.transparent, Colors.transparent, Colors.black87],
                ),
              ),
              child: SizedBox(height: 220, width: double.infinity),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: _buildBottomPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: Colors.white54, size: 48),
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _load,
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }
    if (_post == null) {
      return const Center(
        child: Text('No wallpaper found for today.',
            style: TextStyle(color: Colors.white54)),
      );
    }
    return CachedNetworkImage(
      imageUrl: _post!.imageUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
      errorWidget: (_, __, ___) => const Center(
        child: Icon(Icons.broken_image, color: Colors.white38, size: 64),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_post != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
            child: Text(
              _post!.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.4,
                shadows: [Shadow(blurRadius: 12, color: Colors.black)],
              ),
            ),
          ),
        const SizedBox(height: 8),
        _buildSetButton(),
      ],
    );
  }

  Widget _buildSetButton() {
    final bool supported =
        Platform.isAndroid || Platform.isWindows || Platform.isMacOS;
    if (!supported) return const SizedBox.shrink();

    return ElevatedButton.icon(
      onPressed: (_loading || _post == null || _setting) ? null : _onSetPressed,
      icon: _setting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : Icon(_setToday ? Icons.check_circle_outline : Icons.wallpaper),
      label: Text(_setToday ? 'Wallpaper Set' : 'Set as Wallpaper'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.15),
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white38,
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        elevation: 0,
      ),
    );
  }
}
