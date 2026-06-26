import 'dart:io';
import 'package:flutter/services.dart';

/// Sets up system-level HTTP proxy detection and applies it globally via
/// [HttpOverrides.global] so that every [HttpClient] in the process (including
/// the one used by the `http` package) automatically routes through the
/// system proxy.
///
/// Resolution order for each request:
///   1. Environment variables (HTTP_PROXY / HTTPS_PROXY / http_proxy /
///      https_proxy, with NO_PROXY / no_proxy for exclusions).
///      Most proxy tools (Clash, v2rayN, Proxyman, …) set these when
///      "Use system proxy" is enabled.
///   2. Native OS proxy settings detected at startup:
///      - Windows : HKCU registry (same source as IE / Edge proxy)
///      - macOS   : scutil --proxy (same source as System Preferences)
///      - Android : Java system properties http.proxyHost / http.proxyPort
///        (read via a MethodChannel in MainActivity.kt)
///   3. DIRECT (no proxy).
///
/// On Windows the `ProxyServer` registry value can be either:
///   - `host:port`                         (one proxy for all protocols), or
///   - `http=h:p;https=h:p;ftp=h:p;socks=h:p` (per-protocol).
/// We parse both forms and keep separate `http` / `https` entries so that
/// `findProxy` can choose the right one based on the request URI's scheme.
class ProxyHttpOverrides extends HttpOverrides {
  final String? _httpProxy; // host:port for http:// requests
  final String? _httpsProxy; // host:port for https:// requests

  ProxyHttpOverrides._(this._httpProxy, this._httpsProxy);

  /// Detects the current OS proxy settings and returns a configured
  /// [ProxyHttpOverrides] instance. Call once at app startup before
  /// [runApp].
  static Future<ProxyHttpOverrides> detect() async {
    String? httpProxy;
    String? httpsProxy;
    try {
      if (Platform.isWindows) {
        final (http, https) = await _windowsProxy();
        httpProxy = http;
        httpsProxy = https;
      } else if (Platform.isMacOS) {
        final proxy = await _macOsProxy();
        httpProxy = httpsProxy = proxy;
      } else if (Platform.isAndroid) {
        final proxy = await _androidProxy();
        httpProxy = httpsProxy = proxy;
      }
    } catch (_) {
      // Proxy detection is best-effort; failures are silently ignored.
    }
    return ProxyHttpOverrides._(httpProxy, httpsProxy);
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      // Fail fast on dead/unreachable proxies instead of hanging forever.
      ..connectionTimeout = const Duration(seconds: 15)
      ..findProxy = (uri) {
        // 1. Check environment variables first.
        final env = HttpClient.findProxyFromEnvironment(uri);
        if (env != 'DIRECT') return env;

        // 2. Fall back to the value detected at startup from OS settings,
        //    choosing the entry matching the request scheme. Validate the
        //    host:port before returning so a malformed registry value can
        //    never produce an unparseable PROXY directive.
        final chosen = uri.scheme == 'https' ? _httpsProxy : _httpProxy;
        if (chosen != null && chosen.isNotEmpty && _isValidHostPort(chosen)) {
          return 'PROXY $chosen';
        }
        return 'DIRECT';
      };
  }

  // ---------------------------------------------------------------------------
  // Validation helpers
  // ---------------------------------------------------------------------------

  /// Returns true when [s] looks like a usable `host:port` string.
  static bool _isValidHostPort(String s) {
    final colon = s.lastIndexOf(':');
    if (colon <= 0) return false;
    final host = s.substring(0, colon).trim();
    final port = s.substring(colon + 1).trim();
    if (host.isEmpty) return false;
    final portNum = int.tryParse(port);
    return portNum != null && portNum >= 0 && portNum <= 65535;
  }

  // ---------------------------------------------------------------------------
  // Platform-specific readers
  // ---------------------------------------------------------------------------

  /// Reads the Windows system proxy from the Internet Settings registry key.
  ///
  /// Returns `(httpProxy, httpsProxy)` where each is `host:port` or null.
  /// Both can be null when the proxy is disabled / not set, or when the
  /// stored value is malformed.
  static Future<(String?, String?)> _windowsProxy() async {
    // Check ProxyEnable first.
    final enableResult = await Process.run('reg', [
      'query',
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
      '/v',
      'ProxyEnable',
    ]);
    if (enableResult.exitCode != 0) return (null, null);
    // The registry value is shown as 0x1 when enabled.
    if (!(enableResult.stdout as String).contains('0x1')) return (null, null);

    final serverResult = await Process.run('reg', [
      'query',
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
      '/v',
      'ProxyServer',
    ]);
    if (serverResult.exitCode != 0) return (null, null);

    final match = RegExp(r'ProxyServer\s+REG_SZ\s+(.+)')
        .firstMatch(serverResult.stdout as String);
    final raw = match?.group(1)?.trim();
    if (raw == null || raw.isEmpty) return (null, null);

    // The value can be either:
    //   "host:port"                          (single proxy, all protocols)
    //   "http=h:p;https=h:p;ftp=h:p;socks=h:p" (per-protocol)
    // We split on ';' and inspect each token.
    String? plain;
    final Map<String, String> byProto = {};
    for (final token in raw.split(';')) {
      final t = token.trim();
      if (t.isEmpty) continue;
      final eq = t.indexOf('=');
      if (eq <= 0) {
        // No protocol prefix -> plain "host:port" applying to all protocols.
        if (plain == null && _isValidHostPort(t)) plain = t;
      } else {
        final proto = t.substring(0, eq).trim().toLowerCase();
        final hp = t.substring(eq + 1).trim();
        if (_isValidHostPort(hp)) byProto[proto] = hp;
      }
    }

    // Prefer the scheme-specific entry; fall back to the plain value and
    // then to the other scheme's entry (many setups use one proxy for both).
    final http = byProto['http'] ?? plain;
    final https = byProto['https'] ?? byProto['http'] ?? plain;
    return (http, https);
  }

  /// Reads the macOS HTTP proxy via `scutil --proxy`.
  /// Returns "host:port" or null if proxy is disabled / not set.
  static Future<String?> _macOsProxy() async {
    final result = await Process.run('scutil', ['--proxy']);
    if (result.exitCode != 0) return null;

    final output = result.stdout as String;

    // HTTPEnable must be 1.
    final enableMatch =
        RegExp(r'HTTPEnable\s*:\s*(\d+)').firstMatch(output);
    if (enableMatch?.group(1) != '1') return null;

    final hostMatch =
        RegExp(r'HTTPProxy\s*:\s*(\S+)').firstMatch(output);
    if (hostMatch == null) return null;

    final portMatch =
        RegExp(r'HTTPPort\s*:\s*(\d+)').firstMatch(output);

    final host = hostMatch.group(1)!.trim();
    final port = portMatch?.group(1)?.trim() ?? '80';
    final hp = '$host:$port';
    return _isValidHostPort(hp) ? hp : null;
  }

  /// Reads the Android system proxy via the MethodChannel registered in
  /// MainActivity.kt, which calls System.getProperty("http.proxyHost/Port").
  /// Returns "host:port" or null.
  static Future<String?> _androidProxy() async {
    const channel = MethodChannel('com.example.yol_app/system');
    final proxy = await channel.invokeMethod<String?>('getSystemProxy');
    if (proxy == null || proxy.isEmpty || !_isValidHostPort(proxy)) return null;
    return proxy;
  }
}