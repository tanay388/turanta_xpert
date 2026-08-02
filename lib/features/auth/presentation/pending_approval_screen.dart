import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import 'auth_controller.dart';

/// Where a partner waits after submitting verification.
///
/// This is the last thing they see for however long review takes, and it used
/// to be an hourglass, two sentences and a Check status button — with no sense
/// of what had already happened, what happens next, or how long it takes. The
/// timeline answers that, because the alternative is a partner tapping Check
/// status every few minutes.
class PendingApprovalScreen extends ConsumerStatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  ConsumerState<PendingApprovalScreen> createState() =>
      _PendingApprovalScreenState();
}

class _PendingApprovalScreenState
    extends ConsumerState<PendingApprovalScreen> {
  bool _checking = false;

  Future<void> _check() async {
    setState(() => _checking = true);
    await ref.read(authProvider.notifier).bootstrap();
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ref.t('settings.signout.confirm.title')),
        content: Text(ref.t('settings.signout.confirm.body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ref.t('leave.no')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: XpertColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ref.t('pending.sign_out')),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(authProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XpertColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: XpertColors.background,
        actions: [
          TextButton(
            onPressed: _confirmSignOut,
            child: Text(ref.t('pending.sign_out')),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            XpertSpacing.lg,
            XpertSpacing.md,
            XpertSpacing.lg,
            XpertSpacing.xxl,
          ),
          children: [
            Center(
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: XpertColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(XpertRadius.xl),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  size: 36,
                  color: XpertColors.primary,
                ),
              ),
            ),
            const SizedBox(height: XpertSpacing.lg),
            Text(
              ref.t('pending.title'),
              textAlign: TextAlign.center,
              style: XpertTypography.title.copyWith(fontSize: 24),
            ),
            const SizedBox(height: XpertSpacing.xs),
            Text(
              ref.t('pending.body'),
              textAlign: TextAlign.center,
              style: XpertTypography.caption.copyWith(
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: XpertSpacing.xxl),
            const _Timeline(),
            const SizedBox(height: XpertSpacing.xxl),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _checking ? null : _check,
                icon: _checking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: XpertColors.onPrimary,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, size: 19),
                label: Text(
                  ref.t('pending.check'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: XpertSpacing.sm),
            // Says the wait is passive, so nobody sits here refreshing.
            Text(
              ref.t('pending.notify_hint'),
              textAlign: TextAlign.center,
              style: XpertTypography.caption.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Submitted → under review → ready. Two done, one to go.
class _Timeline extends ConsumerWidget {
  const _Timeline();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const stages = [
      ('pending.stage.submitted', true),
      ('pending.stage.review', true),
      ('pending.stage.approved', false),
    ];

    return Column(
      children: [
        for (var i = 0; i < stages.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: stages[i].$2
                              ? XpertColors.primary
                              : XpertColors.surface,
                          border: Border.all(
                            color: stages[i].$2
                                ? XpertColors.primary
                                : XpertColors.border,
                            width: 2,
                          ),
                        ),
                        child: stages[i].$2
                            ? const Icon(
                                Icons.check_rounded,
                                size: 9,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      Expanded(
                        child: Container(
                          width: 2,
                          color: i == stages.length - 1
                              ? Colors.transparent
                              : XpertColors.border.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: XpertSpacing.sm),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: i == stages.length - 1 ? 0 : XpertSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ref.t('${stages[i].$1}.title'),
                          style: XpertTypography.label.copyWith(
                            fontSize: 14.5,
                            color: stages[i].$2
                                ? XpertColors.onSurface
                                : XpertColors.muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ref.t('${stages[i].$1}.body'),
                          style: XpertTypography.caption.copyWith(
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
