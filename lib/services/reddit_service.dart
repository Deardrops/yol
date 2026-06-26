import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import '../models/wallpaper_post.dart';

/// Fetches image posts from Reddit's r/EarthPorn.
///
/// Reddit's public `.json` endpoints now routinely return HTTP 403 to
/// unauthenticated/automated clients, while the Atom `.rss` feed still
/// accepts a descriptive custom User-Agent.  We therefore read the RSS
/// feed and parse the Atom XML instead of the JSON API.
class RedditService {
  static const String _endpoint =
      'https://www.reddit.com/r/EarthPorn/top/.rss?t=day&limit=25';

  // Reddit blocks requests with the default Dart User-Agent.  A descriptive
  // UA following Reddit's bot guidelines (`platform:app:version (by /u/...)`)
  // is accepted by the RSS feed.
  static const String _userAgent =
      'flutter:com.example.yol_app:v1.0.0 (by /u/yol_app_dev)';

  static const Set<String> _imageExtensions = {'.jpg', '.jpeg', '.png'};

  /// Maximum retries for transient failures (429 / 5xx).
  static const int _maxRetries = 2;

  /// Upper bound on a single retry delay so we never block the UI too long.
  static const Duration _maxRetryDelay = Duration(seconds: 8);

  final http.Client _client;

  RedditService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches all qualifying image posts from r/EarthPorn for today.
  ///
  /// When [landscapeOnly] is true, only landscape images (width ≥ height) are
  /// returned.  When false, only portrait images (height > width) are
  /// returned.  Posts whose dimensions cannot be determined are always
  /// included (best-effort).  Returns an empty list if no qualifying posts
  /// are found.
  Future<List<WallpaperPost>> fetchWallpapers({
    required bool landscapeOnly,
  }) async {
    final body = await _fetchFeedWithRetries();
    return _parseAtomFeed(body, landscapeOnly: landscapeOnly);
  }

  /// Fetches the top image post from r/EarthPorn for today.
  /// Returns null if no qualifying post is found.
  Future<WallpaperPost?> fetchTopWallpaper({
    required bool landscapeOnly,
  }) async {
    final posts = await fetchWallpapers(landscapeOnly: landscapeOnly);
    return posts.isEmpty ? null : posts.first;
  }

  // ---------------------------------------------------------------------------
  // Networking
  // ---------------------------------------------------------------------------

  /// GETs the RSS feed, retrying on 429 / 5xx with exponential backoff.
  /// Throws [Exception] with a human-readable message on terminal failure.
  Future<String> _fetchFeedWithRetries() async {
    final uri = Uri.parse(_endpoint);
    for (var attempt = 0;; attempt++) {
      http.Response response;
      try {
        response = await _client
            .get(uri, headers: {'User-Agent': _userAgent})
            .timeout(const Duration(seconds: 20));
      } on TimeoutException {
        throw Exception('Reddit request timed out after 20s — '
            'check network/proxy settings.');
      }

      if (response.statusCode == 200) return response.body;

      // 403 means Reddit is actively blocking this client; retrying won't
      // help, so surface a clear message immediately.
      if (response.statusCode == 403) {
        throw Exception('Reddit returned 403 (blocked). The RSS feed may be '
            'unavailable from this network/IP; try a different proxy or '
            'wait and retry later.');
      }

      // Transient errors: retry with backoff.
      if (_isTransient(response.statusCode) && attempt < _maxRetries) {
        final delay = _retryDelay(response, attempt);
        await Future.delayed(delay);
        continue;
      }

      throw Exception('Reddit API returned HTTP ${response.statusCode}: '
          '${_truncate(response.body, 200)}');
    }
  }

  bool _isTransient(int status) =>
      status == 429 || status == 500 || status == 502 || status == 503;

  Duration _retryDelay(http.Response response, int attempt) {
    // Honour Retry-After (seconds) when present, capped to [_maxRetryDelay].
    final header = response.headers['retry-after'];
    if (header != null) {
      final secs = int.tryParse(header.trim());
      if (secs != null && secs > 0) {
        final clamped = secs < _maxRetryDelay.inSeconds
            ? secs
            : _maxRetryDelay.inSeconds;
        return Duration(seconds: clamped);
      }
    }
    // Exponential backoff: 2s, 4s, … capped.
    final secs = 1 << (attempt + 1); // 2, 4, 8, …
    return Duration(seconds: secs < _maxRetryDelay.inSeconds
        ? secs
        : _maxRetryDelay.inSeconds);
  }

  String _truncate(String s, int n) =>
      s.length > n ? '${s.substring(0, n)}…' : s;

  // ---------------------------------------------------------------------------
  // Atom parsing
  // ---------------------------------------------------------------------------

  List<WallpaperPost> _parseAtomFeed(
    String body, {
    required bool landscapeOnly,
  }) {
    final xml.XmlDocument doc;
    try {
      doc = xml.XmlDocument.parse(body);
    } catch (e) {
      throw Exception('Failed to parse Reddit RSS feed as XML: $e');
    }

    final results = <WallpaperPost>[];

    for (final entry in doc.findAllElements('entry')) {
      final title = _textOf(entry, 'title');
      final author = _authorOf(entry);
      final imageUrl = _directImageFromContent(entry);

      // Only keep direct image links (drops galleries, videos, text posts).
      if (imageUrl == null || !_isDirectImageUrl(imageUrl)) continue;

      final (width, height) = _dimensionsFromTitle(title);

      // Filter by orientation only when dimensions are known.
      if (width > 0 && height > 0) {
        final imageIsLandscape = width >= height;
        if (imageIsLandscape != landscapeOnly) continue;
      }

      results.add(WallpaperPost(
        title: title,
        imageUrl: imageUrl,
        author: author,
        sourceWidth: width,
        sourceHeight: height,
      ));
    }

    return results;
  }

  /// Returns the text content of the first descendant [name] element, or ''.
  String _textOf(xml.XmlElement parent, String name) {
    final el = parent.findAllElements(name).firstOrNull;
    return el?.innerText.trim() ?? '';
  }

  /// Extracts the author username (e.g. `/u/foo`) from `<author><name>`.
  String _authorOf(xml.XmlElement entry) {
    final author = entry.findAllElements('author').firstOrNull;
    if (author == null) return '';
    return _textOf(author, 'name');
  }

  /// The Atom `<content type="html">` holds an HTML-escaped snippet.  After
  /// XML-decoding it looks like:
  ///
  ///   <a href="https://i.redd.it/<id>.jpeg">[link]</a>
  ///
  /// where the href is the full-resolution direct image URL.  We extract that
  /// `[link]` anchor's href.  Returns null when no such link is present.
  String? _directImageFromContent(xml.XmlElement entry) {
    final content = entry.findAllElements('content').firstOrNull;
    if (content == null) return null;
    final html = content.innerText;
    final match = RegExp(r'<a\s+href="([^"]+)"[^>]*>\[link\]</a>')
        .firstMatch(html);
    final url = match?.group(1);
    if (url == null || url.isEmpty) return null;
    // HTML-unescape any remaining entities (e.g. &amp;) just in case.
    return _htmlUnescape(url);
  }

  String _htmlUnescape(String s) {
    // The XML parser already decoded the outer XML entities; the remaining
    // HTML-level entities inside the href are handled here.
    return s
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }

  bool _isDirectImageUrl(String url) {
    final lower = url.toLowerCase().split('?').first;
    return _imageExtensions.any((ext) => lower.endsWith(ext));
  }

  /// r/EarthPorn titles usually end with the source dimensions, e.g.
  /// `... [OC] 1080×1603`.  We parse the *last* `WxH` occurrence in the title.
  /// Returns (0, 0) when no dimensions are found.
  (int, int) _dimensionsFromTitle(String title) {
    final regex = RegExp(r'(\d{2,5})\s*[×xX]\s*(\d{2,5})');
    final matches = regex.allMatches(title);
    if (matches.isEmpty) return (0, 0);
    final m = matches.last;
    final w = int.tryParse(m.group(1)!) ?? 0;
    final h = int.tryParse(m.group(2)!) ?? 0;
    return (w, h);
  }
}