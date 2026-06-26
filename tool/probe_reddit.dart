// Standalone connectivity probe that mirrors the logic in
// lib/utils/proxy_overrides.dart (Windows registry parsing) and
// lib/services/reddit_service.dart (Reddit JSON request with timeout).
//
// Run with:  dart run tool/probe_reddit.dart
//
// It does NOT depend on Flutter, so it works as a plain Dart program on
// Windows. It prints exactly what proxy was detected and the Reddit HTTP
// status / error, which lets us verify the fix without the GUI.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const String endpoint =
    'https://www.reddit.com/r/EarthPorn/top.json?t=day&limit=25';
const String userAgent =
    'flutter:com.example.yol_app:v1.0.0 (by /u/yol_app_dev)';

bool isValidHostPort(String s) {
  final colon = s.lastIndexOf(':');
  if (colon <= 0) return false;
  final host = s.substring(0, colon).trim();
  final port = s.substring(colon + 1).trim();
  if (host.isEmpty) return false;
  final portNum = int.tryParse(port);
  return portNum != null && portNum >= 0 && portNum <= 65535;
}

/// Returns (httpProxy, httpsProxy) read from the Windows registry.
Future<(String?, String?)> windowsProxy() async {
  final enableResult = await Process.run('reg', [
    'query',
    r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
    '/v',
    'ProxyEnable',
  ]);
  if (enableResult.exitCode != 0) {
    print('ProxyEnable query exit=${enableResult.exitCode}');
    return (null, null);
  }
  final enableOut = enableResult.stdout as String;
  print('ProxyEnable output:\n$enableOut');
  if (!enableOut.contains('0x1')) {
    print('=> ProxyEnable is NOT 0x1 (system proxy disabled).');
    return (null, null);
  }

  final serverResult = await Process.run('reg', [
    'query',
    r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
    '/v',
    'ProxyServer',
  ]);
  if (serverResult.exitCode != 0) {
    print('ProxyServer query exit=${serverResult.exitCode}');
    return (null, null);
  }
  final serverOut = serverResult.stdout as String;
  print('ProxyServer output:\n$serverOut');

  final match =
      RegExp(r'ProxyServer\s+REG_SZ\s+(.+)').firstMatch(serverOut);
  final raw = match?.group(1)?.trim();
  print('Raw ProxyServer value: "$raw"');
  if (raw == null || raw.isEmpty) return (null, null);

  String? plain;
  final Map<String, String> byProto = {};
  for (final token in raw.split(';')) {
    final t = token.trim();
    if (t.isEmpty) continue;
    final eq = t.indexOf('=');
    if (eq <= 0) {
      if (plain == null && isValidHostPort(t)) plain = t;
    } else {
      final proto = t.substring(0, eq).trim().toLowerCase();
      final hp = t.substring(eq + 1).trim();
      if (isValidHostPort(hp)) byProto[proto] = hp;
    }
  }
  print('Parsed per-protocol: $byProto; plain="$plain"');

  final http = byProto['http'] ?? plain;
  final https = byProto['https'] ?? byProto['http'] ?? plain;
  return (http, https);
}

Future<void> main() async {
  // --- 1. Detect Windows proxy ---
  print('=== Detecting Windows system proxy ===');
  final (httpProxy, httpsProxy) = await windowsProxy();
  print('=> httpProxy  = "$httpProxy"');
  print('=> httpsProxy = "$httpsProxy"');

  // --- 2. Apply an HttpOverrides that mirrors ProxyHttpOverrides ---
  HttpOverrides.global = _ProbeOverrides(httpsProxy ?? httpProxy);

  // --- 3. Fetch Reddit with a 20s timeout, same as RedditService ---
  print('\n=== Fetching $endpoint ===');
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 15);
  try {
    final req = await client.getUrl(Uri.parse(endpoint));
    req.headers.set('User-Agent', userAgent);
    final resp = await req.close().timeout(const Duration(seconds: 20));
    final body = await resp.transform(utf8.decoder).join();
    print('HTTP status: ${resp.statusCode}');
    final preview = body.length > 300 ? body.substring(0, 300) : body;
    print('Body preview: $preview');

    if (resp.statusCode == 200) {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final children =
          (json['data'] as Map<String, dynamic>)['children'] as List<dynamic>;
      print('=> SUCCESS: parsed ${children.length} posts');
    } else {
      print('=> FAIL: non-200 status ${resp.statusCode}');
    }
  } on TimeoutException {
    print('=> FAIL: TimeoutException after 20s (network/proxy unreachable)');
  } catch (e, st) {
    print('=> FAIL: $e');
    print(st.toString().split('\n').take(4).join('\n'));
  } finally {
    client.close();
  }
}

class _ProbeOverrides extends HttpOverrides {
  final String? _proxy;
  _ProbeOverrides(this._proxy);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..connectionTimeout = const Duration(seconds: 15)
      ..findProxy = (uri) {
        final env = HttpClient.findProxyFromEnvironment(uri);
        if (env != 'DIRECT') {
          print('findProxy($uri) -> env: $env');
          return env;
        }
        if (_proxy != null && _proxy!.isNotEmpty && isValidHostPort(_proxy!)) {
          final directive = 'PROXY $_proxy';
          print('findProxy($uri) -> $directive');
          return directive;
        }
        print('findProxy($uri) -> DIRECT');
        return 'DIRECT';
      };
  }
}