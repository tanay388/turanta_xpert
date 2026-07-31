import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/dio_client.dart';
import 'earning_models.dart';

/// Read API for the Paisa (earnings / payouts) tab.
///
/// Mirrors the partner earning endpoints:
/// - `GET /partner/earning/summary`
/// - `GET /partner/earning/cycles`
/// - `GET /partner/earning/cycles/:id`
class EarningApi {
  EarningApi(this._dio);
  final Dio _dio;

  Future<EarningSummary> summary() async {
    final res =
        await _dio.get<Map<String, dynamic>>('/partner/earning/summary');
    return EarningSummary.fromJson(res.data ?? const {});
  }

  Future<List<PayoutCycle>> cycles() async {
    final res =
        await _dio.get<Map<String, dynamic>>('/partner/earning/cycles');
    final items = res.data?['items'] as List<dynamic>? ?? const [];
    return items
        .map((e) => PayoutCycle.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PayoutCycleDetail> cycleDetail(int id) async {
    final res =
        await _dio.get<Map<String, dynamic>>('/partner/earning/cycles/$id');
    return PayoutCycleDetail.fromJson(res.data ?? const {});
  }
}

final earningApiProvider = Provider<EarningApi>((ref) {
  return EarningApi(ref.watch(dioProvider));
});

/// Current-cycle payout + rate band shown at the top of the Paisa tab.
final earningSummaryProvider = FutureProvider<EarningSummary>((ref) async {
  return ref.watch(earningApiProvider).summary();
});

/// Previous + current payout cycles.
final payoutCyclesProvider = FutureProvider<List<PayoutCycle>>((ref) async {
  return ref.watch(earningApiProvider).cycles();
});

/// Per-job breakdown for one cycle (used by the payout detail screen).
final payoutCycleDetailProvider =
    FutureProvider.family<PayoutCycleDetail, int>((ref, id) async {
  return ref.watch(earningApiProvider).cycleDetail(id);
});
