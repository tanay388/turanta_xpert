import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/leave_api.dart';

class LeaveState {
  const LeaveState({
    this.summary,
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
  });

  final LeaveSummary? summary;
  final bool isLoading;
  final bool isSubmitting;
  final String? error;

  LeaveState copyWith({
    LeaveSummary? summary,
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
  }) {
    return LeaveState(
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class LeaveController extends Notifier<LeaveState> {
  @override
  LeaveState build() => const LeaveState();

  LeaveApi get _api => ref.read(leaveApiProvider);

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final summary = await _api.getSummary();
      state = state.copyWith(summary: summary, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _message(e),
      );
    }
  }

  Future<bool> apply({
    required String startDate,
    required String endDate,
    String? reason,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _api.apply(
        startDate: startDate,
        endDate: endDate,
        reason: reason,
      );
      await refresh();
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: _message(e));
      return false;
    }
  }

  Future<bool> cancel(int id) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _api.cancel(id);
      await refresh();
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: _message(e));
      return false;
    }
  }

  String _message(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final message = data['message'];
        if (message is Map) {
          return message['message']?.toString() ?? message.toString();
        }
        if (message is String) return message;
        if (message is List && message.isNotEmpty) return message.first.toString();
      }
      return e.message ?? 'Something went wrong';
    }
    return e.toString();
  }
}

final leaveProvider = NotifierProvider<LeaveController, LeaveState>(
  LeaveController.new,
);
