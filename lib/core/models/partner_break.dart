/// Where the clock sits relative to a partner's break.
enum BreakWindowState { none, upcoming, now, passed }

/// A partner's own break. It belongs to the partner, not their shift: two
/// people on the same shift can break at different times.
class PartnerBreak {
  const PartnerBreak({this.startTime, required this.durationMinutes});

  /// `HH:mm` when the break starts, or null when it has no fixed time and the
  /// partner takes it when the day allows.
  final String? startTime;
  final int durationMinutes;

  bool get hasWindow => _startMinutes != null && durationMinutes > 0;

  int? get _startMinutes {
    final parts = startTime?.split(':');
    if (parts == null || parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  /// `12:00 – 12:30`, or null when there is no fixed time.
  String? get windowLabel {
    final start = _startMinutes;
    if (start == null || durationMinutes <= 0) return null;
    return '${_hhmm(start)} – ${_hhmm((start + durationMinutes) % 1440)}';
  }

  static String _hhmm(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Where `now` sits relative to the break window.
  BreakWindowState stateAt([DateTime? now]) {
    final start = _startMinutes;
    if (start == null || durationMinutes <= 0) return BreakWindowState.none;

    final at = now ?? DateTime.now();
    // Measured from the window's start and wrapped, so an overnight shift
    // breaking at 01:00 is handled by the same arithmetic.
    final offset = (at.hour * 60 + at.minute - start + 1440) % 1440;
    if (offset < durationMinutes) return BreakWindowState.now;
    return offset > 720 ? BreakWindowState.upcoming : BreakWindowState.passed;
  }

  /// Null when the server sent no break at all — an older backend, or a
  /// partner not yet approved.
  static PartnerBreak? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final minutes = (json['durationMinutes'] as num?)?.toInt();
    if (minutes == null) return null;
    final start = (json['startTime'] as String?)?.trim();
    return PartnerBreak(
      startTime: start == null || start.isEmpty ? null : start,
      durationMinutes: minutes,
    );
  }
}
