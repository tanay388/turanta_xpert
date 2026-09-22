import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/i18n/context_t.dart';
import '../../../../core/theme/xpert_tokens.dart';

/// Why the customer never gave the end code. Matches the backend's
/// `UnverifiedCloseReason` exactly — these strings go straight to the API.
const _reasons = <(String, IconData)>[
  ('CUSTOMER_UNAVAILABLE', Icons.person_off_rounded),
  ('CUSTOMER_LEFT', Icons.directions_walk_rounded),
  ('CUSTOMER_REFUSED', Icons.block_rounded),
  ('CODE_NOT_WORKING', Icons.password_rounded),
  ('OTHER', Icons.more_horiz_rounded),
];

/// What the partner picked, on the way back to the caller.
typedef CloseWithoutOtpChoice = ({String reason, String? note});

/// The way out of a job the customer will not close.
///
/// A helper who has finished the work and cannot get the code is otherwise
/// stuck holding a job open — and an open job takes them out of dispatch for
/// as long as it lasts, so this costs a whole shift rather than one booking.
/// The reason is required because the close is flagged for ops, not hidden
/// from them.
Future<CloseWithoutOtpChoice?> showCloseWithoutOtpSheet(BuildContext context) {
  return showModalBottomSheet<CloseWithoutOtpChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: XpertColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(XpertRadius.sheetTop),
      ),
    ),
    builder: (_) => const _CloseWithoutOtpSheet(),
  );
}

class _CloseWithoutOtpSheet extends ConsumerStatefulWidget {
  const _CloseWithoutOtpSheet();

  @override
  ConsumerState<_CloseWithoutOtpSheet> createState() =>
      _CloseWithoutOtpSheetState();
}

class _CloseWithoutOtpSheetState extends ConsumerState<_CloseWithoutOtpSheet> {
  String? _reason;
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _isOther => _reason == 'OTHER';

  // A free-text note is the whole content of "Other"; without it ops gets a
  // close with no explanation at all.
  bool get _canSubmit =>
      _reason != null && (!_isOther || _noteCtrl.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: XpertSpacing.lg,
        right: XpertSpacing.lg,
        top: XpertSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + XpertSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: XpertColors.border,
                borderRadius: BorderRadius.circular(XpertRadius.pill),
              ),
            ),
          ),
          const SizedBox(height: XpertSpacing.lg),
          Text(
            ref.t('jobs.close_no_otp.title'),
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: XpertColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            ref.t('jobs.close_no_otp.body'),
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: XpertColors.muted,
            ),
          ),
          const SizedBox(height: XpertSpacing.lg),
          Wrap(
            spacing: XpertSpacing.sm,
            runSpacing: XpertSpacing.sm,
            children: [
              for (final (code, icon) in _reasons)
                _ReasonChip(
                  icon: icon,
                  label: ref.t(
                    'jobs.close_no_otp.reason.${code.toLowerCase()}',
                  ),
                  selected: _reason == code,
                  onTap: () => setState(() => _reason = code),
                ),
            ],
          ),
          if (_isOther) ...[
            const SizedBox(height: XpertSpacing.md),
            TextField(
              controller: _noteCtrl,
              maxLength: 280,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: ref.t('jobs.close_no_otp.note_hint'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(XpertRadius.md),
                ),
              ),
            ),
          ],
          const SizedBox(height: XpertSpacing.md),
          Container(
            padding: const EdgeInsets.all(XpertSpacing.sm + 2),
            decoration: BoxDecoration(
              color: XpertColors.secondary,
              borderRadius: BorderRadius.circular(XpertRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: XpertColors.primaryDeep,
                ),
                const SizedBox(width: XpertSpacing.sm),
                Expanded(
                  child: Text(
                    // Said plainly: the pay is not at risk, but the close is
                    // visible. A helper guessing at either will avoid the
                    // button and stay stuck instead.
                    ref.t('jobs.close_no_otp.notice'),
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: XpertColors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: XpertSpacing.lg),
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: _canSubmit
                  ? () => Navigator.of(context).pop((
                      reason: _reason!,
                      note: _noteCtrl.text.trim().isEmpty
                          ? null
                          : _noteCtrl.text.trim(),
                    ))
                  : null,
              child: Text(ref.t('jobs.close_no_otp.cta')),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? XpertColors.primary.withValues(alpha: 0.12)
            : const Color(0xFFF6F9FB),
        borderRadius: BorderRadius.circular(XpertRadius.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(XpertRadius.pill),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: XpertSpacing.md,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(XpertRadius.pill),
              border: Border.all(
                color: selected ? XpertColors.primary : const Color(0xFFDCE4EA),
                width: selected ? 1.8 : 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? XpertColors.primary : XpertColors.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? XpertColors.onSurface
                        : XpertColors.onSurface.withValues(alpha: 0.75),
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
