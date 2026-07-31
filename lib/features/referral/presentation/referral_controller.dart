import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/referral_api.dart';

class ReferralState {
  const ReferralState({
    this.summary,
    this.workProfiles = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
  });

  final ReferralSummary? summary;
  final List<ReferralWorkProfile> workProfiles;
  final bool isLoading;
  final bool isSubmitting;
  final String? error;

  ReferralState copyWith({
    ReferralSummary? summary,
    List<ReferralWorkProfile>? workProfiles,
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
  }) {
    return ReferralState(
      summary: summary ?? this.summary,
      workProfiles: workProfiles ?? this.workProfiles,
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
      final results = await Future.wait([
        _api.getSummary(),
        _api.getWorkProfiles(),
      ]);
      state = state.copyWith(
        summary: results[0] as ReferralSummary,
        workProfiles: results[1] as List<ReferralWorkProfile>,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _message(e));
    }
  }

  Future<String?> invite({String? name, String? phone, int? serviceId}) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final shareLink = await _api.invite(
        name: name,
        phone: phone,
        serviceId: serviceId,
      );
      await refresh();
      state = state.copyWith(isSubmitting: false);
      return shareLink;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: _message(e));
      return null;
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

final referralProvider = NotifierProvider<ReferralController, ReferralState>(
  ReferralController.new,
);
