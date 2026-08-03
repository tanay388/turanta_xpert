/// Formats a [Duration] as `H:MM:SS` or `MM:SS`.
String formatJobClock(Duration d) {
  final total = d.isNegative ? Duration.zero : d;
  final h = total.inHours;
  final m = total.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = total.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) return '$h:$m:$s';
  return '$m:$s';
}

/// Live-job clock start.
///
/// Always prefers [startedAt] (partner may start early once assigned).
/// Does **not** fall back to the booked slot.
DateTime jobLiveStart({
  required DateTime? startedAt,
  DateTime? scheduledEnd,
  required Duration duration,
  required DateTime now,
}) {
  if (startedAt != null) return startedAt;
  if (scheduledEnd != null && duration > Duration.zero) {
    return scheduledEnd.subtract(duration);
  }
  return now;
}

/// End = actual start + booked duration (early starts still get the full hour).
DateTime jobLiveEnd({
  required DateTime start,
  required Duration duration,
  DateTime? scheduledEnd,
}) {
  if (duration > Duration.zero) return start.add(duration);
  return scheduledEnd ?? start;
}

Duration jobTimeRemaining(DateTime end, [DateTime? now]) {
  final left = end.difference(now ?? DateTime.now());
  return left.isNegative ? Duration.zero : left;
}

Duration jobTimeElapsed(DateTime start, [DateTime? now]) {
  final elapsed = (now ?? DateTime.now()).difference(start);
  return elapsed.isNegative ? Duration.zero : elapsed;
}

bool jobIsOvertime(DateTime end, [DateTime? now]) {
  return (now ?? DateTime.now()).isAfter(end);
}

/// Compact elapsed/duration label: `1h 14m`, `48m`, `< 1m`.
///
/// Not [formatJobClock] — that is the ticking hero clock and needs its seconds.
/// This is the quiet counterpart beside it, where seconds are noise.
String formatJobDurationShort(Duration d) {
  final total = d.isNegative ? Duration.zero : d;
  final h = total.inHours;
  final m = total.inMinutes.remainder(60);
  if (h > 0) return m > 0 ? '${h}h ${m}m' : '${h}h';
  if (m > 0) return '${m}m';
  return '< 1m';
}
