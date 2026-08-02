import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/i18n/context_t.dart';
import '../../../../core/theme/xpert_tokens.dart';

/// The break affordance, in its three states: offer, running, spent.
///
/// Moved out of home_screen.dart unchanged — it owns a ticker and a fallback
/// countdown, and that logic has nothing to do with laying out a home screen.
class BreakControl extends ConsumerStatefulWidget {
  const BreakControl({
    super.key,
    required this.isOnBreak,
    required this.breakUsed,
    required this.breakStartedAt,
    required this.capMinutes,
    required this.fallbackRemainingSeconds,
    required this.loading,
    required this.onToggle,
  });

  final bool isOnBreak;
  final bool breakUsed;
  final DateTime? breakStartedAt;
  final int capMinutes;
  final int? fallbackRemainingSeconds;
  final bool loading;
  final VoidCallback onToggle;

  @override
  ConsumerState<BreakControl> createState() => _BreakControlState();
}

class _BreakControlState extends ConsumerState<BreakControl> {
  static const _breakColor = Color(0xFFE65100);
  static const _breakBg = Color(0xFFFFF3E0);
  static const _breakBorder = Color(0xFFFFB74D);

  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant BreakControl old) {
    super.didUpdateWidget(old);
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncTicker() {
    if (widget.isOnBreak) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  /// Resolves the moment the break should end, so we can tick down locally.
  DateTime? get _endsAt {
    if (widget.breakStartedAt != null) {
      return widget.breakStartedAt!.add(Duration(minutes: widget.capMinutes));
    }
    if (widget.fallbackRemainingSeconds != null) {
      // No start time available: count down from first build.
      _fallbackEnd ??= DateTime.now()
          .add(Duration(seconds: widget.fallbackRemainingSeconds!));
      return _fallbackEnd;
    }
    return null;
  }

  DateTime? _fallbackEnd;

  String _format(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isOnBreak = widget.isOnBreak;
    final breakUsed = widget.breakUsed;
    final loading = widget.loading;
    final onToggle = widget.onToggle;

    // Active break: prominent card with live countdown + End break button.
    if (isOnBreak) {
      final endsAt = _endsAt;
      final remaining = endsAt?.difference(DateTime.now());
      final overrun = remaining != null && remaining.isNegative;
      final remainingText = remaining == null
          ? ref.t('home.break_running')
          : overrun
              ? ref.t('home.break_overrun',
                  {'time': _format(remaining.abs())})
              : ref.t('home.break_remaining', {
                  'time': _format(remaining),
                  'cap': '${widget.capMinutes}',
                });
      final accent = overrun ? XpertColors.danger : _breakColor;
      return Container(
        padding: const EdgeInsets.all(XpertSpacing.md),
        decoration: BoxDecoration(
          color: overrun
              ? XpertColors.danger.withValues(alpha: 0.08)
              : _breakBg,
          borderRadius: BorderRadius.circular(XpertRadius.md),
          border: Border.all(
              color: overrun
                  ? XpertColors.danger.withValues(alpha: 0.5)
                  : _breakBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.free_breakfast_rounded, color: accent),
                const SizedBox(width: XpertSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        overrun
                            ? ref.t('home.break_over_title')
                            : ref.t('home.break_on_title'),
                        style: XpertTypography.label.copyWith(
                          color: accent,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        remainingText,
                        style: XpertTypography.caption.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: XpertSpacing.md),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
              ),
              onPressed: loading ? null : onToggle,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(ref.t('home.break_end')),
            ),
          ],
        ),
      );
    }

    // Already used today: subtle disabled note.
    if (breakUsed) {
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
            Icon(Icons.check_circle_outline_rounded,
                size: 18, color: XpertColors.muted),
            const SizedBox(width: XpertSpacing.sm),
            Expanded(
              child: Text(
                ref.t('home.break_used'),
                style: XpertTypography.caption.copyWith(color: XpertColors.muted),
              ),
            ),
          ],
        ),
      );
    }

    // Available: clear call to action with icon + hint.
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: _breakColor,
        side: const BorderSide(color: _breakBorder),
        padding: const EdgeInsets.symmetric(vertical: XpertSpacing.sm + 2),
      ),
      onPressed: loading ? null : onToggle,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.free_breakfast_rounded, size: 20),
          const SizedBox(width: XpertSpacing.sm),
          // Flexible, not bare: a Row hands its children unbounded width, so
          // the longer Hindi and Marathi strings ran straight off the button.
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ref.t('home.break_take_title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: XpertTypography.label.copyWith(
                    color: _breakColor,
                    fontSize: 15,
                  ),
                ),
                Text(
                  ref.t('home.break_take_hint'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: XpertTypography.caption.copyWith(
                    color: _breakColor.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
