import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/context_t.dart';
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
  const ShiftCard({super.key, required this.attendance});

  final AttendanceState attendance;

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
    final hours = attendance.currentShift?.shift.displayWindow ?? '—';
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

    return Container(
      padding: const EdgeInsets.all(XpertSpacing.lg),
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
        border: Border.all(color: XpertColors.border.withValues(alpha: 0.45)),
        boxShadow: [
          // Tinted to the page behind it rather than a grey wash, so the hero
          // lifts without looking like it is floating in smoke.
          BoxShadow(
            color: XpertColors.canvas.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Flexible, because "Account inactive" in Marathi plus the date
              // does not fit a 360pt row.
              Flexible(
                child: _StatusPill(color: statusColor, label: statusLabel),
              ),
              const SizedBox(width: XpertSpacing.sm),
              const Spacer(),
              if (attendance.loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                // Today's date belongs to the shift, not to the greeting — it
                // is what this card is a record of.
                Text(
                  DateFormat('EEE, d MMM').format(DateTime.now()),
                  style: XpertTypography.caption.copyWith(fontSize: 12),
                ),
            ],
          ),
          // The clock is the reward for being on shift, so it gets the space.
          if (isCheckedIn && startedAt != null) ...[
            const SizedBox(height: XpertSpacing.md),
            ShiftClock(startedAt: startedAt),
          ],
          const SizedBox(height: XpertSpacing.sm),
          Text(subtitle, style: XpertTypography.caption),
          // A finished day gets no button, so it gets no gap under the text
          // either — the card just stops.
          if (showsCheckInButton || isCheckedIn)
            const SizedBox(height: XpertSpacing.lg),
          if (showsCheckInButton)
            FilledButton(
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
            )
          else if (isCheckedIn) ...[
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: XpertColors.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: attendance.loading
                  ? null
                  : () => _checkOut(context, ref),
              child: Text(ref.t('home.check_out')),
            ),
            const SizedBox(height: XpertSpacing.md),
            BreakControl(
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
              capMinutes:
                  (attendance.breakSummary?['capMinutes'] as num?)?.toInt() ??
                  45,
              fallbackRemainingSeconds:
                  (attendance.breakSummary?['remainingSeconds'] as num?)
                      ?.toInt(),
              loading: attendance.loading,
              onToggle: () => _toggleBreak(context, ref),
            ),
          ],
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
