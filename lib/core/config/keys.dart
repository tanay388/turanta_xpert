import 'dart:io' show Platform;

class AppKeys {
  AppKeys._();

  /// NestJS turanta-backend base URL.
  ///
  /// Prefer `127.0.0.1` over `localhost` on iOS — `localhost` can resolve to
  /// IPv6 `::1` and hit a different process bound only on loopback IPv6
  /// (e.g. Vite admin) while Nest listens on IPv4 `*:3033`.
  static String get apiBaseUrl {
    return 'https://turanta-app-hrggf.ondigitalocean.app';
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;
    if (Platform.isAndroid) return 'http://10.0.2.2:3033';
    return 'http://127.0.0.1:3033';
  }
}
