/// Where the clock sits relative to a shift's scheduled break.
enum BreakWindowState { none, upcoming, now, passed }

/// Partner working-shift (DB-backed).
class PartnerShift {
  const PartnerShift({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.checkinBeforeMinutes = 15,
    this.checkinGraceMinutes = 15,
    this.checkoutGraceMinutes = 30,
    this.breakStartTime,
    this.breakDurationMinutes = 30,
    this.isActive = true,
  });

  final int id;
  final String name;

  /// `HH:mm` wall-clock start.
  final String startTime;

  /// `HH:mm` wall-clock end.
  final String endTime;
  final int checkinBeforeMinutes;
  final int checkinGraceMinutes;
  final int checkoutGraceMinutes;

  /// `HH:mm` when the scheduled break starts, or null for a shift that has
  /// none and leaves the partner to take one when the day allows.
  final String? breakStartTime;
  final int breakDurationMinutes;
  final bool isActive;

  bool get hasScheduledBreak =>
      breakStartTime != null && breakDurationMinutes > 0;

  /// `07:00 – 19:00`. The 12-hour [displayWindow] is for a line of its own;
  /// in a two-column strip it ellipsises, and it reads inconsistently beside
  /// a break window that has no room for AM/PM either.
  String get compactWindowLabel => '$startTime – $endTime';

  /// `12:00 – 12:30`, or null when there is no scheduled break.
  String? get breakWindowLabel {
    final start = breakStartTime;
    if (start == null || breakDurationMinutes <= 0) return null;
    final startMins = _minutesOfDay(start);
    if (startMins == null) return null;
    final endMins = (startMins + breakDurationMinutes) % 1440;
    return '${_hhmm(startMins)} – ${_hhmm(endMins)}';
  }

  static String _hhmm(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Where `now` sits relative to the break window.
  BreakWindowState breakStateAt([DateTime? now]) {
    final start = breakStartTime;
    if (start == null || breakDurationMinutes <= 0) {
      return BreakWindowState.none;
    }
    final startMins = _minutesOfDay(start);
    if (startMins == null) return BreakWindowState.none;

    final at = now ?? DateTime.now();
    // Measured from the window's start and wrapped, so an overnight shift
    // breaking at 01:00 is handled by the same arithmetic.
    final offset = (at.hour * 60 + at.minute - startMins + 1440) % 1440;
    if (offset < breakDurationMinutes) return BreakWindowState.now;
    return offset > 720 ? BreakWindowState.upcoming : BreakWindowState.passed;
  }

  factory PartnerShift.fromJson(Map<String, dynamic> json) {
    return PartnerShift(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ??
          (json['label'] as String?) ??
          'Shift',
      startTime: json['startTime'] as String? ?? '00:00',
      endTime: json['endTime'] as String? ?? '23:59',
      checkinBeforeMinutes:
          (json['checkinBeforeMinutes'] as num?)?.toInt() ?? 15,
      checkinGraceMinutes:
          (json['checkinGraceMinutes'] as num?)?.toInt() ?? 15,
      checkoutGraceMinutes:
          (json['checkoutGraceMinutes'] as num?)?.toInt() ?? 30,
      breakStartTime: (json['breakStartTime'] as String?)?.trim().isEmpty ?? true
          ? null
          : json['breakStartTime'] as String?,
      breakDurationMinutes:
          (json['breakDurationMinutes'] as num?)?.toInt() ?? 30,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  static int? _minutesOfDay(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  bool isWithinWorkingHours([DateTime? now]) {
    final at = now ?? DateTime.now();
    final start = _minutesOfDay(startTime);
    final end = _minutesOfDay(endTime);
    if (start == null || end == null) return false;

    final current = at.hour * 60 + at.minute;
    if (start == end) return true;
    if (start < end) {
      return current >= start && current <= end;
    }
    return current >= start || current <= end;
  }

  String get displayWindow {
    final start = _formatDisplay(startTime);
    final end = _formatDisplay(endTime);
    return '$start – $end';
  }

  String get label => name;

  static String _formatDisplay(String hhmm) {
    final minutes = _minutesOfDay(hhmm);
    if (minutes == null) return hhmm;
    final h24 = minutes ~/ 60;
    final m = minutes % 60;
    final period = h24 >= 12 ? 'PM' : 'AM';
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    final mm = m.toString().padLeft(2, '0');
    return '$h12:$mm $period';
  }
}
