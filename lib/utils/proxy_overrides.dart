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
class ProxyHttpOverrides extends HttpOverrides {
  final String? _detected;

  ProxyHttpOverrides._(this._detected);

  /// Detects the current OS proxy settings and returns a configured
  /// [ProxyHttpOverrides] instance. Call once at app startup before
  /// [runApp].
  static Future<ProxyHttpOverrides> detect() async {
    String? detected;
    try {
      if (Platform.isWindows) {
        detected = await _windowsProxy();
      } else if (Platform.isMacOS) {
        detected = await _macOsProxy();
      } else if (Platform.isAndroid) {
        detected = await _androidProxy();
      }
    } catch (_) {
      // Proxy detection is best-effort; failures are silently ignored.
    }
    return ProxyHttpOverrides._(detected);
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..findProxy = (uri) {
        // 1. Check environment variables first.
        final env = HttpClient.findProxyFromEnvironment(uri);
        if (env != 'DIRECT') return env;

        // 2. Fall back to the value detected at startup from OS settings.
        if (_detected != null && _detected.isNotEmpty) {
          return 'PROXY $_detected';
        }
        return 'DIRECT';
      };
  }

  // ---------------------------------------------------------------------------
  // Platform-specific readers
  // ---------------------------------------------------------------------------

  /// Reads the Windows system proxy from the Internet Settings registry key.
  /// Returns "host:port" or null if proxy is disabled / not set.
  static Future<String?> _windowsProxy() async {
    // Check ProxyEnable first.
    final enableResult = await Process.run('reg', [
      'query',
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
      '/v',
      'ProxyEnable',
    ]);
    if (enableResult.exitCode != 0) return null;
    // The registry value is shown as 0x1 when enabled.
    if (!(enableResult.stdout as String).contains('0x1')) return null;

    final serverResult = await Process.run('reg', [
      'query',
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
      '/v',
      'ProxyServer',
    ]);
    if (serverResult.exitCode != 0) return null;

    final match = RegExp(r'ProxyServer\s+REG_SZ\s+(\S+)')
        .firstMatch(serverResult.stdout as String);
    return match?.group(1)?.trim();
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
    return '$host:$port';
  }

  /// Reads the Android system proxy via the MethodChannel registered in
  /// MainActivity.kt, which calls System.getProperty("http.proxyHost/Port").
  /// Returns "host:port" or null.
  static Future<String?> _androidProxy() async {
    const channel = MethodChannel('com.example.yol_app/system');
    final proxy = await channel.invokeMethod<String?>('getSystemProxy');
    return proxy;
  }
}
