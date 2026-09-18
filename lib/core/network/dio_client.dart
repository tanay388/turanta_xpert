import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:talker/talker.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';
import 'retry_interceptor.dart';
import 'crash_reporting_interceptor.dart';

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
    settings: TalkerLoggerSettings(enableColors: false, maxLineWidth: 100),
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

/// How long the app waits for Firebase to hand over an ID token, and for the
/// device to describe itself, before giving up on a request.
///
/// Neither call has a deadline of its own, and both run before anything is
/// sent — so without these a stalled token fetch hangs every request in the
/// app with nothing in the logs to say so.
const authTokenTimeout = Duration(seconds: 12);
const deviceHeadersTimeout = Duration(seconds: 5);

/// The ID token, or a [TimeoutException] rather than a wait with no end.
Future<String?> idTokenOrTimeout(
  Future<String?> Function() fetch, {
  Duration timeout = authTokenTimeout,
}) => fetch().timeout(timeout);

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
      final String? token;
      try {
        token = await idTokenOrTimeout(() => user.getIdToken());
      } on TimeoutException {
        // Sending it unsigned would come back 401 and read as "signed out".
        return handler.reject(
          DioException.connectionTimeout(
            timeout: authTokenTimeout,
            requestOptions: options,
          ),
        );
      }
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401 ||
        err.requestOptions.extra['_retried'] == true) {
      return handler.next(err);
    }
    final user = _auth.currentUser;
    if (user == null) return handler.next(err);

    try {
      final token = await idTokenOrTimeout(() => user.getIdToken(true));
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
      final headers = await _deviceInfo.getHeaders().timeout(
        deviceHeadersTimeout,
      );
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
  dio.interceptors.add(RetryInterceptor());
  dio.interceptors.add(CrashReportingInterceptor());
  dio.interceptors.add(createHttpLogger());
  return dio;
});
