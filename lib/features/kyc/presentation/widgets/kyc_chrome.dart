import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/i18n/context_t.dart';
import '../../../../core/theme/xpert_tokens.dart';

/// Where you are in the wizard.
///
/// Progress used to be one unlabelled bar, with the current step's name in the
/// app-bar title and no indication of how many were left. Six steps of
/// document photography is a long way to walk without being told how far.
class KycStepper extends ConsumerWidget {
  const KycStepper({
    super.key,
    required this.step,
    required this.total,
    required this.label,
  });

  final int step;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: XpertTypography.title.copyWith(fontSize: 19),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: XpertSpacing.sm),
            Text(
              ref.t('kyc.step_of', {
                'step': '${step + 1}',
                'total': '$total',
              }),
              style: XpertTypography.caption.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: XpertSpacing.sm),
        // Segments rather than a continuous bar: the steps are discrete, and
        // seeing four still to go is the useful part.
        Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 5,
                  decoration: BoxDecoration(
                    color: i <= step
                        ? XpertColors.primary
                        : XpertColors.border.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(XpertRadius.pill),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// A document to photograph.
///
/// The old tile was a bare `ListTile` reading "Uploaded" — with no way to see
/// *what* you uploaded. Photographing the wrong side of an Aadhaar card and
/// finding out days later from a rejection is the failure this prevents.
class KycDocTile extends ConsumerWidget {
  const KycDocTile({
    super.key,
    required this.label,
    required this.hint,
    required this.storageKey,
    required this.previewUrl,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final String hint;
  final String? storageKey;
  final String? previewUrl;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploaded = storageKey != null;

    return Material(
      color: uploaded
          ? XpertColors.success.withValues(alpha: 0.06)
          : XpertColors.surface,
      borderRadius: BorderRadius.circular(XpertRadius.lg),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(XpertSpacing.sm + 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(XpertRadius.lg),
            border: Border.all(
              color: uploaded
                  ? XpertColors.success.withValues(alpha: 0.45)
                  : XpertColors.border.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            children: [
              _Thumb(uploaded: uploaded, previewUrl: previewUrl),
              const SizedBox(width: XpertSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: XpertTypography.label.copyWith(fontSize: 14.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      uploaded ? ref.t('kyc.doc.retake') : hint,
                      style: XpertTypography.caption.copyWith(
                        fontSize: 12,
                        color: uploaded
                            ? XpertColors.success
                            : XpertColors.muted,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              Icon(
                uploaded
                    ? Icons.check_circle_rounded
                    : Icons.add_a_photo_outlined,
                size: 20,
                color: uploaded ? XpertColors.success : XpertColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.uploaded, required this.previewUrl});

  final bool uploaded;
  final String? previewUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: XpertColors.background,
        borderRadius: BorderRadius.circular(XpertRadius.md),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: uploaded && previewUrl != null
          ? Image.network(
              previewUrl!,
              fit: BoxFit.cover,
              width: 54,
              height: 54,
              // A signed preview link can expire; a broken image should not
              // make a completed step look incomplete.
              errorBuilder: (_, _, _) => const Icon(
                Icons.description_rounded,
                size: 20,
                color: XpertColors.success,
              ),
            )
          : Icon(
              uploaded ? Icons.description_rounded : Icons.photo_outlined,
              size: 20,
              color: uploaded ? XpertColors.success : XpertColors.border,
            ),
    );
  }
}

/// A line on the review step, with a way back to the step that produced it.
class KycReviewRow extends StatelessWidget {
  const KycReviewRow({
    super.key,
    required this.label,
    required this.value,
    required this.onEdit,
    this.ok = true,
  });

  final String label;
  final String value;
  final VoidCallback onEdit;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: XpertSpacing.md,
          vertical: XpertSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: XpertTypography.caption.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: XpertTypography.label.copyWith(
                      fontSize: 14.5,
                      color: ok ? XpertColors.onSurface : XpertColors.danger,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Review was a wall of Text with no way back to fix anything
            // short of stepping backwards through the whole wizard.
            const Icon(
              Icons.edit_outlined,
              size: 16,
              color: XpertColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
