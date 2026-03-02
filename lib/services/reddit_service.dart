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

  final http.Client _client;

  RedditService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches all qualifying image posts from r/EarthPorn for today.
  ///
  /// When [landscapeOnly] is true, only landscape images (width ≥ height) are
  /// returned.  When false, only portrait images (height > width) are returned.
  /// Returns an empty list if no qualifying posts are found.
  Future<List<WallpaperPost>> fetchWallpapers({
    required bool landscapeOnly,
  }) async {
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

    final results = <WallpaperPost>[];

    for (final child in children) {
      final data =
          (child as Map<String, dynamic>)['data'] as Map<String, dynamic>;

      final String? hint = data['post_hint'] as String?;
      final String? url =
          (data['url_overridden_by_dest'] ?? data['url']) as String?;

      if (hint != 'image' || url == null || !_isDirectImageUrl(url)) continue;

      // Extract source dimensions from preview metadata.
      final (int width, int height) = _sourceDimensions(data);

      // Filter by orientation when dimensions are available.
      if (width > 0 && height > 0) {
        final imageIsLandscape = width >= height;
        if (imageIsLandscape != landscapeOnly) continue;
      }

      results.add(WallpaperPost(
        title: (data['title'] as String?) ?? '',
        imageUrl: url,
        author: (data['author'] as String?) ?? '',
        sourceWidth: width,
        sourceHeight: height,
      ));
    }

    return results;
  }

  /// Fetches the top image post from r/EarthPorn for today.
  /// Returns null if no qualifying post is found.
  Future<WallpaperPost?> fetchTopWallpaper({
    required bool landscapeOnly,
  }) async {
    final posts = await fetchWallpapers(landscapeOnly: landscapeOnly);
    return posts.isEmpty ? null : posts.first;
  }

  bool _isDirectImageUrl(String url) {
    final lower = url.toLowerCase().split('?').first;
    return _imageExtensions.any((ext) => lower.endsWith(ext));
  }

  /// Extracts the source image width and height from the Reddit post's preview
  /// metadata. Returns (0, 0) if the field is absent.
  (int, int) _sourceDimensions(Map<String, dynamic> data) {
    try {
      final preview = data['preview'] as Map<String, dynamic>?;
      final images = preview?['images'] as List<dynamic>?;
      if (images == null || images.isEmpty) return (0, 0);
      final source =
          (images[0] as Map<String, dynamic>)['source'] as Map<String, dynamic>?;
      final w = (source?['width'] as num?)?.toInt() ?? 0;
      final h = (source?['height'] as num?)?.toInt() ?? 0;
      return (w, h);
    } catch (_) {
      return (0, 0);
    }
  }
}
