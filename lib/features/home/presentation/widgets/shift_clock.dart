import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/xpert_tokens.dart';

/// How long this shift has been running, ticking.
///
/// The old home screen could tell a partner they were checked in but not for
/// how long — the only live number on the screen was the break countdown. This
/// is the one thing a shift worker actually watches, so it gets the largest
/// type in the card.
class ShiftClock extends StatefulWidget {
  const ShiftClock({super.key, required this.startedAt});

  final DateTime startedAt;

  @override
  State<ShiftClock> createState() => _ShiftClockState();
}

class _ShiftClockState extends State<ShiftClock> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.startedAt);
    // A clock that has run backwards is a clock skew, not a negative shift.
    final safe = elapsed.isNegative ? Duration.zero : elapsed;

    final hours = safe.inHours.toString().padLeft(2, '0');
    final minutes = (safe.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (safe.inSeconds % 60).toString().padLeft(2, '0');

    return Text(
      '$hours:$minutes:$seconds',
      style: XpertTypography.metric.copyWith(fontSize: 26),
    );
  }
}
