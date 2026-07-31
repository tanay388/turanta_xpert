import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceHeaders {
  const DeviceHeaders({
    required this.deviceId,
    required this.platform,
    this.brand,
    this.model,
    this.deviceName,
    this.osVersion,
    this.appVersion,
    this.notificationToken,
  });

  final String deviceId;
  final String platform;
  final String? brand;
  final String? model;
  final String? deviceName;
  final String? osVersion;
  final String? appVersion;
  final String? notificationToken;

  Map<String, String> toHeaders() {
    return {
      'device-id': deviceId,
      'device-platform': platform,
      if (brand != null && brand!.isNotEmpty) 'device-brand': brand!,
      if (model != null && model!.isNotEmpty) 'device-model': model!,
      if (deviceName != null && deviceName!.isNotEmpty) 'device-name': deviceName!,
      if (osVersion != null && osVersion!.isNotEmpty) 'os-version': osVersion!,
      if (appVersion != null && appVersion!.isNotEmpty) 'app-version': appVersion!,
      if (notificationToken != null && notificationToken!.isNotEmpty)
        'notification-token': notificationToken!,
    };
  }

  DeviceHeaders copyWith({
    String? brand,
    String? model,
    String? deviceName,
    String? osVersion,
    String? appVersion,
    String? notificationToken,
    bool clearNotificationToken = false,
  }) {
    return DeviceHeaders(
      deviceId: deviceId,
      platform: platform,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      deviceName: deviceName ?? this.deviceName,
      osVersion: osVersion ?? this.osVersion,
      appVersion: appVersion ?? this.appVersion,
      notificationToken: clearNotificationToken
          ? null
          : (notificationToken ?? this.notificationToken),
    );
  }
}

class DeviceInfoService {
  static const _deviceIdKey = 'xpert_device_id';

  DeviceHeaders? _cached;
  Future<DeviceHeaders>? _loading;
  String? _notificationToken;

  String? get notificationToken => _notificationToken;

  void setNotificationToken(String? token) {
    final next = (token == null || token.isEmpty) ? null : token;
    _notificationToken = next;
    if (_cached != null) {
      _cached = next == null
          ? _cached!.copyWith(clearNotificationToken: true)
          : _cached!.copyWith(notificationToken: next);
    }
  }

  Future<DeviceHeaders> getHeaders({String? notificationToken}) async {
    final base = _cached ?? await (_loading ??= _load());
    _cached = base;
    final token = notificationToken ?? _notificationToken;
    if (token == null) {
      return base.copyWith(clearNotificationToken: true);
    }
    return base.copyWith(notificationToken: token);
  }

  Future<DeviceHeaders> _load() async {
    try {
      final deviceId = await _stableDeviceId();
      final platform = (!kIsWeb && Platform.isIOS) ? 'ios' : 'android';

      String? brand;
      String? model;
      String? deviceName;
      String? osVersion;
      String? appVersion;

      try {
        final package = await PackageInfo.fromPlatform();
        appVersion = '${package.version}+${package.buildNumber}';
      } catch (e) {
        debugPrint('[DeviceInfo] package_info failed: $e');
        appVersion = 'unknown';
      }

      try {
        final plugin = DeviceInfoPlugin();
        if (!kIsWeb && Platform.isIOS) {
          final ios = await plugin.iosInfo;
          brand = 'Apple';
          model = ios.utsname.machine;
          deviceName = ios.name;
          osVersion = ios.systemVersion;
        } else if (!kIsWeb && Platform.isAndroid) {
          final android = await plugin.androidInfo;
          brand = android.brand;
          model = android.model;
          deviceName = android.device;
          osVersion = android.version.release;
        }
      } catch (e) {
        debugPrint('[DeviceInfo] device_info failed: $e');
      }

      return DeviceHeaders(
        deviceId: deviceId,
        platform: platform,
        brand: brand,
        model: model,
        deviceName: deviceName,
        osVersion: osVersion,
        appVersion: appVersion,
      );
    } finally {
      _loading = null;
    }
  }

  /// Prefer SharedPreferences — more reliable on simulator than Keychain during
  /// hot restart / missing plugin registration.
  Future<String> _stableDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final created = const Uuid().v4();
    await prefs.setString(_deviceIdKey, created);
    return created;
  }
}
