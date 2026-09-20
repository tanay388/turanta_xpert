import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../../referral/data/referral_api.dart';
import 'auth_controller.dart';
import 'otp_controller.dart';
import 'widgets/auth_inputs.dart';
import 'widgets/auth_legal_consent.dart';
import 'widgets/auth_shell.dart';
import 'widgets/auth_text_link.dart';

class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(otpProvider);
    final controller = ref.read(otpProvider.notifier);

    final phone = useTextEditingController();
    final phoneFocus = useFocusNode();
    final phoneError = useState<String?>(null);
    final referralCode = useTextEditingController();
    final referralFocus = useFocusNode();
    final showReferral = useState(false);
    final isBusy = state is OtpSending;

    // Check the code while it is typed: a partner should never send an OTP,
    // sign up, and only then discover the code was a typo — which, until now,
    // nothing anywhere told them.
    final codeCheck = useState<ReferralCodeCheck?>(null);
    final codeChecking = useState(false);
    useEffect(() {
      Timer? debounce;
      void onChanged() {
        final code = referralCode.text.trim().toUpperCase();
        debounce?.cancel();
        if (code.length < 6) {
          codeChecking.value = false;
          codeCheck.value = null;
          return;
        }
        codeChecking.value = true;
        codeCheck.value = null;
        debounce = Timer(const Duration(milliseconds: 350), () async {
          try {
            final result = await ref.read(referralApiProvider).checkCode(code);
            if (referralCode.text.trim().toUpperCase() != code) return;
            codeChecking.value = false;
            codeCheck.value = result;
          } catch (_) {
            // Offline or API down: stay quiet and let the server decide at
            // signup rather than blocking sign-in over a nicety.
            codeChecking.value = false;
            codeCheck.value = null;
          }
        });
      }

      referralCode.addListener(onChanged);
      return () {
        debounce?.cancel();
        referralCode.removeListener(onChanged);
      };
    }, [referralCode]);

    final rejection = ref.watch(authRejectionProvider);
    useEffect(() {
      if (rejection == null) return null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              backgroundColor: XpertColors.danger,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 6),
              content: Text('$rejection\n${ref.t('login.rejected.hint')}'),
            ),
          );
        ref.read(authRejectionProvider.notifier).state = null;
      });
      return null;
    }, [rejection]);

    useEffect(() {
      if (state is OtpCodeSent) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.go('/otp');
        });
      } else if (state is OtpFailed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          phoneError.value = ref.t(state.message);
        });
      }
      return null;
    }, [state]);

    Future<void> sendCode() async {
      final raw = phone.text.trim();
      if (raw.length < 10) {
        phoneError.value = ref.t('login.phone.error');
        return;
      }
      phoneError.value = null;
      final code = referralCode.text.trim();
      ref.read(pendingReferralCodeProvider.notifier).state = code.isEmpty
          ? null
          : code;
      final normalized = raw.startsWith('+') ? raw : '+91$raw';
      await controller.sendOtp(normalized);
    }

    final hasKeyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final checked = codeCheck.value;

    return AuthShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthPhoneField(
            controller: phone,
            focusNode: phoneFocus,
            hint: ref.t('login.phone.hint'),
            enabled: !isBusy,
            errorText: phoneError.value,
            onSubmitted: sendCode,
          ),
          const SizedBox(height: XpertSpacing.md),
          // Optional, and only ever relevant on a partner's first sign-in, so
          // it asks to be opened rather than sitting in the way of everyone
          // else's.
          if (showReferral.value) ...[
            _ReferralField(
              controller: referralCode,
              focusNode: referralFocus,
              enabled: !isBusy,
              label: ref.t('login.referral.label'),
              hint: ref.t('login.referral.hint'),
              errorText: checked?.valid == false
                  ? ref.t('login.referral.invalid')
                  : null,
              note: codeChecking.value
                  ? ref.t('login.referral.checking')
                  : checked != null && checked.valid
                  ? (checked.referrerName == null
                        ? ref.t('login.referral.valid_generic')
                        : ref.t('login.referral.valid', {
                            'name': checked.referrerName!,
                          }))
                  : null,
              noteIsGood: !codeChecking.value,
              onSubmitted: sendCode,
            ),
            const SizedBox(height: XpertSpacing.md),
          ] else
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AuthTextLink(
                label: ref.t('login.referral.toggle'),
                onTap: () {
                  showReferral.value = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    referralFocus.requestFocus();
                  });
                },
              ),
            ),
          const SizedBox(height: XpertSpacing.md),
          AuthCta(
            label: ref.t('login.cta'),
            isLoading: isBusy,
            onPressed: sendCode,
          ),
          const SizedBox(height: XpertSpacing.sm),
          const AuthLegalConsent(),
        ],
      ),
    );
  }
}

/// The referral code: same card, quieter than the number it sits under.
class _ReferralField extends StatelessWidget {
  const _ReferralField({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.label,
    required this.hint,
    required this.errorText,
    required this.note,
    required this.noteIsGood,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final String label;
  final String hint;
  final String? errorText;
  final String? note;
  final bool noteIsGood;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          inputFormatters: [UpperCaseCode()],
          onSubmitted: (_) => onSubmitted(),
          style: XpertTypography.label.copyWith(fontSize: 16, letterSpacing: 2),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            filled: true,
            fillColor: XpertColors.background,
            errorText: errorText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(XpertRadius.lg),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(XpertRadius.lg),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(XpertRadius.lg),
              borderSide: const BorderSide(
                color: XpertColors.primaryDeep,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: XpertSpacing.xs),
          Row(
            children: [
              Icon(
                noteIsGood
                    ? Icons.check_circle_rounded
                    : Icons.hourglass_empty_rounded,
                size: 15,
                color: noteIsGood ? XpertColors.success : XpertColors.muted,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  note!,
                  style: XpertTypography.caption.copyWith(
                    fontSize: 12.5,
                    color: noteIsGood ? XpertColors.success : XpertColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Codes are typed off a screenshot or dictated over a call, so spaces and
/// lower case arrive constantly. Normalise as they type rather than rejecting.
class UpperCaseCode extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cleaned = newValue.text.toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: cleaned.length),
    );
  }
}
