import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/wallpaper_post.dart';

class RedditService {
  static const String _endpoint =
      'https://www.reddit.com/r/EarthPorn/top.json?t=day&limit=25';

  // Reddit blocks requests with the default Dart User-Agent.
  static const String _userAgent =
      'flutter:com.example.yol_app:v1.0.0 (by /u/yol_app_dev)';

  static const Set<String> _imageExtensions = {'.jpg', '.jpeg', '.png'};

  // Minimum source width required
  static const int _minWidth = 2499;

  final http.Client _client;

  RedditService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches the top image post from r/EarthPorn for today.
  /// Returns null if no qualifying post is found.
  Future<WallpaperPost?> fetchTopWallpaper() async {
    final uri = Uri.parse(_endpoint);
    final response = await _client.get(
      uri,
      headers: {'User-Agent': _userAgent},
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Reddit API returned HTTP ${response.statusCode}: ${response.body}');
    }

    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;

    final List<dynamic> children =
        (json['data'] as Map<String, dynamic>)['children'] as List<dynamic>;

    for (final child in children) {
      final data =
          (child as Map<String, dynamic>)['data'] as Map<String, dynamic>;

      final String? hint = data['post_hint'] as String?;
      final String? url =
          (data['url_overridden_by_dest'] ?? data['url']) as String?;

      if (hint != 'image' || url == null || !_isDirectImageUrl(url)) continue;

      // Check source width from the preview metadata.
      final int width = _sourceWidth(data);
      if (width < _minWidth) continue;

      return WallpaperPost(
        title: (data['title'] as String?) ?? '',
        imageUrl: url,
        author: (data['author'] as String?) ?? '',
      );
    }

    return null;
  }

  bool _isDirectImageUrl(String url) {
    final lower = url.toLowerCase().split('?').first;
    return _imageExtensions.any((ext) => lower.endsWith(ext));
  }

  /// Extracts the source image width from the Reddit post's preview metadata.
  /// Returns 0 if the field is absent (so the post is skipped by the filter).
  int _sourceWidth(Map<String, dynamic> data) {
    try {
      final preview = data['preview'] as Map<String, dynamic>?;
      final images = preview?['images'] as List<dynamic>?;
      if (images == null || images.isEmpty) return 0;
      final source =
          (images[0] as Map<String, dynamic>)['source'] as Map<String, dynamic>?;
      return (source?['width'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
