import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import 'otp_controller.dart';
import 'widgets/auth_inputs.dart';
import 'widgets/auth_shell.dart';
import 'widgets/auth_text_link.dart';

const _otpLength = 6;
const _resendCooldownSeconds = 60;

class OtpVerificationScreen extends HookConsumerWidget {
  const OtpVerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(otpProvider);
    final controller = ref.read(otpProvider.notifier);

    final focusNode = useFocusNode();
    final hiddenController = useTextEditingController();
    final codeError = useState<String?>(null);
    final secondsLeft = useState(_resendCooldownSeconds);
    final timerRef = useRef<Timer?>(null);

    useListenable(hiddenController);
    useListenable(focusNode);

    final phone = switch (state) {
      OtpCodeSent(:final phone) => phone,
      OtpVerifying(:final phone) => phone,
      OtpVerifyFailed(:final phone) => phone,
      _ => '',
    };

    final isBusy = state is OtpVerifying;
    final code = hiddenController.text;

    useEffect(() {
      if (state is OtpIdle) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.go('/login');
        });
      } else if (state is OtpSucceeded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.go('/splash');
        });
      }
      return null;
    }, [state]);

    useEffect(() {
      if (state is OtpVerifyFailed) {
        codeError.value = ref.t(state.message);
      }
      return null;
    }, [state]);

    useEffect(() {
      timerRef.value?.cancel();
      secondsLeft.value = _resendCooldownSeconds;
      timerRef.value = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (secondsLeft.value <= 1) {
          timer.cancel();
          secondsLeft.value = 0;
        } else {
          secondsLeft.value = secondsLeft.value - 1;
        }
      });
      return () => timerRef.value?.cancel();
    }, [phone]);

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) focusNode.requestFocus();
      });
      return null;
    }, const []);

    Future<void> verifyCode(String value) async {
      if (value.length < _otpLength) {
        codeError.value = ref.t('otp.incomplete');
        return;
      }
      if (state is! OtpCodeSent && state is! OtpVerifyFailed) return;
      codeError.value = null;
      await controller.verify(value);
    }

    Future<void> resendCode() async {
      if (phone.isEmpty || secondsLeft.value > 0) return;
      hiddenController.clear();
      codeError.value = null;
      await controller.sendOtp(phone);
    }

    void goBack() {
      controller.reset();
      context.go('/login');
    }

    final isSending = state is OtpSending;
    final canResend = secondsLeft.value == 0 && !isBusy && !isSending;

    return AuthShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ref.t('otp.title'),
            style: XpertTypography.title.copyWith(fontSize: 20),
          ),
          const SizedBox(height: XpertSpacing.xs),
          // The number and the way back out of it, on one line — everything
          // else here is the six digits.
          Row(
            children: [
              InkWell(
                onTap: goBack,
                borderRadius: BorderRadius.circular(XpertRadius.pill),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    size: 20,
                    color: XpertColors.muted,
                  ),
                ),
              ),
              const SizedBox(width: XpertSpacing.xs),
              Expanded(
                child: Text(
                  ref.t('otp.sent_to', {'phone': _formatPhone(phone)}),
                  style: XpertTypography.caption.copyWith(fontSize: 13.5),
                ),
              ),
              InkWell(
                onTap: goBack,
                borderRadius: BorderRadius.circular(XpertRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: XpertSpacing.xs,
                    vertical: 2,
                  ),
                  child: Text(
                    ref.t('otp.change'),
                    style: XpertTypography.caption.copyWith(
                      color: XpertColors.primaryDeep,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: XpertSpacing.lg),
          AuthCodeField(
            length: _otpLength,
            code: code,
            controller: hiddenController,
            focusNode: focusNode,
            hasError: codeError.value != null,
            onCompleted: () => verifyCode(hiddenController.text),
          ),
          if (codeError.value != null) ...[
            const SizedBox(height: XpertSpacing.sm),
            Text(
              codeError.value!,
              textAlign: TextAlign.center,
              style: XpertTypography.caption.copyWith(
                color: XpertColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: XpertSpacing.lg),
          AuthCta(
            label: ref.t('otp.verify'),
            isLoading: isBusy,
            onPressed: () => verifyCode(code),
          ),
          const SizedBox(height: XpertSpacing.md),
          Center(
            child: canResend
                ? AuthTextLink(label: ref.t('otp.resend'), onTap: resendCode)
                : Text(
                    ref.t('otp.resend_in', {'seconds': secondsLeft.value}),
                    style: XpertTypography.caption.copyWith(fontSize: 13.5),
                  ),
          ),
        ],
      ),
    );
  }
}

String _formatPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return phone;

  final String local;
  if (digits.length >= 12 && digits.startsWith('91')) {
    local = digits.substring(digits.length - 10);
  } else if (digits.length == 10) {
    local = digits;
  } else {
    return phone;
  }

  return '+91 ${local.substring(0, 4)} ${local.substring(4)}';
}
