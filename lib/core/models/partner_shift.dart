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
  final bool isActive;

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
