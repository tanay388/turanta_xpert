import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Firebase's own messages are written for developers — the device-attestation
/// one literally tells the reader to check logcat. Map the codes worth acting
/// on to our own copy and send everything else to one generic line. Every
/// [OtpFailed] / [OtpVerifyFailed] message is an i18n key.
String _sendFailureKey(FirebaseAuthException e) {
  return switch (e.code) {
    'invalid-phone-number' => 'login.phone.error',
    'network-request-failed' => 'otp.error.network',
    'too-many-requests' || 'quota-exceeded' => 'otp.error.too_many',
    // Play Integrity / reCAPTCHA attestation failed — usually transient, and
    // retrying picks the reCAPTCHA fallback.
    'missing-client-identifier' ||
    'app-not-authorized' ||
    'captcha-check-failed' => 'otp.error.verification',
    _ => 'otp.error.generic',
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
  const OtpCodeSent({required this.verificationId, required this.phone});
  final String verificationId;
  final String phone;
}

class OtpVerifying extends OtpState {
  const OtpVerifying({required this.verificationId, required this.phone});
  final String verificationId;
  final String phone;
}

class OtpFailed extends OtpState {
  const OtpFailed(this.message);
  final String message;
}

class OtpVerifyFailed extends OtpState {
  const OtpVerifyFailed({
    required this.message,
    required this.verificationId,
    required this.phone,
  });

  final String message;
  final String verificationId;
  final String phone;
}

class OtpSucceeded extends OtpState {
  const OtpSucceeded();
}

/// How long a partner waits for Google to answer before the screen admits
/// nothing is happening. `verifyPhoneNumber`'s own `timeout` only governs
/// auto-retrieval of the SMS; when device verification itself never comes
/// back, not one of its callbacks fires and the screen spins forever.
const otpSendTimeout = Duration(seconds: 45);

class OtpController extends Notifier<OtpState> {
  Timer? _sendGuard;

  @override
  OtpState build() {
    ref.onDispose(() => _sendGuard?.cancel());
    return const OtpIdle();
  }

  void _answered() => _sendGuard?.cancel();

  Future<void> sendOtp(String phone) async {
    state = const OtpSending();
    _sendGuard?.cancel();
    _sendGuard = Timer(otpSendTimeout, () {
      if (state is OtpSending) state = const OtpFailed('otp.error.no_response');
    });

    if (Firebase.apps.isEmpty) {
      state = const OtpFailed('otp.error.generic');
      return;
    }

    final auth = FirebaseAuth.instance;
    try {
      await auth.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          _answered();
          try {
            await auth.signInWithCredential(credential);
            state = const OtpSucceeded();
          } catch (_) {
            state = const OtpFailed('otp.error.generic');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          _answered();
          state = OtpFailed(_sendFailureKey(e));
        },
        codeSent: (verificationId, _) {
          _answered();
          state = OtpCodeSent(verificationId: verificationId, phone: phone);
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _answered();
          final prior = state;
          final phoneStr = prior is OtpCodeSent ? prior.phone : phone;
          state = OtpCodeSent(verificationId: verificationId, phone: phoneStr);
        },
      );
    } on FirebaseAuthException catch (e) {
      _answered();
      state = OtpFailed(_sendFailureKey(e));
    } catch (_) {
      _answered();
      state = const OtpFailed('otp.error.generic');
    }
  }

  Future<void> verify(String code) async {
    final current = state;
    final session = switch (current) {
      OtpCodeSent(:final verificationId, :final phone) => (
        verificationId: verificationId,
        phone: phone,
      ),
      OtpVerifyFailed(:final verificationId, :final phone) => (
        verificationId: verificationId,
        phone: phone,
      ),
      _ => null,
    };
    if (session == null) return;

    state = OtpVerifying(
      verificationId: session.verificationId,
      phone: session.phone,
    );

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: session.verificationId,
        smsCode: code,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      state = const OtpSucceeded();
    } on FirebaseAuthException catch (e) {
      state = OtpVerifyFailed(
        message: e.code == 'invalid-verification-code'
            ? 'otp.error.invalid_code'
            : _sendFailureKey(e),
        verificationId: session.verificationId,
        phone: session.phone,
      );
    } catch (_) {
      state = OtpVerifyFailed(
        message: 'otp.error.generic',
        verificationId: session.verificationId,
        phone: session.phone,
      );
    }
  }

  void reset() => state = const OtpIdle();
}

final otpProvider = NotifierProvider<OtpController, OtpState>(
  OtpController.new,
);
