import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/referral_api.dart';

class ReferralState {
  const ReferralState({
    this.summary,
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
  });

  final ReferralSummary? summary;
  final bool isLoading;
  final bool isSubmitting;
  final String? error;

  ReferralState copyWith({
    ReferralSummary? summary,
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
  }) {
    return ReferralState(
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ReferralController extends Notifier<ReferralState> {
  @override
  ReferralState build() => const ReferralState();

  ReferralApi get _api => ref.read(referralApiProvider);

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      state = state.copyWith(
        summary: await _api.getSummary(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _message(e));
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
        if (message is List && message.isNotEmpty) {
          return message.first.toString();
        }
      }
      return e.message ?? 'Something went wrong';
    }
    return e.toString();
  }
}

final referralProvider = NotifierProvider<ReferralController, ReferralState>(
  ReferralController.new,
);
