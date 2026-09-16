import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/i18n/context_t.dart';
import '../../../../core/models/partner_break.dart';
import '../../../../core/theme/xpert_tokens.dart';

/// The break, as one row.
///
/// It used to be a full-width button stacked under a full-width check-out
/// button, so a partner mid-shift faced two slabs of colour where one line of
/// information would do. Every state now fits the same row: what the break is
/// and, only when it can actually be started or ended, a small button at the
/// end of it.
class BreakControl extends ConsumerStatefulWidget {
  const BreakControl({
    super.key,
    required this.isCheckedIn,
    required this.isOnBreak,
    required this.breakUsed,
    required this.breakStartedAt,
    required this.capMinutes,
    required this.fallbackRemainingSeconds,
    required this.loading,
    required this.onToggle,
    this.window,
    this.windowState = BreakWindowState.none,
  });

  final bool isCheckedIn;
  final bool isOnBreak;
  final bool breakUsed;
  final DateTime? breakStartedAt;

  /// How long the break runs, from the partner's own break or the server.
  /// Null only until either has answered — there is no number of minutes
  /// baked into this widget.
  final int? capMinutes;
  final int? fallbackRemainingSeconds;
  final bool loading;
  final VoidCallback onToggle;

  /// `12:00 – 12:30` when the partner's break has a fixed time, else null.
  final String? window;
  final BreakWindowState windowState;

  @override
  ConsumerState<BreakControl> createState() => _BreakControlState();
}

class _BreakControlState extends ConsumerState<BreakControl> {
  static const _breakColor = Color(0xFFD35400);

  Timer? _ticker;
  DateTime? _fallbackEnd;

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
      _fallbackEnd = null;
    }
  }

  /// Resolves the moment the break should end, so we can tick down locally.
  DateTime? get _endsAt {
    final cap = widget.capMinutes;
    if (widget.breakStartedAt != null && cap != null && cap > 0) {
      return widget.breakStartedAt!.add(Duration(minutes: cap));
    }
    if (widget.fallbackRemainingSeconds != null) {
      // No start time available: count down from first build.
      _fallbackEnd ??= DateTime.now().add(
        Duration(seconds: widget.fallbackRemainingSeconds!),
      );
      return _fallbackEnd;
    }
    return null;
  }

  String _format(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final window = widget.window;

    if (widget.isOnBreak) {
      final remaining = _endsAt?.difference(DateTime.now());
      final overrun = remaining != null && remaining.isNegative;
      final accent = overrun ? XpertColors.danger : _breakColor;
      final detail = remaining == null
          ? (widget.capMinutes == null
                ? null
                : ref.t('home.break_running', {
                    'minutes': '${widget.capMinutes}',
                  }))
          : overrun
          ? ref.t('home.break_overrun', {'time': _format(remaining.abs())})
          : ref.t('home.break_remaining', {
              'time': _format(remaining),
              'cap': '${widget.capMinutes}',
            });

      return _Row(
        tint: accent,
        icon: Icons.free_breakfast_rounded,
        iconColor: accent,
        title: overrun
            ? ref.t('home.break_over_title')
            : ref.t('home.break_on_title'),
        titleColor: accent,
        detail: detail,
        detailColor: accent,
        tabular: true,
        action: _SmallButton(
          label: ref.t('home.break_end'),
          color: accent,
          filled: true,
          onPressed: widget.loading ? null : widget.onToggle,
        ),
      );
    }

    if (widget.breakUsed) {
      return _Row(
        icon: Icons.check_circle_rounded,
        iconColor: XpertColors.success,
        title: ref.t('home.break_used'),
      );
    }

    // Off shift the row is information: when the break will be. There is
    // nothing to start until the partner has checked in.
    if (!widget.isCheckedIn) {
      if (window == null) return const SizedBox.shrink();
      return _Row(
        icon: Icons.free_breakfast_rounded,
        iconColor: XpertColors.muted,
        title: ref.t('home.break_label'),
        detail: window,
      );
    }

    // A break with a fixed time is not offered all shift. Outside its window
    // the row says when instead — which is also the answer to "when is my
    // break?".
    if (widget.windowState == BreakWindowState.upcoming) {
      return _Row(
        icon: Icons.free_breakfast_rounded,
        iconColor: XpertColors.muted,
        title: ref.t('home.break_label'),
        detail: window,
      );
    }
    if (widget.windowState == BreakWindowState.passed) {
      return _Row(
        icon: Icons.schedule_rounded,
        iconColor: XpertColors.muted,
        title: ref.t('home.break_window_over'),
        detail: window,
      );
    }

    // Break window is open now, or the break has no fixed time at all.
    final open = widget.windowState == BreakWindowState.now;
    return _Row(
      tint: open ? _breakColor : null,
      icon: Icons.free_breakfast_rounded,
      iconColor: open ? _breakColor : XpertColors.muted,
      title: open ? ref.t('home.strip.break_now') : ref.t('home.break_label'),
      titleColor: open ? _breakColor : null,
      detail: window,
      action: _SmallButton(
        label: ref.t('home.break_take_title'),
        color: _breakColor,
        filled: false,
        onPressed: widget.loading ? null : widget.onToggle,
      ),
    );
  }
}

/// The single shape every break state takes.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.titleColor,
    this.detail,
    this.detailColor,
    this.tint,
    this.tabular = false,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Color? titleColor;
  final String? detail;
  final Color? detailColor;

  /// A faint wash of this colour behind the row, for the states that are live.
  final Color? tint;
  final bool tabular;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        XpertSpacing.sm + 2,
        XpertSpacing.xs,
        action == null ? XpertSpacing.sm + 2 : XpertSpacing.xs,
        XpertSpacing.xs,
      ),
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        color: tint?.withValues(alpha: 0.08) ?? XpertColors.background,
        borderRadius: BorderRadius.circular(XpertRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: XpertSpacing.sm),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: titleColor ?? XpertColors.onSurface,
                  ),
                ),
                if (detail != null)
                  Text(
                    detail!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                      color: detailColor ?? XpertColors.muted,
                      fontFeatures: tabular
                          ? const [FontFeature.tabularFigures()]
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: XpertSpacing.sm),
            Flexible(child: action!),
          ],
        ],
      ),
    );
  }
}

/// A button sized to the row it sits in, not to the card.
class _SmallButton extends StatelessWidget {
  const _SmallButton({
    required this.label,
    required this.color,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final bool filled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(XpertRadius.pill),
    );
    const padding = EdgeInsets.symmetric(horizontal: 14);
    const size = Size(0, 34);
    // Set on the style, not only on the Text: the app theme gives every button
    // its full-size label style, which otherwise still sizes this one.
    const textStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w700);
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textStyle,
    );

    return filled
        ? FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: padding,
              minimumSize: size,
              textStyle: textStyle,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: shape,
            ),
            child: text,
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color.withValues(alpha: 0.6)),
              backgroundColor: XpertColors.surface,
              padding: padding,
              minimumSize: size,
              textStyle: textStyle,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: shape,
            ),
            child: text,
          );
  }
}
