import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/context_t.dart';
import '../../../core/i18n/locale_provider.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../../auth/data/partner_auth_api.dart';
import '../../auth/presentation/auth_controller.dart';

/// The first screen a partner sees in a language they chose.
///
/// It opened with nothing selected, so Continue was dead until you tapped
/// something — on a screen where the server already knew the answer. It now
/// starts on the language the profile carries, so the common case is one tap.
///
/// Each row leads with the language written in its own script, because a
/// partner who cannot read English finds their language by its shape, not by
/// reading a list of English names.
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

  @override
  void initState() {
    super.initState();
    // The profile already carries a language; falling back to whatever the
    // app is currently showing is still better than an empty selection.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final saved = ref.read(authProvider).valueOrNull?.profile?.language;
      setState(() {
        _selected =
            AppLocale.tryParse(saved) ?? ref.read(localeProvider);
      });
    });
  }

  void _preview(AppLocale locale) {
    setState(() {
      _selected = locale;
      _error = null;
    });
    // The whole screen re-renders in the tapped language straight away, which
    // is the clearest possible confirmation of what was chosen.
    ref.read(localeProvider.notifier).set(locale, persistLocal: false);
  }

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
    } catch (_) {
      if (!mounted) return;
      // The raw Dio exception used to be printed onto the screen.
      setState(() => _error = ref.t('language.error'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XpertColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                XpertSpacing.lg,
                XpertSpacing.xl,
                XpertSpacing.lg,
                XpertSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: XpertColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(XpertRadius.md),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.translate_rounded,
                      size: 22,
                      color: XpertColors.primary,
                    ),
                  ),
                  const SizedBox(height: XpertSpacing.md),
                  Text(
                    ref.t('language.title'),
                    style: XpertTypography.title.copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: XpertSpacing.xs),
                  Text(
                    ref.t('language.subtitle'),
                    style: XpertTypography.caption.copyWith(
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: XpertSpacing.lg,
                ),
                children: [
                  for (final locale in AppLocale.values) ...[
                    _LanguageCard(
                      locale: locale,
                      selected: _selected == locale,
                      enabled: !_busy,
                      onTap: () => _preview(locale),
                    ),
                    const SizedBox(height: XpertSpacing.sm),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                XpertSpacing.lg,
                XpertSpacing.md,
                XpertSpacing.lg,
                XpertSpacing.md,
              ),
              decoration: const BoxDecoration(
                color: XpertColors.surface,
                border: Border(top: BorderSide(color: Color(0xFFE8EDF1))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_error != null) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 15,
                          color: XpertColors.danger,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _error!,
                            style: XpertTypography.caption.copyWith(
                              color: XpertColors.danger,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: XpertSpacing.sm),
                  ],
                  SizedBox(
                    height: 54,
                    child: FilledButton(
                      onPressed: _busy || _selected == null ? null : _continue,
                      child: _busy
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              ref.t('language.cta'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageCard extends ConsumerWidget {
  const _LanguageCard({
    required this.locale,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final AppLocale locale;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The language's name in whatever language the app is currently showing.
    // Repeating it under an identical native name would just look broken.
    final inCurrentLanguage = ref.t('language.name.${locale.code}');
    final showsSecondary = inCurrentLanguage != locale.labelNative;

    return Semantics(
      button: true,
      selected: selected,
      label: locale.labelEn,
      child: Material(
        color: selected
            ? XpertColors.primary.withValues(alpha: 0.08)
            : XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(XpertRadius.lg),
          child: Container(
            padding: const EdgeInsets.all(XpertSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(XpertRadius.lg),
              border: Border.all(
                color: selected
                    ? XpertColors.primary
                    : XpertColors.border.withValues(alpha: 0.5),
                width: selected ? 2 : 1.2,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Set large and in its own script — this is what a
                      // partner who cannot read English recognises.
                      Text(
                        locale.labelNative,
                        style: XpertTypography.title.copyWith(
                          fontSize: 20,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (showsSecondary) ...[
                        const SizedBox(height: 2),
                        Text(
                          inCurrentLanguage,
                          style: XpertTypography.caption.copyWith(fontSize: 12.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: XpertSpacing.sm),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? XpertColors.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: selected
                          ? XpertColors.primary
                          : XpertColors.border,
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: XpertColors.onPrimary,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
