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

  List<WallpaperPost> _posts = [];
  int _currentIndex = 0;
  bool _goForward = true; // tracks slide direction for animation

  bool _loading = true;
  bool _setting = false;
  bool _setToday = false;
  String? _error;

  WallpaperPost? get _post =>
      _posts.isEmpty ? null : _posts[_currentIndex];

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
      final posts = await _reddit.fetchWallpapers();
      final lastUrl = await _storage.getLastWallpaperUrl();
      setState(() {
        _posts = posts;
        _currentIndex = 0;
        _loading = false;
        _setToday = lastUrl != null &&
            posts.isNotEmpty &&
            lastUrl == posts[0].imageUrl;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Could not load wallpaper: $e';
      });
    }
  }

  void _goPrev() {
    if (_posts.isEmpty || _currentIndex <= 0) return;
    setState(() {
      _goForward = false;
      _currentIndex--;
      _checkSetToday();
    });
  }

  void _goNext() {
    if (_posts.isEmpty || _currentIndex >= _posts.length - 1) return;
    setState(() {
      _goForward = true;
      _currentIndex++;
      _checkSetToday();
    });
  }

  Future<void> _checkSetToday() async {
    final lastUrl = await _storage.getLastWallpaperUrl();
    if (mounted) {
      setState(() {
        _setToday = lastUrl != null && lastUrl == _post?.imageUrl;
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
        content:
            Text(ok ? 'Wallpaper set successfully.' : 'Failed to set wallpaper.'),
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
          _buildAnimatedImage(),
          const Align(
            alignment: Alignment.bottomCenter,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.4, 1],
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black87
                  ],
                ),
              ),
              child: SizedBox(height: 220, width: double.infinity),
            ),
          ),
          if (!_loading && _error == null) ...[
            _buildNavButton(isNext: false),
            _buildNavButton(isNext: true),
          ],
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

  Widget _buildAnimatedImage() {
    if (_loading) {
      return const Center(
        child: _PulsingLoader(),
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
                child:
                    const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }
    if (_posts.isEmpty) {
      return const Center(
        child: Text('No wallpaper found for today.',
            style: TextStyle(color: Colors.white54)),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) {
        final isIncoming = child.key == ValueKey(_posts[_currentIndex].imageUrl);
        final begin = isIncoming
            ? Offset(_goForward ? 1.0 : -1.0, 0)
            : Offset(_goForward ? -1.0 : 1.0, 0);
        final slide = Tween<Offset>(begin: begin, end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut));
        return SlideTransition(position: slide, child: child);
      },
      child: _PostImage(
        key: ValueKey(_posts[_currentIndex].imageUrl),
        imageUrl: _posts[_currentIndex].imageUrl,
      ),
    );
  }

  Widget _buildNavButton({required bool isNext}) {
    final canGo =
        isNext ? _currentIndex < _posts.length - 1 : _currentIndex > 0;
    return Positioned(
      top: 0,
      bottom: 0,
      left: isNext ? null : 0,
      right: isNext ? 0 : null,
      child: Center(
        child: AnimatedOpacity(
          opacity: canGo ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !canGo,
            child: _NavButton(
              icon: isNext ? Icons.chevron_right : Icons.chevron_left,
              onTap: isNext ? _goNext : _goPrev,
            ),
          ),
        ),
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
        if (_posts.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${_currentIndex + 1} / ${_posts.length}',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        elevation: 0,
      ),
    );
  }
}

/// Displays a single wallpaper image with its own loading/error state.
class _PostImage extends StatelessWidget {
  final String imageUrl;

  const _PostImage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (_, _) => const Center(
        child: _PulsingLoader(),
      ),
      errorWidget: (_, _, _) => const Center(
        child: Icon(Icons.broken_image, color: Colors.white38, size: 64),
      ),
    );
  }
}

/// A translucent circular nav button.
class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }
}

/// Animated loading indicator with a pulsing scale effect.
class _PulsingLoader extends StatefulWidget {
  const _PulsingLoader();

  @override
  State<_PulsingLoader> createState() => _PulsingLoaderState();
}

class _PulsingLoaderState extends State<_PulsingLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: const CircularProgressIndicator(
        color: Colors.white,
        strokeWidth: 2.5,
      ),
    );
  }
}
