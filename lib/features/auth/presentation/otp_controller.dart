import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

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
      state = const OtpFailed(
        'Firebase is not configured. Run flutterfire configure and restart.',
      );
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
          } catch (e) {
            state = OtpFailed(e.toString());
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          state = OtpFailed(e.message ?? 'Could not send OTP. Try again.');
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
      state = OtpFailed(e.message ?? 'Could not send OTP. Try again.');
    } catch (e) {
      state = OtpFailed(e.toString());
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
        message: e.message ?? 'Invalid OTP. Try again.',
        verificationId: session.verificationId,
        phone: session.phone,
      );
    } catch (e) {
      state = OtpVerifyFailed(
        message: e.toString(),
        verificationId: session.verificationId,
        phone: session.phone,
      );
    }
  }

  void reset() => state = const OtpIdle();
}

final otpProvider = NotifierProvider<OtpController, OtpState>(OtpController.new);
