import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/context_t.dart';
import '../../../core/i18n/locale_provider.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../../auth/data/partner_auth_api.dart';
import '../../auth/presentation/auth_controller.dart';

class LanguageSelectionScreen extends ConsumerStatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  ConsumerState<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState
    extends ConsumerState<LanguageSelectionScreen> {
  AppLocale? _selected;
  bool _busy = false;
  String? _error;

  Future<void> _continue() async {
    final selected = _selected;
    if (selected == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(partnerAuthApiProvider).updateLanguage(selected.code);
      await ref.read(localeProvider.notifier).set(selected);
      await ref.read(authProvider.notifier).refreshProfile();
      if (!mounted) return;
      final session = ref.read(authProvider).valueOrNull;
      if (session == null) {
        context.go('/login');
        return;
      }
      if (session.deviceMismatch) {
        context.go('/device-blocked');
      } else if (session.needsKyc) {
        context.go('/kyc');
      } else if (session.isPendingApproval || !session.canUseHome) {
        context.go('/pending-approval');
      } else {
        context.go('/home');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XpertColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(XpertSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: XpertSpacing.xl),
              Text(
                ref.t('language.title'),
                style: XpertTypography.title.copyWith(fontSize: 28),
              ),
              const SizedBox(height: XpertSpacing.sm),
              Text(
                ref.t('language.subtitle'),
                style: XpertTypography.body.copyWith(color: XpertColors.muted),
              ),
              const SizedBox(height: XpertSpacing.xl),
              Expanded(
                child: ListView(
                  children: AppLocale.values.map((locale) {
                    final selected = _selected == locale;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: XpertSpacing.sm),
                      child: Material(
                        color: XpertColors.surface,
                        borderRadius: BorderRadius.circular(XpertRadius.md),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(XpertRadius.md),
                          onTap: _busy
                              ? null
                              : () {
                                  setState(() => _selected = locale);
                                  // Preview UI language immediately while choosing.
                                  ref
                                      .read(localeProvider.notifier)
                                      .set(locale, persistLocal: false);
                                },
                          child: Container(
                            padding: const EdgeInsets.all(XpertSpacing.md),
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(XpertRadius.md),
                              border: Border.all(
                                color: selected
                                    ? XpertColors.primary
                                    : XpertColors.border,
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        locale.labelNative,
                                        style: XpertTypography.label.copyWith(
                                          fontSize: 18,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        locale.labelEn,
                                        style: XpertTypography.caption,
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  selected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: selected
                                      ? XpertColors.primary
                                      : XpertColors.muted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: XpertTypography.caption.copyWith(
                    color: XpertColors.danger,
                  ),
                ),
                const SizedBox(height: XpertSpacing.sm),
              ],
              FilledButton(
                onPressed: _busy || _selected == null ? null : _continue,
                child: _busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(ref.t('language.cta')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
