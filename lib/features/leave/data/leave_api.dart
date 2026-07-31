import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/dio_client.dart';

class LeaveRequestItem {
  const LeaveRequestItem({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.daysCount,
    required this.status,
    this.leaveType = 'PAID',
    this.reason,
    this.reviewedByName,
    this.reviewNote,
  });

  final int id;
  final String startDate;
  final String endDate;
  final int daysCount;
  final String status;
  final String leaveType;
  final String? reason;
  final String? reviewedByName;
  final String? reviewNote;

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';
  bool get isCancelled => status == 'CANCELLED';
  bool get isUnpaid => leaveType == 'UNPAID';

  factory LeaveRequestItem.fromJson(Map<String, dynamic> json) {
    return LeaveRequestItem(
      id: (json['id'] as num).toInt(),
      startDate: json['startDate'] as String? ?? '',
      endDate: json['endDate'] as String? ?? '',
      daysCount: (json['daysCount'] as num?)?.toInt() ?? 1,
      status: json['status'] as String? ?? 'PENDING',
      leaveType: json['leaveType'] as String? ?? 'PAID',
      reason: json['reason'] as String?,
      reviewedByName: json['reviewedByName'] as String?,
      reviewNote: json['reviewNote'] as String?,
    );
  }
}

class LeaveSummary {
  const LeaveSummary({
    required this.balanceDays,
    required this.pendingDays,
    required this.availableDays,
    required this.lapsedDaysTotal,
    required this.lastLapsedDays,
    required this.canApplyPaid,
    required this.canApplyUnpaid,
    required this.maxUnpaidDays,
    required this.maxAdvanceDays,
    required this.today,
    required this.maxDate,
    required this.requests,
  });

  final int balanceDays;
  final int pendingDays;
  final int availableDays;
  final int lapsedDaysTotal;
  final int lastLapsedDays;
  final bool canApplyPaid;
  final bool canApplyUnpaid;
  final int maxUnpaidDays;
  final int maxAdvanceDays;
  final String today;
  final String maxDate;
  final List<LeaveRequestItem> requests;

  bool get canApply => canApplyPaid || canApplyUnpaid;

  factory LeaveSummary.fromJson(Map<String, dynamic> json) {
    final list = json['requests'] as List<dynamic>? ?? const [];
    final available = (json['availableDays'] as num?)?.toInt() ?? 0;
    return LeaveSummary(
      balanceDays: (json['balanceDays'] as num?)?.toInt() ?? 0,
      pendingDays: (json['pendingDays'] as num?)?.toInt() ?? 0,
      availableDays: available,
      lapsedDaysTotal: (json['lapsedDaysTotal'] as num?)?.toInt() ?? 0,
      lastLapsedDays: (json['lastLapsedDays'] as num?)?.toInt() ?? 0,
      canApplyPaid: json['canApplyPaid'] as bool? ?? available > 0,
      canApplyUnpaid: json['canApplyUnpaid'] as bool? ?? available == 0,
      maxUnpaidDays: (json['maxUnpaidDays'] as num?)?.toInt() ?? 15,
      maxAdvanceDays: (json['maxAdvanceDays'] as num?)?.toInt() ?? 30,
      today: json['today'] as String? ?? '',
      maxDate: json['maxDate'] as String? ?? '',
      requests: list
          .map((e) => LeaveRequestItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class LeaveApi {
  LeaveApi(this._dio);

  final Dio _dio;

  Future<LeaveSummary> getSummary() async {
    final res = await _dio.get<Map<String, dynamic>>('/leave/summary');
    return LeaveSummary.fromJson(res.data ?? const {});
  }

  Future<void> apply({
    required String startDate,
    required String endDate,
    String? reason,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/leave/apply',
      data: {
        'startDate': startDate,
        'endDate': endDate,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }

  Future<void> cancel(int id) async {
    await _dio.post<Map<String, dynamic>>('/leave/$id/cancel');
  }
}

final leaveApiProvider = Provider<LeaveApi>(
  (ref) => LeaveApi(ref.watch(dioProvider)),
);
