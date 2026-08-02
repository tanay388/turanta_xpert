import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import 'otp_controller.dart';

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

    final maskedPhone = phone.length >= 4
        ? '•••• ${phone.substring(phone.length - 4)}'
        : phone;

    return Scaffold(
      backgroundColor: XpertColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            controller.reset();
            context.go('/login');
          },
        ),
        title: Text(ref.t('otp.title')),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(XpertSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ref.t('otp.sent', {'phone': maskedPhone}),
                style: XpertTypography.body.copyWith(color: XpertColors.muted),
              ),
              const SizedBox(height: XpertSpacing.xl),
              GestureDetector(
                onTap: () => focusNode.requestFocus(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(_otpLength, (i) {
                    final filled = i < code.length;
                    final char = filled ? code[i] : '';
                    final isActive = i == code.length && focusNode.hasFocus;
                    return Container(
                      width: 48,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: XpertColors.surface,
                        borderRadius: BorderRadius.circular(XpertRadius.md),
                        border: Border.all(
                          color: codeError.value != null
                              ? XpertColors.danger
                              : isActive
                                  ? XpertColors.primary
                                  : XpertColors.border,
                          width: isActive ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        char,
                        style: XpertTypography.title.copyWith(fontSize: 22),
                      ),
                    );
                  }),
                ),
              ),
              Opacity(
                opacity: 0,
                child: TextField(
                  controller: hiddenController,
                  focusNode: focusNode,
                  keyboardType: TextInputType.number,
                  maxLength: _otpLength,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) {
                    codeError.value = null;
                    if (value.length == _otpLength) verifyCode(value);
                  },
                ),
              ),
              if (codeError.value != null) ...[
                Text(
                  codeError.value!,
                  style: XpertTypography.caption.copyWith(
                    color: XpertColors.danger,
                  ),
                ),
                const SizedBox(height: XpertSpacing.md),
              ],
              FilledButton(
                onPressed: isBusy ? null : () => verifyCode(code),
                child: isBusy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(ref.t('otp.verify')),
              ),
              const SizedBox(height: XpertSpacing.md),
              TextButton(
                onPressed: secondsLeft.value > 0 ? null : resendCode,
                child: Text(
                  secondsLeft.value > 0
                      ? ref.t('otp.resend_in', {
                          'seconds': secondsLeft.value,
                        })
                      : ref.t('otp.resend'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
