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
import 'widgets/auth_legal_consent.dart';
import 'widgets/auth_primary_button.dart';
import 'widgets/auth_shell.dart';
import 'widgets/auth_text_field.dart';
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
            final result = await ref
                .read(referralApiProvider)
                .checkCode(code);
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

    // Once the keyboard is up the sheet has roughly half the height and the
    // partner is already typing, so the lines that explain the screen give way
    // to the controls that finish it.
    final hasKeyboard = MediaQuery.viewInsetsOf(context).bottom > 0;

    return AuthShell(
      headline: Text(
        ref.t('login.headline'),
        style: XpertTypography.display,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ref.t('login.welcome'),
            style: XpertTypography.title.copyWith(fontSize: 22),
          ),
          if (!hasKeyboard) ...[
            const SizedBox(height: XpertSpacing.xs),
            Text(
              ref.t('login.sheet.description'),
              style: XpertTypography.caption.copyWith(fontSize: 14),
            ),
          ],
          SizedBox(height: hasKeyboard ? XpertSpacing.lg : XpertSpacing.xl),
          AuthTextField(
            label: ref.t('login.phone.label'),
            controller: phone,
            focusNode: phoneFocus,
            hint: ref.t('login.phone.hint'),
            errorText: phoneError.value,
            enabled: !isBusy,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => sendCode(),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            prefix: const AuthPhonePrefix(),
          ),
          const SizedBox(height: XpertSpacing.md),
          // Optional, and only ever relevant on a partner's very first
          // sign-in — so it asks to be opened rather than sitting next to the
          // phone number competing for attention on every subsequent one.
          if (showReferral.value) ...[
            AuthTextField(
              label: ref.t('login.referral.label'),
              controller: referralCode,
              focusNode: referralFocus,
              hint: ref.t('login.referral.hint'),
              enabled: !isBusy,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              inputFormatters: [_UpperCaseCode()],
              errorText: codeCheck.value?.valid == false
                  ? ref.t('login.referral.invalid')
                  : null,
              onSubmitted: (_) => sendCode(),
            ),
            if (codeChecking.value || codeCheck.value?.valid == true)
              Padding(
                padding: const EdgeInsets.only(top: XpertSpacing.xs),
                child: Row(
                  children: [
                    Icon(
                      codeChecking.value
                          ? Icons.hourglass_empty_rounded
                          : Icons.check_circle_rounded,
                      size: 16,
                      color: codeChecking.value
                          ? XpertColors.muted
                          : XpertColors.success,
                    ),
                    const SizedBox(width: XpertSpacing.xs),
                    Expanded(
                      child: Text(
                        codeChecking.value
                            ? ref.t('login.referral.checking')
                            : (codeCheck.value?.referrerName == null
                                  ? ref.t('login.referral.valid_generic')
                                  : ref.t('login.referral.valid', {
                                      'name': codeCheck.value!.referrerName!,
                                    })),
                        style: XpertTypography.caption.copyWith(
                          fontSize: 12.5,
                          color: codeChecking.value
                              ? XpertColors.muted
                              : XpertColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ]
          else
            Align(
              alignment: Alignment.centerLeft,
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
          SizedBox(height: hasKeyboard ? XpertSpacing.lg : XpertSpacing.xl),
          AuthPrimaryButton(
            label: ref.t('login.cta'),
            isLoading: isBusy,
            onPressed: sendCode,
          ),
          // Directly under the control it qualifies — pressing the button is
          // the act of agreeing, so the terms belong to the button, not to the
          // bottom of the screen.
          const SizedBox(height: XpertSpacing.md),
          const AuthLegalConsent(),
        ],
      ),
    );
  }
}

/// Codes are typed off a screenshot or dictated over a call, so spaces and
/// lower case arrive constantly. Normalise as they type rather than rejecting.
class _UpperCaseCode extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cleaned = newValue.text
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: cleaned.length),
    );
  }
}
