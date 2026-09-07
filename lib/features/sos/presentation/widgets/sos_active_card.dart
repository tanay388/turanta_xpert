import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/i18n/context_t.dart';
import '../../../../core/theme/xpert_tokens.dart';
import '../sos_controller.dart';

/// What the helper sees after pressing SOS.
///
/// It exists so "click and forget" is honest: the alert's state is on screen
/// without the helper having to do anything, including after a relaunch.
class SosActiveCard extends ConsumerWidget {
  const SosActiveCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sos = ref.watch(sosProvider);
    if (sos.phase == SosPhase.idle) return const SizedBox.shrink();

    final failed = sos.phase == SosPhase.failed;
    final sending = sos.phase == SosPhase.sending;

    final title = switch (sos.phase) {
      SosPhase.sending => ref.t('sos.sending_title'),
      SosPhase.sent => ref.t('sos.sent_title'),
      SosPhase.failed => ref.t('sos.failed_title'),
      SosPhase.idle => '',
    };
    final body = switch (sos.phase) {
      SosPhase.sending => ref.t('sos.sending_body'),
      SosPhase.sent => ref.t('sos.sent_body'),
      SosPhase.failed => ref.t('sos.failed_body'),
      SosPhase.idle => '',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        XpertSpacing.lg,
        XpertSpacing.md,
        XpertSpacing.lg,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(XpertSpacing.md),
        decoration: BoxDecoration(
          color: XpertColors.danger.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(XpertRadius.lg),
          border: Border.all(color: XpertColors.danger.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: sending
                  ? const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: XpertColors.danger,
                    )
                  : Icon(
                      failed
                          ? Icons.error_outline_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 22,
                      color: XpertColors.danger,
                    ),
            ),
            const SizedBox(width: XpertSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: XpertTypography.label.copyWith(fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: XpertTypography.body.copyWith(
                      fontSize: 13,
                      color: XpertColors.muted,
                    ),
                  ),
                  if (sos.phase == SosPhase.sent) ...[
                    const SizedBox(height: XpertSpacing.sm),
                    TextButton(
                      onPressed: () => _confirmCancel(context, ref),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(ref.t('sos.cancel')),
                    ),
                  ],
                  if (failed) ...[
                    const SizedBox(height: XpertSpacing.sm),
                    TextButton(
                      onPressed: () => ref.read(sosProvider.notifier).raise(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(ref.t('sos.retry')),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ref.t('sos.cancel_title')),
        content: Text(ref.t('sos.cancel_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ref.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ref.t('sos.cancel_confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(sosProvider.notifier).cancel();
  }
}
