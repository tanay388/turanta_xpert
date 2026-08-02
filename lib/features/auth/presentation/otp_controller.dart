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

class OtpController extends Notifier<OtpState> {
  @override
  OtpState build() => const OtpIdle();

  Future<void> sendOtp(String phone) async {
    state = const OtpSending();

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
          try {
            await auth.signInWithCredential(credential);
            state = const OtpSucceeded();
          } catch (_) {
            state = const OtpFailed('otp.error.generic');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          state = OtpFailed(_sendFailureKey(e));
        },
        codeSent: (verificationId, _) {
          state = OtpCodeSent(verificationId: verificationId, phone: phone);
        },
        codeAutoRetrievalTimeout: (verificationId) {
          final prior = state;
          final phoneStr = prior is OtpCodeSent ? prior.phone : phone;
          state = OtpCodeSent(verificationId: verificationId, phone: phoneStr);
        },
      );
    } on FirebaseAuthException catch (e) {
      state = OtpFailed(_sendFailureKey(e));
    } catch (_) {
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

final otpProvider = NotifierProvider<OtpController, OtpState>(OtpController.new);
