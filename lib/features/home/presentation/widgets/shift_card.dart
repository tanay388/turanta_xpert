import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/context_t.dart';
import '../../../../core/models/partner_break.dart';
import '../../../../core/theme/xpert_tokens.dart';
import '../availability_controller.dart';
import 'break_control.dart';
import 'early_checkout_sheet.dart';
import 'shift_clock.dart';

/// The shift. This tab is called Check-in, so this is the screen's hero — it
/// leads, it is the tallest thing, and it carries the only filled button.
///
/// It used to sit third, under four stat tiles, at the same visual weight as
/// a refer-a-friend row, and it decided what to offer from a handful of loose
/// booleans. Everything it shows now comes from one [ShiftPhase], so the card
/// cannot offer a check-in the server has already refused.
class ShiftCard extends ConsumerWidget {
  const ShiftCard({
    super.key,
    required this.attendance,
    this.blockedByJob = false,
  });

  final AttendanceState attendance;

  /// A job is assigned or running, so the server will refuse check-out and
  /// break-start. The card hides both rather than offering a button whose only
  /// possible outcome is an error toast.
  final bool blockedByJob;

  Future<void> _checkIn(BuildContext context, WidgetRef ref) async {
    final blocked = await ref.read(attendanceProvider.notifier).checkIn();
    if (!context.mounted) return;
    if (blocked != null) {
      final msg =
          ref.read(attendanceProvider).error ??
          ref.t('home.check_in_outside_hours', {
            'hours': attendance.currentShift?.shift.displayWindow ?? '—',
          });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _checkOut(BuildContext context, WidgetRef ref) async {
    final scheduledEnd =
        attendance.snapshot?.scheduledEndAt ??
        attendance.currentShift?.scheduledEndAt;
    final isEarly =
        scheduledEnd != null && DateTime.now().isBefore(scheduledEnd);

    String? reasonCode;
    String? reasonText;
    if (isEarly) {
      final result = await showModalBottomSheet<Map<String, String>>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => const EarlyCheckoutSheet(),
      );
      if (result == null) return;
      reasonCode = result['code'];
      reasonText = result['text'];
    }

    final blocked = await ref
        .read(attendanceProvider.notifier)
        .checkOut(reasonCode: reasonCode, reasonText: reasonText);
    if (!context.mounted) return;
    if (blocked != null) {
      final msg =
          ref.read(attendanceProvider).error ?? ref.t('home.checkout_failed');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _toggleBreak(BuildContext context, WidgetRef ref) async {
    final err = attendance.isOnBreak
        ? await ref.read(attendanceProvider.notifier).endBreak()
        : await ref.read(attendanceProvider.notifier).startBreak();
    if (!context.mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = attendance.phase;
    final shift = attendance.currentShift?.shift;
    final partnerBreak = attendance.currentShift?.partnerBreak;
    final hours = shift?.displayWindow ?? '—';
    final opensAt = attendance.currentShift?.allowedCheckinFrom;

    final statusColor = switch (phase) {
      ShiftPhase.onBreak => const Color(0xFFE65100),
      ShiftPhase.onShift => XpertColors.online,
      ShiftPhase.complete => XpertColors.success,
      ShiftPhase.missed || ShiftPhase.inactive => XpertColors.danger,
      ShiftPhase.onLeave => const Color(0xFF1565C0),
      ShiftPhase.upcoming => XpertColors.primary,
      ShiftPhase.ready || ShiftPhase.unavailable => XpertColors.offline,
    };

    final statusLabel = switch (phase) {
      ShiftPhase.onBreak => ref.t('home.break_on_title'),
      ShiftPhase.onShift => ref.t('home.checked_in'),
      ShiftPhase.complete => ref.t('home.status_completed'),
      ShiftPhase.missed => ref.t('home.status_shift_missed'),
      ShiftPhase.inactive => ref.t('home.status_inactive'),
      ShiftPhase.onLeave => ref.t('home.status_on_leave'),
      ShiftPhase.upcoming => ref.t('home.status_upcoming'),
      ShiftPhase.ready || ShiftPhase.unavailable => ref.t('home.checked_out'),
    };

    final subtitle = switch (phase) {
      ShiftPhase.onBreak => ref.t('home.break_in_progress_hint'),
      // "Available for new jobs" is untrue while one is already in hand.
      ShiftPhase.onShift when blockedByJob => ref.t('home.on_job_hint'),
      ShiftPhase.onShift => ref.t('home.online_hint'),
      ShiftPhase.complete => ref.t('home.completed_body'),
      ShiftPhase.missed => ref.t('home.shift_missed_body', {'hours': hours}),
      ShiftPhase.inactive => ref.t('home.inactive_body'),
      ShiftPhase.onLeave => ref.t('home.on_leave_body'),
      ShiftPhase.upcoming => ref.t('home.upcoming_body', {
        'time': opensAt == null ? '—' : _clock(opensAt),
      }),
      ShiftPhase.ready => ref.t('home.offline_hint'),
      ShiftPhase.unavailable => ref.t('home.check_in_unavailable_body'),
    };

    // Only ShiftPhase.ready earns a live Check in button. Every other phase
    // either offers check-out, or offers nothing at all.
    final checkInLabel = switch (phase) {
      ShiftPhase.complete => ref.t('home.check_in_blocked_complete'),
      ShiftPhase.missed => ref.t('home.check_in_blocked_missed'),
      ShiftPhase.onLeave => ref.t('home.check_in_blocked_leave'),
      ShiftPhase.inactive => ref.t('home.check_in_blocked_inactive'),
      ShiftPhase.upcoming => ref.t('home.check_in_opens', {
        'time': opensAt == null ? '—' : _clock(opensAt),
      }),
      _ => ref.t('home.check_in'),
    };

    final isCheckedIn =
        phase == ShiftPhase.onShift || phase == ShiftPhase.onBreak;
    final canCheckIn = phase == ShiftPhase.ready;
    // A day that is over needs no button — the shift card becomes a receipt.
    final showsCheckInButton = !isCheckedIn && phase != ShiftPhase.complete;

    final startedAt = attendance.snapshot?.sessionStartedAt;

    // "You are available for new jobs" under a green CHECKED IN pill is the
    // same sentence twice, and on a break the break row already says it. The
    // line stays wherever it tells the partner something to do.
    final showSubtitle =
        !(phase == ShiftPhase.onShift && !blockedByJob) &&
        phase != ShiftPhase.onBreak;

    return Container(
      padding: const EdgeInsets.all(XpertSpacing.md),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Expanded and aligned, not Flexible beside a Spacer: both take
              // flex 1, so they split the row and truncated "Checked out" to
              // "Checked …" with half the width standing empty.
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _StatusPill(color: statusColor, label: statusLabel),
                ),
              ),
              const SizedBox(width: XpertSpacing.sm),
              if (attendance.loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (shift != null)
                // The hours, where the date used to be. The date told a
                // partner nothing they did not know; the hours are what the
                // status is measured against.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: XpertColors.muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      shift.compactWindowLabel,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: XpertColors.muted,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (isCheckedIn && startedAt != null) ...[
            const SizedBox(height: XpertSpacing.md),
            ShiftClock(startedAt: startedAt),
            // A bare 02:14:00 could be a countdown, a time of day or an ETA.
            Text(
              ref.t('home.on_shift_for'),
              style: XpertTypography.caption.copyWith(fontSize: 12.5),
            ),
          ],
          if (showSubtitle) ...[
            const SizedBox(height: XpertSpacing.sm),
            Text(subtitle, style: XpertTypography.caption),
          ],
          // Ending a break stays available even with a job in hand — the
          // server guards only break *start*, and a partner handed a job
          // mid-break has to be able to come back from it.
          if (shift != null &&
              phase != ShiftPhase.complete &&
              (!blockedByJob || phase == ShiftPhase.onBreak)) ...[
            const SizedBox(height: XpertSpacing.md),
            BreakControl(
              isCheckedIn: isCheckedIn,
              isOnBreak: phase == ShiftPhase.onBreak,
              breakUsed: attendance.breakUsed,
              breakStartedAt:
                  attendance.snapshot?.breakStartedAt ??
                  DateTime.tryParse(
                    ((attendance.breakSummary?['break']
                                as Map<String, dynamic>?)?['startedAt'])
                            ?.toString() ??
                        '',
                  ),
              window: partnerBreak?.windowLabel,
              windowState: partnerBreak?.stateAt() ?? BreakWindowState.none,
              // The server's cap when it has answered, the partner's own
              // length until then. Never a literal.
              capMinutes:
                  (attendance.breakSummary?['capMinutes'] as num?)?.toInt() ??
                  partnerBreak?.durationMinutes,
              fallbackRemainingSeconds:
                  (attendance.breakSummary?['remainingSeconds'] as num?)
                      ?.toInt(),
              loading: attendance.loading,
              onToggle: () => _toggleBreak(context, ref),
            ),
          ],
          if (showsCheckInButton) ...[
            const SizedBox(height: XpertSpacing.md),
            // Off shift, checking in is the one thing this card is for, so it
            // keeps the full-width filled button.
            SizedBox(
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: canCheckIn
                      ? XpertColors.online
                      : XpertColors.border,
                  foregroundColor: canCheckIn
                      ? Colors.white
                      : XpertColors.onSurface.withValues(alpha: 0.5),
                  disabledBackgroundColor: XpertColors.border,
                  disabledForegroundColor: XpertColors.onSurface.withValues(
                    alpha: 0.5,
                  ),
                ),
                onPressed: (attendance.loading || !canCheckIn)
                    ? null
                    : () => _checkIn(context, ref),
                child: Text(checkInLabel),
              ),
            ),
          ] else if (isCheckedIn) ...[
            const SizedBox(height: XpertSpacing.md),
            if (blockedByJob)
              _JobLockNote(text: ref.t('home.on_job_note'))
            else
              // Checking out is the rarest thing a partner does all day and
              // the one that ends their availability. It sat under the clock
              // as a full-width red slab — the loudest control on the card,
              // and the easiest to hit by accident. It is still here, just no
              // longer shouting.
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: XpertColors.danger,
                    side: BorderSide(
                      color: XpertColors.danger.withValues(alpha: 0.35),
                    ),
                  ),
                  onPressed: attendance.loading
                      ? null
                      : () => _checkOut(context, ref),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: Text(ref.t('home.check_out')),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

const _cardDecoration = BoxDecoration(
  color: XpertColors.surface,
  borderRadius: BorderRadius.all(Radius.circular(XpertRadius.lg)),
  boxShadow: [
    BoxShadow(color: Color(0x0D0B1720), blurRadius: 18, offset: Offset(0, 6)),
  ],
);

/// Why the shift's buttons are gone. An empty space where a check-out button
/// used to be reads as a bug; a line saying what unlocks it does not.
class _JobLockNote extends StatelessWidget {
  const _JobLockNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: XpertSpacing.md,
        vertical: XpertSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: XpertColors.background,
        borderRadius: BorderRadius.circular(XpertRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_clock, size: 18, color: XpertColors.muted),
          const SizedBox(width: XpertSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: XpertTypography.caption.copyWith(color: XpertColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Status as one object rather than a loose dot beside loose text — it reads
/// as a state, and it survives being glanced at from a stairwell.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(XpertRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wall-clock time in the partner's own locale-independent short form. The
/// check-in window is a time of day, so it is written as one.
String _clock(DateTime at) => DateFormat('h:mm a').format(at.toLocal());
