import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import 'auth_controller.dart';
import 'otp_controller.dart';

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
      ref.read(pendingReferralCodeProvider.notifier).state =
          code.isEmpty ? null : code;
      final normalized = raw.startsWith('+') ? raw : '+91$raw';
      await controller.sendOtp(normalized);
    }

    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: XpertColors.background,
      body: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(
            XpertSpacing.lg,
            XpertSpacing.xxl,
            XpertSpacing.lg,
            XpertSpacing.lg + keyboardInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 1),
              _BrandHeader(),
              const SizedBox(height: XpertSpacing.xxl),
              Text(
                ref.t('login.welcome'),
                textAlign: TextAlign.center,
                style: XpertTypography.body.copyWith(color: XpertColors.muted),
              ),
              const SizedBox(height: XpertSpacing.xl),
              Text(
                ref.t('login.phone.label'),
                style: XpertTypography.label,
              ),
              const SizedBox(height: XpertSpacing.sm),
              TextField(
                controller: phone,
                focusNode: phoneFocus,
                enabled: !isBusy,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => sendCode(),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  hintText: ref.t('login.phone.hint'),
                  errorText: phoneError.value,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 14, right: 8),
                    child: Text(
                      '+91',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: XpertColors.onSurface,
                      ),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0),
                ),
              ),
              const SizedBox(height: XpertSpacing.md),
              TextField(
                controller: referralCode,
                enabled: !isBusy,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => sendCode(),
                decoration: InputDecoration(
                  labelText: ref.t('login.referral.label'),
                ),
              ),
              const SizedBox(height: XpertSpacing.xl),
              FilledButton(
                onPressed: isBusy ? null : sendCode,
                child: isBusy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(ref.t('login.cta')),
              ),
              const Spacer(flex: 2),
              Text(
                ref.t('login.terms'),
                textAlign: TextAlign.center,
                style: XpertTypography.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(XpertRadius.lg),
            border: Border.all(color: XpertColors.border.withValues(alpha: 0.4)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(XpertRadius.lg),
            child: Image.asset(
              'assets/logo/turanta_xpert_app_logo.png',
              width: 84,
              height: 84,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: XpertSpacing.md),
        Text(
          'Turanta Xpert',
          textAlign: TextAlign.center,
          style: XpertTypography.title.copyWith(
            fontSize: 30,
            color: XpertColors.onSurface,
          ),
        ),
      ],
    );
  }
}
