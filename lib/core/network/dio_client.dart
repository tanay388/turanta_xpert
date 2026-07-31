import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:talker/talker.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';

import '../config/keys.dart';
import '../device/device_info_service.dart';

/// Shared Talker instance so HTTP logs render cleanly in the Flutter console
/// (boxed `[http-request]` / `[http-response]` / `[http-error]` blocks).
///
/// Colors off by default: with `flutter run` (esp. iOS), ANSI often shows up as
/// literal `\^[[38;5;46m…` instead of color. Cursor/VS Code *can* render ANSI
/// in a real terminal / Debug Console when the Dart adapter supports it — set
/// `enableColors: true` to try.
final appTalker = Talker(
  logger: TalkerLogger(
    settings: TalkerLoggerSettings(
      enableColors: false,
      maxLineWidth: 100,
    ),
  ),
);

/// Talker-style Dio logger matching the usual Flutter HTTP debug UX.
TalkerDioLogger createHttpLogger() {
  return TalkerDioLogger(
    talker: appTalker,
    settings: const TalkerDioLoggerSettings(
      printRequestData: true,
      printRequestHeaders: false,
      printRequestExtra: false,
      printResponseData: true,
      printResponseHeaders: false,
      printResponseMessage: true,
      printResponseTime: true,
      printErrorData: true,
      printErrorHeaders: false,
      printErrorMessage: true,
      hiddenHeaders: {'Authorization'},
    ),
  );
}

class FirebaseAuthInterceptor extends Interceptor {
  FirebaseAuthInterceptor(this._auth);
  final FirebaseAuth _auth;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final user = _auth.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 ||
        err.requestOptions.extra['_retried'] == true) {
      return handler.next(err);
    }
    final user = _auth.currentUser;
    if (user == null) return handler.next(err);

    try {
      final token = await user.getIdToken(true);
      final retried = err.requestOptions
        ..headers['Authorization'] = 'Bearer $token'
        ..extra['_retried'] = true;
      final dio = Dio(BaseOptions(baseUrl: retried.baseUrl));
      final response = await dio.fetch(retried);
      return handler.resolve(response);
    } catch (_) {
      return handler.next(err);
    }
  }
}

class DeviceHeadersInterceptor extends Interceptor {
  DeviceHeadersInterceptor(this._deviceInfo);
  final DeviceInfoService _deviceInfo;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final headers = await _deviceInfo.getHeaders();
      options.headers.addAll(headers.toHeaders());
    } catch (e, st) {
      // Never block API calls if device info collection fails.
      debugPrint('[Dio] device headers failed: $e\n$st');
    }
    handler.next(options);
  }
}

final deviceInfoServiceProvider = Provider<DeviceInfoService>((ref) {
  return DeviceInfoService();
});

final dioProvider = Provider<Dio>((ref) {
  final deviceInfo = ref.watch(deviceInfoServiceProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: AppKeys.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {'Accept': 'application/json'},
    ),
  );
  dio.interceptors.add(DeviceHeadersInterceptor(deviceInfo));
  dio.interceptors.add(FirebaseAuthInterceptor(FirebaseAuth.instance));
  dio.interceptors.add(createHttpLogger());
  return dio;
});
