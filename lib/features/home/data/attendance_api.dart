import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/models/partner_shift.dart';
import '../../../core/network/dio_client.dart';

class CurrentShiftPayload {
  const CurrentShiftPayload({
    required this.shift,
    required this.workDate,
    required this.scheduledStartAt,
    required this.scheduledEndAt,
    required this.allowedCheckinFrom,
    required this.canCheckIn,
    this.warehouseId,
    this.warehouseName,
    this.dayStatus,
    this.attendanceStatusToday,
    this.checkInBlockedReason,
    this.checkInBlocked = false,
  });

  final PartnerShift shift;
  final String workDate;
  final DateTime scheduledStartAt;
  final DateTime scheduledEndAt;
  final DateTime allowedCheckinFrom;
  final bool canCheckIn;
  final int? warehouseId;
  final String? warehouseName;
  final String? dayStatus;
  final String? attendanceStatusToday;
  final String? checkInBlockedReason;
  final bool checkInBlocked;

  bool get isShiftMissed =>
      checkInBlockedReason == 'SHIFT_MISSED' ||
      checkInBlockedReason == 'SHIFT_ABSENT' ||
      dayStatus == 'MISSED' ||
      attendanceStatusToday == 'ABSENT';

  bool get isOnLeave => checkInBlockedReason == 'ON_LEAVE';

  bool get isPartnerInactive => checkInBlockedReason == 'PARTNER_INACTIVE';

  /// The shift is over and was worked — checked out by the partner or by the
  /// auto-checkout cron.
  ///
  /// The server reports this as `canCheckIn: false` with no
  /// `checkInBlockedReason`, because "you already did today" is not a block,
  /// it is a finished day. Nothing else on the payload says so directly.
  bool get isDayComplete =>
      attendanceStatusToday == 'CHECKED_OUT' ||
      attendanceStatusToday == 'AUTO_CHECKED_OUT' ||
      (dayStatus == 'COMPLETED' && attendanceStatusToday != null);

  factory CurrentShiftPayload.fromJson(Map<String, dynamic> json) {
    final shiftJson = json['shift'] as Map<String, dynamic>? ?? const {};
    return CurrentShiftPayload(
      shift: PartnerShift.fromJson(shiftJson),
      workDate: json['workDate'] as String? ?? '',
      scheduledStartAt: DateTime.parse(json['scheduledStartAt'] as String),
      scheduledEndAt: DateTime.parse(json['scheduledEndAt'] as String),
      allowedCheckinFrom: DateTime.parse(json['allowedCheckinFrom'] as String),
      canCheckIn: json['canCheckIn'] as bool? ?? false,
      warehouseId: (json['warehouseId'] as num?)?.toInt(),
      warehouseName: json['warehouseName'] as String?,
      dayStatus: json['dayStatus'] as String?,
      attendanceStatusToday: json['attendanceStatusToday'] as String?,
      checkInBlockedReason: json['checkInBlockedReason'] as String?,
      checkInBlocked: json['checkInBlocked'] as bool? ??
          (json['checkInBlockedReason'] != null),
    );
  }
}

class AttendanceSnapshot {
  const AttendanceSnapshot({
    required this.attendanceStatus,
    required this.availabilityStatus,
    required this.presenceStatus,
    this.sessionId,
    this.sessionStartedAt,
    this.breakUsed = false,
    this.breakActive = false,
    this.breakStartedAt,
    this.scheduledEndAt,
    this.pingIntervalSeconds = 120,
  });

  final String attendanceStatus;
  final String availabilityStatus;
  final String presenceStatus;
  final int? sessionId;
  final DateTime? sessionStartedAt;
  final bool breakUsed;
  final bool breakActive;
  final DateTime? breakStartedAt;
  final DateTime? scheduledEndAt;
  final int pingIntervalSeconds;

  bool get isCheckedIn =>
      attendanceStatus == 'CHECKED_IN' ||
      attendanceStatus == 'checked_in';

  bool get isAvailable =>
      availabilityStatus == 'AVAILABLE' || availabilityStatus == 'available';

  bool get isOnBreak =>
      availabilityStatus == 'ON_BREAK' || availabilityStatus == 'on_break';

  factory AttendanceSnapshot.fromJson(Map<String, dynamic> json) {
    final session = json['session'] as Map<String, dynamic>?;
    final src = session ?? json;
    final br = json['break'] as Map<String, dynamic>?;
    return AttendanceSnapshot(
      attendanceStatus: (json['attendanceStatus'] ??
              src['attendanceStatus'] ??
              (session != null ? 'CHECKED_IN' : 'NOT_CHECKED_IN'))
          .toString(),
      availabilityStatus: (json['availabilityStatus'] ??
              src['availabilityStatus'] ??
              (session != null ? 'AVAILABLE' : 'OFF_SHIFT'))
          .toString(),
      presenceStatus: (json['presenceStatus'] ??
              src['presenceStatus'] ??
              (session != null ? 'ACTIVE' : 'UNAVAILABLE'))
          .toString(),
      sessionId: (src['id'] as num?)?.toInt() ??
          (json['sessionId'] as num?)?.toInt(),
      sessionStartedAt: _parseDt(src['checkinAt'] ?? json['checkinAt']),
      breakUsed: br?['used'] as bool? ?? json['breakUsed'] as bool? ?? false,
      breakActive: br?['active'] as bool? ??
          ((json['availabilityStatus'] ?? src['availabilityStatus'])
                  ?.toString() ==
              'ON_BREAK'),
      breakStartedAt: _parseDt(br?['startedAt']),
      scheduledEndAt:
          _parseDt(src['scheduledEndAt'] ?? json['scheduledEndAt']),
      pingIntervalSeconds:
          (json['pingIntervalSeconds'] as num?)?.toInt() ?? 120,
    );
  }

  static DateTime? _parseDt(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}

class AttendanceApi {
  AttendanceApi(this._dio);
  final Dio _dio;

  Future<CurrentShiftPayload> getCurrentShift() async {
    final res = await _dio.get<Map<String, dynamic>>('/partner/current-shift');
    return CurrentShiftPayload.fromJson(res.data!);
  }

  Future<AttendanceSnapshot> getCurrent() async {
    final res = await _dio.get<Map<String, dynamic>>('/attendance/current');
    return AttendanceSnapshot.fromJson(res.data ?? const {});
  }

  Future<AttendanceSnapshot> checkIn({
    required double latitude,
    required double longitude,
    double? gpsAccuracy,
    int? batteryPercentage,
    String? networkType,
    bool? isMockLocation,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/attendance/check-in',
      data: {
        'latitude': latitude,
        'longitude': longitude,
        if (gpsAccuracy != null) 'gpsAccuracy': gpsAccuracy,
        'clientTimestamp': DateTime.now().toUtc().toIso8601String(),
        if (batteryPercentage != null) 'batteryPercentage': batteryPercentage,
        if (networkType != null) 'networkType': networkType,
        if (isMockLocation != null) 'isMockLocation': isMockLocation,
      },
    );
    return AttendanceSnapshot.fromJson(res.data ?? const {});
  }

  Future<AttendanceSnapshot> checkOut({
    double? latitude,
    double? longitude,
    double? gpsAccuracy,
    String? reasonCode,
    String? reasonText,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/attendance/check-out',
      data: {
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (gpsAccuracy != null) 'gpsAccuracy': gpsAccuracy,
        if (reasonCode != null) 'reasonCode': reasonCode,
        if (reasonText != null) 'reasonText': reasonText,
        'clientTimestamp': DateTime.now().toUtc().toIso8601String(),
      },
    );
    return AttendanceSnapshot.fromJson(res.data ?? const {});
  }

  Future<AttendanceSnapshot> ping({
    required int attendanceSessionId,
    required double latitude,
    required double longitude,
    double? gpsAccuracy,
    int? batteryPercentage,
    String? networkType,
    required String appState,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/attendance/ping',
      data: {
        'attendanceSessionId': attendanceSessionId,
        'latitude': latitude,
        'longitude': longitude,
        if (gpsAccuracy != null) 'gpsAccuracy': gpsAccuracy,
        if (batteryPercentage != null) 'batteryPercentage': batteryPercentage,
        if (networkType != null) 'networkType': networkType,
        'appState': appState,
        'clientTimestamp': DateTime.now().toUtc().toIso8601String(),
      },
    );
    return AttendanceSnapshot.fromJson(res.data ?? const {});
  }

  Future<void> startBreak({
    double? latitude,
    double? longitude,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/breaks/start',
      data: {
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
    );
  }

  Future<void> endBreak({
    double? latitude,
    double? longitude,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/breaks/end',
      data: {
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
    );
  }

  Future<Map<String, dynamic>> breakSummary() async {
    final res = await _dio.get<Map<String, dynamic>>('/breaks/summary');
    return res.data ?? const {};
  }

  Future<AttendanceHistoryResult> getHistory({
    int limit = 30,
    int offset = 0,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/attendance/history',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return AttendanceHistoryResult.fromJson(res.data ?? const {});
  }
}

class AttendanceHistoryItem {
  const AttendanceHistoryItem({
    required this.id,
    required this.attendanceStatus,
    required this.attendanceOutcome,
    required this.scheduledStartAt,
    required this.scheduledEndAt,
    this.checkinAt,
    this.checkoutAt,
    this.checkinStatus,
    this.shiftName,
    this.shiftLabel,
    this.warehouseName,
  });

  final int id;
  final String attendanceStatus;
  final String attendanceOutcome;
  final DateTime scheduledStartAt;
  final DateTime scheduledEndAt;
  final DateTime? checkinAt;
  final DateTime? checkoutAt;
  final String? checkinStatus;
  final String? shiftName;
  final String? shiftLabel;
  final String? warehouseName;

  factory AttendanceHistoryItem.fromJson(Map<String, dynamic> json) {
    DateTime? parse(dynamic v) {
      if (v is! String || v.isEmpty) return null;
      return DateTime.tryParse(v);
    }

    return AttendanceHistoryItem(
      id: (json['id'] as num).toInt(),
      attendanceStatus: json['attendanceStatus'] as String? ?? '',
      attendanceOutcome: json['attendanceOutcome'] as String? ?? '',
      scheduledStartAt:
          DateTime.parse(json['scheduledStartAt'] as String),
      scheduledEndAt: DateTime.parse(json['scheduledEndAt'] as String),
      checkinAt: parse(json['checkinAt']),
      checkoutAt: parse(json['checkoutAt']),
      checkinStatus: json['checkinStatus'] as String?,
      shiftName: json['shiftName'] as String?,
      shiftLabel: json['shiftLabel'] as String?,
      warehouseName: json['warehouseName'] as String?,
    );
  }
}

class AttendanceHistoryResult {
  const AttendanceHistoryResult({
    required this.total,
    required this.items,
  });

  final int total;
  final List<AttendanceHistoryItem> items;

  factory AttendanceHistoryResult.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List<dynamic>? ?? const [];
    return AttendanceHistoryResult(
      total: (json['total'] as num?)?.toInt() ?? list.length,
      items: list
          .map((e) => AttendanceHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

final attendanceApiProvider = Provider<AttendanceApi>((ref) {
  return AttendanceApi(ref.watch(dioProvider));
});
