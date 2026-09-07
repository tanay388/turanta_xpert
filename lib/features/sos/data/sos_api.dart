import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/dio_client.dart';

/// An emergency alert as the backend sees it.
class SosAlert {
  const SosAlert({
    required this.id,
    required this.status,
    this.bookingId,
    this.raisedAt,
  });

  final int id;
  final String status;
  final int? bookingId;
  final DateTime? raisedAt;

  bool get isOpen => status == 'RAISED' || status == 'ACKNOWLEDGED';

  factory SosAlert.fromJson(Map<String, dynamic> json) {
    final raised = json['raisedAt'];
    return SosAlert(
      id: (json['id'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'RAISED',
      bookingId: (json['bookingId'] as num?)?.toInt(),
      raisedAt: raised is String ? DateTime.tryParse(raised) : null,
    );
  }
}

class SosApi {
  SosApi(this._dio);
  final Dio _dio;

  /// `POST /partner/sos` — raise. The backend collapses a repeat press into
  /// the alert already open, so retrying is safe.
  Future<SosAlert> raise({
    double? latitude,
    double? longitude,
    int? accuracyMetres,
    int? batteryPercentage,
    String? networkType,
    DateTime? clientRaisedAt,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/partner/sos',
      data: {
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (accuracyMetres != null) 'accuracyMetres': accuracyMetres,
        if (batteryPercentage != null) 'batteryPercentage': batteryPercentage,
        if (networkType != null) 'networkType': networkType,
        if (clientRaisedAt != null)
          'clientRaisedAt': clientRaisedAt.toUtc().toIso8601String(),
      },
    );
    return SosAlert.fromJson(res.data ?? const {});
  }

  /// `GET /partner/sos/active` — so a relaunch still shows the open alert.
  Future<SosAlert?> active() async {
    final res = await _dio.get<Map<String, dynamic>>('/partner/sos/active');
    final raw = res.data?['alert'];
    if (raw is! Map<String, dynamic>) return null;
    return SosAlert.fromJson(raw);
  }

  Future<SosAlert> cancel(int id) async {
    final res = await _dio.post<Map<String, dynamic>>('/partner/sos/$id/cancel');
    return SosAlert.fromJson(res.data ?? const {});
  }
}

final sosApiProvider = Provider<SosApi>((ref) => SosApi(ref.watch(dioProvider)));
