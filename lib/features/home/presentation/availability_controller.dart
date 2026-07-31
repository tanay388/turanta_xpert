import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../jobs/presentation/jobs_controller.dart';
import '../data/attendance_api.dart';

enum CheckInBlockedReason {
  outsideWorkingHours,
  tooEarly,
  shiftMissed,
  geofence,
  gps,
  other,
}

class AttendanceState {
  const AttendanceState({
    this.snapshot,
    this.currentShift,
    this.breakSummary,
    this.loading = false,
    this.error,
  });

  final AttendanceSnapshot? snapshot;
  final CurrentShiftPayload? currentShift;
  final Map<String, dynamic>? breakSummary;
  final bool loading;
  final String? error;

  bool get isCheckedIn => snapshot?.isCheckedIn ?? false;
  bool get isOnBreak => snapshot?.isOnBreak ?? false;
  bool get isAvailable => snapshot?.isAvailable ?? false;
  bool get breakUsed =>
      breakSummary?['used'] == true || (snapshot?.breakUsed ?? false);

  bool get isCheckInBlocked =>
      currentShift?.checkInBlocked == true ||
      currentShift?.isShiftMissed == true ||
      currentShift?.isOnLeave == true;

  bool get isShiftMissed => currentShift?.isShiftMissed ?? false;
  bool get isOnLeaveToday => currentShift?.isOnLeave ?? false;

  bool get canAttemptCheckIn =>
      !isCheckedIn &&
      !isCheckInBlocked &&
      (currentShift?.canCheckIn ?? true);

  AttendanceState copyWith({
    AttendanceSnapshot? snapshot,
    CurrentShiftPayload? currentShift,
    Map<String, dynamic>? breakSummary,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return AttendanceState(
      snapshot: snapshot ?? this.snapshot,
      currentShift: currentShift ?? this.currentShift,
      breakSummary: breakSummary ?? this.breakSummary,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AttendanceController extends Notifier<AttendanceState> {
  Timer? _pingTimer;
  final _battery = Battery();

  @override
  AttendanceState build() {
    ref.onDispose(() => _pingTimer?.cancel());
    Future.microtask(refresh);
    return const AttendanceState(loading: true);
  }

  AttendanceApi get _api => ref.read(attendanceApiProvider);

  Future<void> refresh() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      CurrentShiftPayload? shift;
      try {
        shift = await _api.getCurrentShift();
      } catch (_) {
        // Partner may not have shift yet.
      }

      final current = await _api.getCurrent();
      Map<String, dynamic>? breakSummary;
      try {
        breakSummary = await _api.breakSummary();
      } catch (_) {}

      final snap = _normalizeSnapshot(current, breakSummary);
      state = AttendanceState(
        snapshot: snap,
        currentShift: shift,
        breakSummary: breakSummary,
        loading: false,
      );
      _syncPingLoop(snap);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  AttendanceSnapshot _normalizeSnapshot(
    AttendanceSnapshot base,
    Map<String, dynamic>? breakSummary,
  ) {
    final used = breakSummary?['used'] == true;
    final active = breakSummary?['breakStatus']?.toString() == 'ACTIVE' ||
        breakSummary?['breakStatus']?.toString() == 'EXCEEDED';
    return AttendanceSnapshot(
      attendanceStatus: base.attendanceStatus,
      availabilityStatus: base.availabilityStatus,
      presenceStatus: base.presenceStatus,
      sessionId: base.sessionId,
      sessionStartedAt: base.sessionStartedAt,
      breakUsed: used || base.breakUsed,
      breakActive: active || base.breakActive,
      breakStartedAt: base.breakStartedAt,
      scheduledEndAt: base.scheduledEndAt,
      pingIntervalSeconds: base.pingIntervalSeconds,
    );
  }

  Future<Position?> _position() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return null;
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  Future<int?> _batteryLevel() async {
    try {
      return await _battery.batteryLevel;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _networkType() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.isEmpty) return 'unknown';
      return results.first.name;
    } catch (_) {
      return null;
    }
  }

  Future<CheckInBlockedReason?> checkIn() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final pos = await _position();
      if (pos == null) {
        state = state.copyWith(loading: false, error: 'Location permission required');
        return CheckInBlockedReason.gps;
      }
      await _api.checkIn(
        latitude: pos.latitude,
        longitude: pos.longitude,
        gpsAccuracy: pos.accuracy,
        batteryPercentage: await _batteryLevel(),
        networkType: await _networkType(),
        isMockLocation: pos.isMocked,
      );
      await refresh();
      return null;
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: _dioMessage(e));
      return _mapBlocked(e);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return CheckInBlockedReason.other;
    }
  }

  Future<CheckInBlockedReason?> checkOut({
    String? reasonCode,
    String? reasonText,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final pos = await _position();
      await _api.checkOut(
        latitude: pos?.latitude,
        longitude: pos?.longitude,
        gpsAccuracy: pos?.accuracy,
        reasonCode: reasonCode,
        reasonText: reasonText,
      );
      await refresh();
      return null;
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: _dioMessage(e));
      return _mapBlocked(e);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return CheckInBlockedReason.other;
    }
  }

  Future<String?> startBreak() async {
    try {
      final pos = await _position();
      await _api.startBreak(
        latitude: pos?.latitude,
        longitude: pos?.longitude,
      );
      await refresh();
      return null;
    } on DioException catch (e) {
      return _dioMessage(e);
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> endBreak() async {
    try {
      final pos = await _position();
      await _api.endBreak(
        latitude: pos?.latitude,
        longitude: pos?.longitude,
      );
      await refresh();
      return null;
    } on DioException catch (e) {
      return _dioMessage(e);
    } catch (e) {
      return e.toString();
    }
  }

  void _syncPingLoop(AttendanceSnapshot snap) {
    _pingTimer?.cancel();
    if (!snap.isCheckedIn || snap.sessionId == null) return;
    final interval = Duration(seconds: snap.pingIntervalSeconds.clamp(30, 300));
    _pingTimer = Timer.periodic(interval, (_) => _sendPing());
    unawaited(_sendPing());
  }

  Future<void> _sendPing() async {
    final snap = state.snapshot;
    final sessionId = snap?.sessionId;
    if (snap == null || !snap.isCheckedIn || sessionId == null) return;
    try {
      final pos = await _position();
      if (pos == null) return;
      final updated = await _api.ping(
        attendanceSessionId: sessionId,
        latitude: pos.latitude,
        longitude: pos.longitude,
        gpsAccuracy: pos.accuracy,
        batteryPercentage: await _batteryLevel(),
        networkType: await _networkType(),
        appState: 'FOREGROUND',
      );
      // Pick up newly assigned jobs without leaving home.
      unawaited(ref.read(jobsProvider.notifier).refresh(silent: true));
      state = state.copyWith(
        snapshot: AttendanceSnapshot(
          attendanceStatus: updated.attendanceStatus.isEmpty
              ? snap.attendanceStatus
              : updated.attendanceStatus,
          availabilityStatus: updated.availabilityStatus.isEmpty
              ? snap.availabilityStatus
              : updated.availabilityStatus,
          presenceStatus: updated.presenceStatus,
          sessionId: updated.sessionId ?? snap.sessionId,
          sessionStartedAt: updated.sessionStartedAt ?? snap.sessionStartedAt,
          breakUsed: snap.breakUsed,
          breakActive: snap.breakActive,
          breakStartedAt: snap.breakStartedAt,
          scheduledEndAt: updated.scheduledEndAt ?? snap.scheduledEndAt,
          pingIntervalSeconds: snap.pingIntervalSeconds,
        ),
      );
    } catch (e) {
      debugPrint('[Attendance] ping failed: $e');
    }
  }

  CheckInBlockedReason _mapBlocked(DioException e) {
    final code = _errorCode(e);
    return switch (code) {
      'OUTSIDE_WORKING_HOURS' || 'CHECKIN_TOO_EARLY' =>
        CheckInBlockedReason.tooEarly,
      'SHIFT_MISSED' => CheckInBlockedReason.shiftMissed,
      'OUTSIDE_ZONE' || 'GEOFENCE' => CheckInBlockedReason.geofence,
      'GPS_ACCURACY' => CheckInBlockedReason.gps,
      _ => CheckInBlockedReason.other,
    };
  }

  String? _errorCode(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final message = data['message'];
      if (message is Map) return message['code']?.toString();
      return data['code']?.toString();
    }
    return null;
  }

  String _dioMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final message = data['message'];
      if (message is Map) {
        return message['message']?.toString() ?? message.toString();
      }
      if (message is String) return message;
      if (message is List && message.isNotEmpty) return message.first.toString();
    }
    return e.message ?? 'Request failed';
  }
}

final attendanceProvider =
    NotifierProvider<AttendanceController, AttendanceState>(
  AttendanceController.new,
);

/// Back-compat for older home widgets that watched a bool.
final availabilityProvider = Provider<bool>((ref) {
  return ref.watch(attendanceProvider).isCheckedIn &&
      !ref.watch(attendanceProvider).isOnBreak;
});

final partnerShiftProvider = Provider((ref) {
  return ref.watch(attendanceProvider).currentShift?.shift;
});

final withinWorkingHoursProvider = Provider<bool>((ref) {
  final shift = ref.watch(attendanceProvider).currentShift;
  if (shift == null) return false;
  final now = DateTime.now();
  // Only during the assigned shift slot (scheduled start → end).
  return !now.isBefore(shift.scheduledStartAt) &&
      !now.isAfter(shift.scheduledEndAt);
});

// Home "today" stats now come from `todaySummaryProvider`
// (see features/home/data/summary_api.dart), backed by GET /partner/summary/today.
