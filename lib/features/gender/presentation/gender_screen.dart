import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../app/router.dart';
import '../../../core/i18n/context_t.dart';
import '../../../core/models/gender.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../../auth/data/partner_auth_api.dart';
import '../../auth/presentation/auth_controller.dart';

/// Asks a partner their gender, once.
///
/// It is its own gate rather than a field inside the KYC wizard because the
/// partners who onboarded before we asked are already past that wizard — this
/// screen catches them on their next launch, whatever else they have cleared.
class GenderScreen extends ConsumerStatefulWidget {
  const GenderScreen({super.key});

  @override
  ConsumerState<GenderScreen> createState() => _GenderScreenState();
}

class _GenderScreenState extends ConsumerState<GenderScreen> {
  String? _selected;
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
      await ref.read(partnerAuthApiProvider).updateProfile(gender: selected);
      await ref.read(authProvider.notifier).refreshProfile();
      if (!mounted) return;
      final session = ref.read(authProvider).valueOrNull;
      if (session == null) {
        context.go('/login');
        return;
      }
      context.go(partnerDestination(PartnerGates.of(session)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = ref.t('gender.error'));
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  XpertSpacing.lg,
                  XpertSpacing.xl,
                  XpertSpacing.lg,
                  XpertSpacing.lg,
                ),
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: XpertColors.heroAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(XpertRadius.md),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.badge_outlined,
                        size: 22,
                        color: XpertColors.heroAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: XpertSpacing.md),
                  Text(
                    ref.t('gender.title'),
                    style: XpertTypography.title.copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: XpertSpacing.xs),
                  Text(
                    ref.t('gender.subtitle'),
                    style: XpertTypography.caption.copyWith(
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: XpertSpacing.xl),
                  // Inside a ListView the row has no height of its own, and
                  // the three boxes must still end up the same size whichever
                  // language makes one label wrap.
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final option in kGenderOptions) ...[
                          if (option != kGenderOptions.first)
                            const SizedBox(width: XpertSpacing.sm),
                          Expanded(
                            child: _GenderBox(
                              label: ref.t(genderLabelKey(option)),
                              icon: _iconFor(option),
                              selected: _selected == option,
                              onTap: _busy
                                  ? null
                                  : () => setState(() {
                                      _selected = option;
                                      _error = null;
                                    }),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
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
                              ref.t('gender.cta'),
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

IconData _iconFor(String option) => switch (option) {
  'Male' => Icons.man_rounded,
  'Female' => Icons.woman_rounded,
  _ => Icons.person_rounded,
};

class _GenderBox extends StatelessWidget {
  const _GenderBox({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = selected ? XpertColors.heroAccent : XpertColors.muted;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? XpertColors.heroAccent.withValues(alpha: 0.10)
            : const Color(0xFFF6F9FB),
        borderRadius: BorderRadius.circular(XpertRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(XpertRadius.lg),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: XpertSpacing.md,
            ),
            // Painted over the box rather than inside it, so the thicker
            // selected border does not shift the icon and label.
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(XpertRadius.lg),
              border: Border.all(
                color: selected
                    ? XpertColors.heroAccent
                    : const Color(0xFFDCE4EA),
                width: selected ? 1.8 : 1.2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 38, color: accent),
                const SizedBox(height: XpertSpacing.sm),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.2,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected
                        ? XpertColors.heroAccent
                        : XpertColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
