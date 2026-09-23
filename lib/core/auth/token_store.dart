import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
    required this.userId,
    required this.phone,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime accessExpiresAt;
  final String userId;
  final String phone;

  bool get expiresSoon => DateTime.now().isAfter(
    accessExpiresAt.subtract(const Duration(minutes: 5)),
  );

  AuthTokens rotated(Map<String, dynamic> json) => AuthTokens(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    accessExpiresAt: DateTime.now().add(
      Duration(seconds: json['expiresIn'] as int),
    ),
    userId: userId,
    phone: phone,
  );

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'accessExpiresAt': accessExpiresAt.toIso8601String(),
    'userId': userId,
    'phone': phone,
  };

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    accessExpiresAt: DateTime.parse(json['accessExpiresAt'] as String),
    userId: json['userId'] as String,
    phone: json['phone'] as String,
  );
}

/// The signed-in session, in the Keychain / Keystore.
class TokenStore {
  TokenStore._();
  static final instance = TokenStore._();

  static const _key = 'auth_tokens';
  static const _installedKey = 'auth_installed';

  // `first_unlock` so the FCM background isolate can still read it.
  final _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  AuthTokens? _cached;
  bool _loaded = false;

  Future<AuthTokens?> read() async {
    if (_loaded) return _cached;
    await _dropTokensFromPreviousInstall();
    try {
      final raw = await _storage.read(key: _key);
      _cached = raw == null
          ? null
          : AuthTokens.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      _cached = null;
    }
    _loaded = true;
    return _cached;
  }

  Future<void> save(AuthTokens tokens) async {
    _cached = tokens;
    _loaded = true;
    await _storage.write(key: _key, value: jsonEncode(tokens.toJson()));
  }

  Future<void> clear() async {
    _cached = null;
    _loaded = true;
    await _storage.delete(key: _key);
  }

  /// The iOS Keychain outlives an uninstall; SharedPreferences does not.
  Future<void> _dropTokensFromPreviousInstall() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_installedKey) == true) return;
    await _storage.delete(key: _key);
    await prefs.setBool(_installedKey, true);
  }
}
