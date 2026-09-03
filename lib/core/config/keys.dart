class AppKeys {
  AppKeys._();

  /// NestJS turanta-backend base URL. Defaults to production; point it
  /// elsewhere with `--dart-define=API_BASE_URL=…`.
  ///
  /// An Android emulator reaches a backend on the dev machine as `10.0.2.2`.
  /// On iOS prefer `127.0.0.1` over `localhost` — the latter can resolve to
  /// IPv6 `::1` and hit a different process bound only on loopback IPv6
  /// (e.g. Vite admin) while Nest listens on IPv4 `*:3033`.
  static String get apiBaseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;
    return 'https://api.myturanta.com';
  }
}
