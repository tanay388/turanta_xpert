import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
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
          if (showReferral.value)
            AuthTextField(
              label: ref.t('login.referral.label'),
              controller: referralCode,
              focusNode: referralFocus,
              hint: ref.t('login.referral.hint'),
              enabled: !isBusy,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => sendCode(),
            )
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
