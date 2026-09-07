import 'dart:async';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
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

/// Where the partner stands with today's shift.
///
/// Derived in one place because the screen used to answer this with a handful
/// of independent booleans, and they disagreed with the server: a finished day
/// comes back as `canCheckIn: false` with **no** `checkInBlockedReason` —
/// having already worked is not a block, it is a completed day — so the old
/// `isCheckInBlocked` said false and the Check in button stayed live at 11pm
/// on a shift that ended at 6.
enum ShiftPhase {
  /// Currently on shift.
  onShift,

  /// On shift, on break.
  onBreak,

  /// Worked and finished — checked out, or auto-checked-out by the cron.
  complete,

  /// Assigned but the check-in window has not opened yet.
  upcoming,

  /// The window is open and nothing is in the way.
  ready,

  /// Check-in closed because the shift was never started.
  missed,

  /// Approved leave today.
  onLeave,

  /// Account is not active.
  inactive,

  /// The server says no and gave no reason we model. Never enable on this.
  unavailable,
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

  /// The single source of truth for what the shift card shows and whether the
  /// primary button does anything. Order matters — the first match wins.
  ShiftPhase get phase {
    if (isOnBreak) return ShiftPhase.onBreak;
    if (isCheckedIn) return ShiftPhase.onShift;

    final shift = currentShift;
    if (shift == null) return ShiftPhase.unavailable;

    if (shift.isOnLeave) return ShiftPhase.onLeave;
    if (shift.isShiftMissed) return ShiftPhase.missed;
    if (shift.isPartnerInactive) return ShiftPhase.inactive;
    if (shift.isDayComplete) return ShiftPhase.complete;

    // `canCheckIn` is the server's verdict and it is authoritative. Anything
    // it refuses that we have not explained above is still a refusal.
    if (!shift.canCheckIn) return ShiftPhase.unavailable;

    // The server allows a check-in the moment no session exists, without
    // regard for the clock; the window is enforced when the call is made. Do
    // not offer a button that is going to be rejected.
    if (DateTime.now().isBefore(shift.allowedCheckinFrom)) {
      return ShiftPhase.upcoming;
    }

    return ShiftPhase.ready;
  }

  bool get isCheckInBlocked => phase != ShiftPhase.ready;

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
  StreamSubscription<Position>? _positionSub;
  final _battery = Battery();

  @override
  AttendanceState build() {
    ref.onDispose(() {
      _pingTimer?.cancel();
      _positionSub?.cancel();
    });
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

  /// What the OS says about us right now, rather than a hopeful constant.
  String _appState() {
    final lifecycle =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    return lifecycle == AppLifecycleState.resumed ? 'FOREGROUND' : 'BACKGROUND';
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

  /// Keeps the shift heartbeat alive while the phone is in a pocket.
  ///
  /// This used to be a bare `Timer.periodic`, which iOS suspends and Android
  /// Doze kills the moment the app leaves the foreground. Partners were
  /// checking in, pocketing the phone, and vanishing from dispatch inside four
  /// minutes while still showing as available — on 6 Sep that left paid
  /// bookings unassigned with free partners on shift.
  ///
  /// The stream runs under a foreground service on Android and background
  /// location updates on iOS, so it survives. The timer stays as a backstop
  /// because a stationary phone produces no location events at all.
  void _syncPingLoop(AttendanceSnapshot snap) {
    _pingTimer?.cancel();
    _positionSub?.cancel();
    _positionSub = null;

    if (!snap.isCheckedIn || snap.sessionId == null) return;

    final interval = Duration(seconds: snap.pingIntervalSeconds.clamp(30, 300));
    _pingTimer = Timer.periodic(interval, (_) => _sendPing());
    _positionSub = Geolocator.getPositionStream(
      locationSettings: _shiftLocationSettings(interval),
    ).listen(
      (position) => unawaited(_sendPing(position: position)),
      onError: (Object err) => debugPrint('shift location stream: $err'),
    );
    unawaited(_sendPing());
  }

  LocationSettings _shiftLocationSettings(Duration interval) {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        // Time-based, not distance-based: a partner waiting at a doorstep is
        // still on shift and must keep reporting.
        distanceFilter: 0,
        intervalDuration: interval,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'On shift with Turanta',
          notificationText: 'Sharing your location so jobs can reach you.',
          notificationChannelName: 'Shift location',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        allowBackgroundLocationUpdates: true,
        // iOS pauses updates when it decides the user has settled, which is
        // exactly when a partner is waiting to be given a job.
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );
  }

  Future<void> _sendPing({Position? position}) async {
    final snap = state.snapshot;
    final sessionId = snap?.sessionId;
    if (snap == null || !snap.isCheckedIn || sessionId == null) return;
    try {
      final pos = position ?? await _position();
      if (pos == null) return;
      final updated = await _api.ping(
        attendanceSessionId: sessionId,
        latitude: pos.latitude,
        longitude: pos.longitude,
        gpsAccuracy: pos.accuracy,
        batteryPercentage: await _batteryLevel(),
        networkType: await _networkType(),
        // Reported honestly: the server uses it to tell a quiet app apart
        // from a quiet partner.
        appState: _appState(),
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
