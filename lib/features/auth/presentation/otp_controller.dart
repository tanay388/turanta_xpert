import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/auth/token_store.dart';
import '../../../core/models/partner_user.dart';
import '../data/partner_auth_api.dart';

/// Every [OtpFailed] / [OtpVerifyFailed] message is an i18n key.
String _sendFailureKey(ApiException e) {
  if (e.kind == ApiFailure.network) return 'otp.error.network';
  return switch (e.code) {
    'OTP_INVALID_PHONE' => 'login.phone.error',
    'OTP_LOCKED' => 'otp.error.locked',
    'OTP_COOLDOWN' || 'OTP_RATE_LIMITED' => 'otp.error.too_many',
    _ => 'otp.error.generic',
  };
}

String _verifyFailureKey(ApiException e) {
  if (e.kind == ApiFailure.network) return 'otp.error.network';
  return switch (e.code) {
    'OTP_EXPIRED' => 'otp.error.expired',
    'OTP_CHALLENGE_DEAD' => 'otp.error.dead',
    'OTP_LOCKED' => 'otp.error.locked',
    _ => 'otp.error.invalid_code',
  };
}

sealed class OtpState {
  const OtpState();
}

class OtpIdle extends OtpState {
  const OtpIdle();
}

class OtpSending extends OtpState {
  const OtpSending();
}

class OtpCodeSent extends OtpState {
  const OtpCodeSent({
    required this.challengeId,
    required this.phone,
    required this.resendAfter,
  });
  final String challengeId;
  final String phone;
  final Duration resendAfter;
}

class OtpVerifying extends OtpCodeSent {
  const OtpVerifying({
    required super.challengeId,
    required super.phone,
    required super.resendAfter,
  });
}

class OtpFailed extends OtpState {
  const OtpFailed(this.message);
  final String message;
}

class OtpVerifyFailed extends OtpCodeSent {
  const OtpVerifyFailed({
    required this.message,
    required super.challengeId,
    required super.phone,
    required super.resendAfter,
  });
  final String message;
}

class OtpSucceeded extends OtpState {
  const OtpSucceeded();
}

class OtpController extends Notifier<OtpState> {
  @override
  OtpState build() => const OtpIdle();

  Future<void> sendOtp(String phone) async {
    final previous = state;
    state = const OtpSending();
    try {
      final challenge = await ref.read(partnerAuthApiProvider).sendOtp(phone);
      state = OtpCodeSent(
        challengeId: challenge.id,
        phone: phone,
        resendAfter: challenge.resendAfter,
      );
    } on ApiException catch (e) {
      // A failed resend keeps the code screen on the code already sent.
      state = previous is OtpCodeSent
          ? OtpVerifyFailed(
              message: _sendFailureKey(e),
              challengeId: previous.challengeId,
              phone: previous.phone,
              resendAfter: previous.resendAfter,
            )
          : OtpFailed(_sendFailureKey(e));
    }
  }

  /// On success the code screen hands over to splash, which loads the profile.
  Future<void> verify(String code) async {
    final current = state;
    if (current is! OtpCodeSent || current is OtpVerifying) return;
    state = OtpVerifying(
      challengeId: current.challengeId,
      phone: current.phone,
      resendAfter: current.resendAfter,
    );
    try {
      final tokens = await ref
          .read(partnerAuthApiProvider)
          .verifyOtp(
            challengeId: current.challengeId,
            code: code,
            phone: current.phone,
          );
      await TokenStore.instance.save(tokens);
      state = const OtpSucceeded();
    } on ApiException catch (e) {
      state = OtpVerifyFailed(
        message: _verifyFailureKey(e),
        challengeId: current.challengeId,
        phone: current.phone,
        resendAfter: current.resendAfter,
      );
    }
  }

  void reset() => state = const OtpIdle();
}

final otpProvider = NotifierProvider<OtpController, OtpState>(
  OtpController.new,
);
