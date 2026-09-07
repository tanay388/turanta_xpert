import 'dart:async';
import 'dart:convert';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/location/location_service.dart';
import '../data/sos_api.dart';

enum SosPhase { idle, sending, sent, failed }

class SosState {
  const SosState({
    this.phase = SosPhase.idle,
    this.alert,
    this.attempt = 0,
  });

  final SosPhase phase;
  final SosAlert? alert;
  final int attempt;

  bool get isBusy => phase == SosPhase.sending;
  bool get hasOpenAlert => alert?.isOpen ?? false;

  SosState copyWith({SosPhase? phase, SosAlert? alert, int? attempt, bool clearAlert = false}) {
    return SosState(
      phase: phase ?? this.phase,
      alert: clearAlert ? null : (alert ?? this.alert),
      attempt: attempt ?? this.attempt,
    );
  }
}

/// Raises the alert and then keeps trying on the helper's behalf.
///
/// `RetryInterceptor` only retries idempotent verbs, so this POST would
/// otherwise get one attempt on a bad tower. The pending raise is written to
/// disk before the first attempt so that even a killed app resends on launch —
/// the backend collapses duplicates, so resending costs nothing.
class SosController extends Notifier<SosState> {
  static const _pendingKey = 'xpert_pending_sos';
  static const _maxAttempts = 6;

  final _battery = Battery();
  Timer? _retryTimer;

  @override
  SosState build() {
    ref.onDispose(() => _retryTimer?.cancel());
    return const SosState();
  }

  /// Called once the helper has confirmed. Returns as soon as the alert is
  /// queued — the helper is not asked to wait or watch.
  Future<void> raise() async {
    _retryTimer?.cancel();
    state = state.copyWith(phase: SosPhase.sending, attempt: 0);
    await _markPending();
    unawaited(_attempt());
  }

  /// Restores an alert raised earlier, and finishes any raise the app died
  /// half-way through.
  Future<void> refresh() async {
    try {
      final alert = await ref.read(sosApiProvider).active();
      if (alert != null) {
        await _clearPending();
        state = SosState(phase: SosPhase.sent, alert: alert);
        return;
      }
    } catch (_) {
      // Offline on launch: fall through to the pending check.
    }
    if (await _hasPending()) {
      state = state.copyWith(phase: SosPhase.sending);
      unawaited(_attempt());
    }
  }

  Future<void> cancel() async {
    final alert = state.alert;
    if (alert == null) return;
    _retryTimer?.cancel();
    await _clearPending();
    try {
      await ref.read(sosApiProvider).cancel(alert.id);
    } finally {
      state = const SosState();
    }
  }

  Future<void> _attempt() async {
    final attempt = state.attempt + 1;
    state = state.copyWith(attempt: attempt);
    try {
      final position = await ref
          .read(locationServiceProvider)
          .currentOrLastKnown();
      final alert = await ref.read(sosApiProvider).raise(
            latitude: position?.latitude,
            longitude: position?.longitude,
            accuracyMetres: position?.accuracy.round(),
            batteryPercentage: await _batteryLevel(),
            networkType: await _networkType(),
            clientRaisedAt: DateTime.now(),
          );
      await _clearPending();
      state = SosState(phase: SosPhase.sent, alert: alert);
    } catch (_) {
      if (attempt >= _maxAttempts) {
        state = state.copyWith(phase: SosPhase.failed);
        return;
      }
      // 2s, 4s, 8s … capped, so a helper in a lift still gets through when
      // signal returns without hammering a dying battery.
      final backoff = Duration(seconds: 1 << attempt);
      _retryTimer = Timer(backoff, _attempt);
    }
  }

  Future<void> _markPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _pendingKey,
      jsonEncode({'at': DateTime.now().toIso8601String()}),
    );
  }

  Future<bool> _hasPending() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pendingKey) != null;
  }

  Future<void> _clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey);
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
}

final sosProvider = NotifierProvider<SosController, SosState>(
  SosController.new,
);
