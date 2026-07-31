import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/dio_client.dart';

/// Home dashboard "today" stats for the logged-in partner.
///
/// Shape mirrors `GET /partner/summary/today`. `earnings` stays 0 until the
/// earning engine (roadmap 04) and `rating` stays null until customer ratings
/// (roadmap 03) land — only the values change, not the keys.
class TodaySummary {
  const TodaySummary({
    this.jobsDone = 0,
    this.hoursWorked = 0,
    this.earnings = 0,
    this.rating,
  });

  final int jobsDone;
  final double hoursWorked;
  final double earnings;
  final double? rating;

  factory TodaySummary.fromJson(Map<String, dynamic> json) {
    return TodaySummary(
      jobsDone: (json['jobsDoneToday'] as num?)?.toInt() ?? 0,
      hoursWorked: (json['hoursWorkedToday'] as num?)?.toDouble() ?? 0,
      earnings: (json['earningsToday'] as num?)?.toDouble() ?? 0,
      rating: (json['rating'] as num?)?.toDouble(),
    );
  }
}

class SummaryApi {
  SummaryApi(this._dio);
  final Dio _dio;

  Future<TodaySummary> today() async {
    final res =
        await _dio.get<Map<String, dynamic>>('/partner/summary/today');
    return TodaySummary.fromJson(res.data ?? const {});
  }
}

final summaryApiProvider = Provider<SummaryApi>((ref) {
  return SummaryApi(ref.watch(dioProvider));
});

/// Async today-stats for the Check-in home tab. Auto-refreshes when invalidated.
final todaySummaryProvider = FutureProvider<TodaySummary>((ref) async {
  return ref.watch(summaryApiProvider).today();
});
