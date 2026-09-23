import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:talker/talker.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';
import 'retry_interceptor.dart';
import 'crash_reporting_interceptor.dart';

import '../auth/session_reset.dart';
import '../auth/token_store.dart';
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

const deviceHeadersTimeout = Duration(seconds: 5);

/// Attaches the access token, refreshing it shortly before it expires and
/// once on a 401. Parallel requests share one refresh.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._dio, this._tokens);
  final Dio _dio;
  final TokenStore _tokens;
  late final Dio _refreshDio = Dio(
    BaseOptions(
      baseUrl: _dio.options.baseUrl,
      connectTimeout: _dio.options.connectTimeout,
      receiveTimeout: _dio.options.receiveTimeout,
    ),
  );
  Future<AuthTokens?>? _refreshing;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    var tokens = await _tokens.read();
    if (tokens != null && tokens.expiresSoon) {
      tokens = await _refresh() ?? await _tokens.read();
    }
    if (tokens != null) {
      options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401 ||
        err.requestOptions.extra['_retried'] == true ||
        await _tokens.read() == null) {
      return handler.next(err);
    }
    final tokens = await _refresh();
    if (tokens == null) return handler.next(err);
    try {
      final retried = err.requestOptions..extra['_retried'] = true;
      return handler.resolve(await _dio.fetch(retried));
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  Future<AuthTokens?> _refresh() =>
      _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  /// Only the server saying the session is over signs the partner out; a
  /// timeout or a 5xx keeps the session for the next attempt.
  Future<AuthTokens?> _doRefresh() async {
    final current = await _tokens.read();
    if (current == null) return null;
    try {
      final res = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': current.refreshToken},
      );
      final next = current.rotated(res.data!);
      await _tokens.save(next);
      return next;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) await endSession();
      return null;
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
  dio.interceptors.add(AuthInterceptor(dio, TokenStore.instance));
  dio.interceptors.add(RetryInterceptor());
  dio.interceptors.add(CrashReportingInterceptor());
  dio.interceptors.add(createHttpLogger());
  return dio;
});
