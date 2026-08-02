import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import 'otp_controller.dart';
import 'widgets/auth_primary_button.dart';
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
          Align(
            alignment: Alignment.centerLeft,
            child: _BackButton(onTap: goBack),
          ),
          const SizedBox(height: XpertSpacing.lg),
          Text(
            ref.t('otp.title'),
            style: XpertTypography.title.copyWith(fontSize: 22),
          ),
          const SizedBox(height: XpertSpacing.xs),
          // The number is the thing to check before typing, so it leads the
          // line rather than hiding inside a sentence.
          Row(
            children: [
              Flexible(
                child: Text(
                  _formatPhone(phone),
                  style: XpertTypography.label.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: XpertSpacing.xs),
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
                      color: XpertColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: XpertSpacing.xl),
          LayoutBuilder(
            builder: (context, constraints) {
              const maxCellSize = 48.0;
              const minCellSize = 40.0;
              const gap = 8.0;
              final cellSize =
                  ((constraints.maxWidth - gap * (_otpLength - 1)) /
                          _otpLength)
                      .clamp(minCellSize, maxCellSize);
              final rowWidth = cellSize * _otpLength + gap * (_otpLength - 1);

              return Stack(
                alignment: Alignment.center,
                children: [
                  GestureDetector(
                    onTap: () => focusNode.requestFocus(),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var index = 0; index < _otpLength; index++) ...[
                          if (index > 0) const SizedBox(width: gap),
                          _OtpDigitCell(
                            size: cellSize,
                            digit: index < code.length ? code[index] : '',
                            isFocused:
                                focusNode.hasFocus && index == code.length,
                            hasError: codeError.value != null,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Opacity(
                    opacity: 0,
                    child: SizedBox(
                      width: rowWidth,
                      height: cellSize,
                      child: TextField(
                        controller: hiddenController,
                        focusNode: focusNode,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        enableSuggestions: false,
                        autocorrect: false,
                        showCursor: false,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(_otpLength),
                        ],
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (value) {
                          codeError.value = null;
                          if (value.length == _otpLength) verifyCode(value);
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          if (codeError.value != null) ...[
            const SizedBox(height: XpertSpacing.md),
            Text(
              codeError.value!,
              textAlign: TextAlign.center,
              style: XpertTypography.caption.copyWith(
                color: XpertColors.danger,
              ),
            ),
          ],
          const SizedBox(height: XpertSpacing.xl),
          AuthPrimaryButton(
            label: ref.t('otp.verify'),
            isLoading: isBusy,
            onPressed: () => verifyCode(code),
          ),
          const SizedBox(height: XpertSpacing.lg),
          Center(
            child: canResend
                ? AuthTextLink(label: ref.t('otp.resend'), onTap: resendCode)
                : Text(
                    ref.t('otp.resend_in', {'seconds': secondsLeft.value}),
                    style: XpertTypography.caption.copyWith(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
          ),
        ],
      ),
    );
  }
}

class _OtpDigitCell extends StatelessWidget {
  const _OtpDigitCell({
    required this.size,
    required this.digit,
    required this.isFocused,
    required this.hasError,
  });

  final double size;
  final String digit;
  final bool isFocused;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final filled = digit.isNotEmpty;
    final borderColor = hasError
        ? XpertColors.danger
        : isFocused
        ? XpertColors.primary
        : filled
        ? const Color(0xFFC9D6DE)
        : const Color(0xFFE3EAEF);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      width: size,
      height: size * 1.16,
      decoration: BoxDecoration(
        // An empty cell is a hole to fill, a filled one is done — colour says
        // so, so the cell needs no placeholder character.
        color: filled ? XpertColors.surface : const Color(0xFFF6F9FB),
        borderRadius: BorderRadius.circular(XpertRadius.md),
        border: Border.all(color: borderColor, width: isFocused ? 2 : 1.2),
      ),
      alignment: Alignment.center,
      child: filled
          ? Text(
              digit,
              style: XpertTypography.title.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            )
          : isFocused
          ? Container(
              width: 2,
              height: size * 0.42,
              decoration: BoxDecoration(
                color: XpertColors.primary,
                borderRadius: BorderRadius.circular(1),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

/// A quiet back affordance — the flow's only way out, so it stays visible
/// without competing with the code entry.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF2F6F9),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            Icons.arrow_back_rounded,
            size: 20,
            color: XpertColors.onSurface,
          ),
        ),
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
