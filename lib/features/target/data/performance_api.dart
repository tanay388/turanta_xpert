import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/dio_client.dart';

/// A rate band in the earning ladder.
class RateLadderBand {
  const RateLadderBand({
    required this.label,
    required this.minRating,
    required this.maxRating,
    required this.ratePerHour,
    this.current = false,
  });

  final String label;
  final double minRating;
  final double maxRating;
  final double ratePerHour;
  final bool current;

  factory RateLadderBand.fromJson(Map<String, dynamic> json) {
    return RateLadderBand(
      label: (json['label'] as String?) ?? '',
      minRating: (json['minRating'] as num?)?.toDouble() ?? 0,
      maxRating: (json['maxRating'] as num?)?.toDouble() ?? 0,
      ratePerHour: (json['ratePerHour'] as num?)?.toDouble() ?? 0,
      current: json['current'] as bool? ?? false,
    );
  }
}

/// A performance metric with its target and pass/fail state.
class PerformanceMetric {
  const PerformanceMetric({
    required this.value,
    required this.threshold,
    required this.ok,
  });

  final double? value;
  final double threshold;
  final bool ok;

  factory PerformanceMetric.fromJson(Map<String, dynamic> json) {
    return PerformanceMetric(
      value: (json['value'] as num?)?.toDouble(),
      threshold: (json['threshold'] as num?)?.toDouble() ?? 0,
      ok: json['ok'] as bool? ?? true,
    );
  }
}

class PartnerPerformance {
  const PartnerPerformance({
    this.rating,
    this.ratingCount = 0,
    this.currentRatePerHour,
    this.currentBandLabel,
    this.ladder = const [],
    required this.ratingMetric,
    required this.unavailableMetric,
    required this.cancellationsMetric,
    required this.lateShowMetric,
  });

  final double? rating;
  final int ratingCount;
  final double? currentRatePerHour;
  final String? currentBandLabel;
  final List<RateLadderBand> ladder;

  final PerformanceMetric ratingMetric;
  final PerformanceMetric unavailableMetric;
  final PerformanceMetric cancellationsMetric;
  final PerformanceMetric lateShowMetric;

  /// The next band up from the current one (null if already at the top).
  RateLadderBand? get nextBand {
    final idx = ladder.indexWhere((b) => b.current);
    if (idx < 0 || idx + 1 >= ladder.length) return null;
    return ladder[idx + 1];
  }

  factory PartnerPerformance.fromJson(Map<String, dynamic> json) {
    final ratingJson = json['rating'] as Map<String, dynamic>? ?? const {};
    final band = json['currentRateBand'] as Map<String, dynamic>?;
    final metrics = json['metrics'] as Map<String, dynamic>? ?? const {};
    PerformanceMetric metric(String key) => PerformanceMetric.fromJson(
          metrics[key] as Map<String, dynamic>? ?? const {},
        );
    return PartnerPerformance(
      rating: (ratingJson['value'] as num?)?.toDouble(),
      ratingCount: (ratingJson['count'] as num?)?.toInt() ?? 0,
      currentRatePerHour: (band?['ratePerHour'] as num?)?.toDouble(),
      currentBandLabel: band?['label'] as String?,
      ladder: (json['ladder'] as List<dynamic>? ?? const [])
          .map((e) => RateLadderBand.fromJson(e as Map<String, dynamic>))
          .toList(),
      ratingMetric: metric('rating'),
      unavailableMetric: metric('unavailableDays'),
      cancellationsMetric: metric('cancellations'),
      lateShowMetric: metric('lateShow'),
    );
  }
}

class PerformanceApi {
  PerformanceApi(this._dio);
  final Dio _dio;

  Future<PartnerPerformance> get() async {
    final res =
        await _dio.get<Map<String, dynamic>>('/partner/performance');
    return PartnerPerformance.fromJson(res.data ?? const {});
  }
}

final performanceApiProvider = Provider<PerformanceApi>((ref) {
  return PerformanceApi(ref.watch(dioProvider));
});

final performanceProvider = FutureProvider<PartnerPerformance>((ref) async {
  return ref.watch(performanceApiProvider).get();
});
