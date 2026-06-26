// End-to-end probe that drives the REAL RedditService against the live
// RSS feed, using a minimal HttpOverrides that routes through the Windows
// system proxy detected from the registry (mirrors ProxyHttpOverrides).
//
//   dart run tool/probe_reddit_service.dart
//
import 'dart:io';
import '../lib/services/reddit_service.dart';

bool isValidHostPort(String s) {
  final c = s.lastIndexOf(':');
  if (c <= 0) return false;
  final host = s.substring(0, c).trim();
  final port = s.substring(c + 1).trim();
  if (host.isEmpty) return false;
  final p = int.tryParse(port);
  return p != null && p >= 0 && p <= 65535;
}

Future<String?> windowsProxy() async {
  final en = await Process.run('reg', [
    'query',
    r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
    '/v', 'ProxyEnable',
  ]);
  if (en.exitCode != 0 || !(en.stdout as String).contains('0x1')) return null;
  final sv = await Process.run('reg', [
    'query',
    r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
    '/v', 'ProxyServer',
  ]);
  if (sv.exitCode != 0) return null;
  final m = RegExp(r'ProxyServer\s+REG_SZ\s+(.+)').firstMatch(sv.stdout as String);
  final raw = m?.group(1)?.trim();
  if (raw == null) return null;
  String? plain;
  final byProto = <String, String>{};
  for (final t in raw.split(';')) {
    final tok = t.trim();
    if (tok.isEmpty) continue;
    final eq = tok.indexOf('=');
    if (eq <= 0) {
      if (plain == null && isValidHostPort(tok)) plain = tok;
    } else {
      final proto = tok.substring(0, eq).trim().toLowerCase();
      final hp = tok.substring(eq + 1).trim();
      if (isValidHostPort(hp)) byProto[proto] = hp;
    }
  }
  return byProto['https'] ?? byProto['http'] ?? plain;
}

class _Overrides extends HttpOverrides {
  final String? proxy;
  _Overrides(this.proxy);
  @override
  HttpClient createHttpClient(SecurityContext? c) =>
    super.createHttpClient(c)
      ..connectionTimeout = const Duration(seconds: 15)
      ..findProxy = (uri) {
        final env = HttpClient.findProxyFromEnvironment(uri);
        if (env != 'DIRECT') return env;
        if (proxy != null && isValidHostPort(proxy!)) return 'PROXY $proxy';
        return 'DIRECT';
      };
}

Future<void> main() async {
  final proxy = await windowsProxy();
  print('Detected proxy: "$proxy"');
  HttpOverrides.global = _Overrides(proxy);

  for (final landscapeOnly in [true, false]) {
    print('\n=== fetchWallpapers(landscapeOnly: $landscapeOnly) ===');
    try {
      final posts = await RedditService()
          .fetchWallpapers(landscapeOnly: landscapeOnly)
          .timeout(const Duration(seconds: 40));
      print('=> got ${posts.length} posts');
      for (final p in posts.take(3)) {
        print('   - ${p.title}');
        print('     url=${p.imageUrl}  author=${p.author}  '
            'size=${p.sourceWidth}x${p.sourceHeight}  '
            'landscape=${p.isLandscape}');
      }
    } catch (e) {
      print('=> ERROR: $e');
    }
  }
}
