import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  static const _channel = MethodChannel('com.turanta.turanta_xpert/device');

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

  /// An id for this handset that survives the app being uninstalled.
  ///
  /// It used to be a UUID in SharedPreferences, which both platforms delete
  /// along with the app. A partner who reinstalled came back as a new device,
  /// hit DEVICE_MISMATCH, and could not log in until an admin cleared their
  /// binding — on the same phone they had been using all along.
  ///
  /// Order matters. An id already on this install is kept whatever its origin,
  /// so updating the app never changes who a working partner appears to be.
  /// Only a fresh install derives one, and then from somewhere that outlives
  /// the app: the Keychain on iOS, `ANDROID_ID` on Android.
  Future<String> _stableDeviceId() async {
    final prefs = await SharedPreferences.getInstance();

    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      // Carry an id from before this change into the Keychain, so the next
      // reinstall on this phone recognises them rather than locking them out.
      await _rememberInKeychain(existing);
      return existing;
    }

    final durable = await _durableDeviceId();
    final id = durable ?? const Uuid().v4();
    await prefs.setString(_deviceIdKey, id);
    if (durable == null) await _rememberInKeychain(id);
    return id;
  }

  /// Somewhere the id outlives an uninstall, or null if neither applies.
  Future<String?> _durableDeviceId() async {
    if (kIsWeb) return null;
    try {
      if (Platform.isAndroid) {
        final androidId = await _channel.invokeMethod<String>('getAndroidId');
        // Buggy ROMs have shipped this constant on every unit, so it
        // identifies a model rather than a phone.
        if (androidId != null &&
            androidId.isNotEmpty &&
            androidId != '9774d56d682e549c') {
          return 'android:$androidId';
        }
      }
      if (Platform.isIOS) {
        return await const FlutterSecureStorage(
          iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
        ).read(key: _deviceIdKey);
      }
    } catch (e) {
      debugPrint('[DeviceInfo] durable id unavailable: $e');
    }
    return null;
  }

  /// iOS only: the Keychain is not emptied when an app is deleted.
  Future<void> _rememberInKeychain(String id) async {
    if (kIsWeb || !Platform.isIOS) return;
    try {
      const storage = FlutterSecureStorage(
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      );
      if (await storage.read(key: _deviceIdKey) == id) return;
      await storage.write(key: _deviceIdKey, value: id);
    } catch (e) {
      // Never block a login over this — the prefs copy still works until the
      // app is deleted, which is exactly the case this is insuring against.
      debugPrint('[DeviceInfo] could not persist device id: $e');
    }
  }
}
