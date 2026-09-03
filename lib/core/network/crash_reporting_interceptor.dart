import 'package:dio/dio.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Reports network failures to Crashlytics as non-fatals.
///
/// A request that times out is not a crash, so the connectivity users actually
/// hit never reaches Crashlytics on its own. Only failures the server never
/// answered, or answered with a 5xx, are recorded: a 4xx is the backend
/// correctly rejecting a request, and recording those would bury the transport
/// failures worth acting on.
///
/// Must be registered after the retry interceptor so a request that recovered
/// on its second attempt is not reported as a failure.
class CrashReportingInterceptor extends Interceptor {
  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final request = response.requestOptions;
    FirebaseCrashlytics.instance.log(
      '${request.method} ${request.path} -> ${response.statusCode}',
    );
    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final status = err.response?.statusCode;
    final neverAnswered = status == null;
    final serverFault = status != null && status >= 500;

    if (!neverAnswered && !serverFault) {
      return handler.next(err);
    }

    final request = err.requestOptions;
    final crashlytics = FirebaseCrashlytics.instance;
    try {
      await crashlytics.setCustomKey(
        'net_endpoint',
        '${request.method} ${request.path}',
      );
      await crashlytics.setCustomKey('net_error_type', err.type.name);
      await crashlytics.setCustomKey('net_status', status ?? -1);
      await crashlytics.setCustomKey(
        'net_retries',
        (request.extra['_retryAttempt'] as int?) ?? 0,
      );
      await crashlytics.recordError(
        err,
        err.stackTrace,
        reason: 'Network ${err.type.name} on ${request.method} ${request.path}',
        fatal: false,
      );
    } catch (_) {
      // Reporting must never replace the error the caller is waiting for.
    }

    handler.next(err);
  }
}
