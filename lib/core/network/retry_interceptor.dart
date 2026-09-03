import 'dart:math';

import 'package:dio/dio.dart';

/// Retries a request that failed before the server ever answered.
///
/// On a weak mobile network a handshake stalls or a socket drops mid-response
/// often enough that one attempt is not a fair test of reachability — the user
/// sees "couldn't reach the server" for a link that would have worked a second
/// later. Only transport-level failures and the gateway 5xx codes are retried,
/// and only for methods that are safe to repeat: anything that already reached
/// the server and was rejected on its merits is passed straight through.
class RetryInterceptor extends Interceptor {
  RetryInterceptor({this.maxAttempts = 3});

  final int maxAttempts;

  static const _attemptKey = '_retryAttempt';
  static const _idempotent = {'GET', 'HEAD', 'OPTIONS'};
  static const _retriableStatus = {502, 503, 504};

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final attempt = (request.extra[_attemptKey] as int? ?? 0) + 1;

    if (attempt >= maxAttempts || !_shouldRetry(err)) {
      return handler.next(err);
    }

    await Future<void>.delayed(_backoff(attempt));
    request.extra[_attemptKey] = attempt;

    try {
      // A bare client: the original options already carry the resolved URL,
      // headers and timeouts, and re-running the interceptor chain would
      // re-enter this one.
      final response = await Dio().fetch<dynamic>(request);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  bool _shouldRetry(DioException err) {
    if (!_idempotent.contains(err.requestOptions.method.toUpperCase())) {
      return false;
    }
    return switch (err.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => true,
      DioExceptionType.badResponse =>
        _retriableStatus.contains(err.response?.statusCode),
      _ => false,
    };
  }

  /// Exponential, with jitter so a flapping tower does not resynchronise every
  /// client onto the same retry instant.
  Duration _backoff(int attempt) {
    final base = 400 * pow(2, attempt - 1).toInt();
    return Duration(milliseconds: base + Random().nextInt(250));
  }
}
