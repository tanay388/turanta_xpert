// Data models for the Paisa (earnings / payouts) tab.

/// Parses a server ISO datetime as UTC-aware, converting to device local time.
///
/// Nest/TypeORM sometimes emit UTC without a `Z` suffix; Dart would otherwise
/// treat those as local and shift the clock by the timezone offset.
DateTime? _parseServerDate(dynamic raw) {
  if (raw == null) return null;
  var s = raw.toString().trim();
  if (s.isEmpty) return null;
  final hasTz = s.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(s);
  if (!hasTz) s = '${s}Z';
  return DateTime.tryParse(s)?.toLocal();
}

enum PayoutStatus { accruing, pending, paid }

PayoutStatus _statusFromString(String? raw) {
  switch (raw) {
    case 'PENDING':
      return PayoutStatus.pending;
    case 'PAID':
      return PayoutStatus.paid;
    case 'ACCRUING':
    default:
      return PayoutStatus.accruing;
  }
}

/// Current rating band → rate/hour context.
class RateBand {
  const RateBand({required this.label, required this.ratePerHour});
  final String label;
  final double ratePerHour;

  factory RateBand.fromJson(Map<String, dynamic> json) {
    return RateBand(
      label: (json['label'] as String?) ?? '',
      ratePerHour: (json['ratePerHour'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Top-of-tab summary: current cycle total + rate band + rating.
class EarningSummary {
  const EarningSummary({
    this.periodStart,
    this.periodEnd,
    this.totalAmount = 0,
    this.status = PayoutStatus.accruing,
    this.ratePerHour = 0,
    this.band,
    this.rating,
  });

  final DateTime? periodStart;
  final DateTime? periodEnd;
  final double totalAmount;
  final PayoutStatus status;
  final double ratePerHour;
  final RateBand? band;
  final double? rating;

  factory EarningSummary.fromJson(Map<String, dynamic> json) {
    final cycle = json['currentCycle'] as Map<String, dynamic>? ?? const {};
    final bandJson = json['band'];
    return EarningSummary(
      periodStart: _parseServerDate(cycle['periodStart']),
      periodEnd: _parseServerDate(cycle['periodEnd']),
      totalAmount: (cycle['totalAmount'] as num?)?.toDouble() ?? 0,
      status: _statusFromString(cycle['status'] as String?),
      ratePerHour: (json['ratePerHour'] as num?)?.toDouble() ?? 0,
      band: bandJson is Map<String, dynamic>
          ? RateBand.fromJson(bandJson)
          : null,
      rating: (json['rating'] as num?)?.toDouble(),
    );
  }
}

/// One payout window row.
class PayoutCycle {
  const PayoutCycle({
    required this.id,
    this.periodStart,
    this.periodEnd,
    this.totalAmount = 0,
    this.status = PayoutStatus.accruing,
    this.paidAt,
  });

  final int id;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final double totalAmount;
  final PayoutStatus status;
  final DateTime? paidAt;

  factory PayoutCycle.fromJson(Map<String, dynamic> json) {
    return PayoutCycle(
      id: (json['id'] as num).toInt(),
      periodStart: _parseServerDate(json['periodStart']),
      periodEnd: _parseServerDate(json['periodEnd']),
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      status: _statusFromString(json['status'] as String?),
      paidAt: _parseServerDate(json['paidAt']),
    );
  }
}

/// A single job's earning line inside a cycle breakdown.
class EarningLineItem {
  const EarningLineItem({
    required this.bookingId,
    this.serviceName,
    this.ratePerHour = 0,
    this.hours = 0,
    this.amount = 0,
    this.earnedAt,
  });

  final int bookingId;
  final String? serviceName;
  final double ratePerHour;
  final double hours;
  final double amount;
  final DateTime? earnedAt;

  factory EarningLineItem.fromJson(Map<String, dynamic> json) {
    return EarningLineItem(
      bookingId: (json['bookingId'] as num?)?.toInt() ?? 0,
      serviceName: json['serviceName'] as String?,
      ratePerHour: (json['ratePerHour'] as num?)?.toDouble() ?? 0,
      hours: (json['hours'] as num?)?.toDouble() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      earnedAt: _parseServerDate(json['earnedAt']),
    );
  }
}

/// A cycle plus its per-job breakdown.
class PayoutCycleDetail {
  const PayoutCycleDetail({
    required this.cycle,
    this.items = const [],
  });

  final PayoutCycle cycle;
  final List<EarningLineItem> items;

  factory PayoutCycleDetail.fromJson(Map<String, dynamic> json) {
    return PayoutCycleDetail(
      cycle: PayoutCycle.fromJson(json),
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((e) => EarningLineItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
