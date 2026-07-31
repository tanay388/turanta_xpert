import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/dio_client.dart';

class PartnerJobAddress {
  const PartnerJobAddress({
    this.name,
    this.phoneNumber,
    this.flat,
    this.floor,
    this.address,
    this.city,
    this.state,
    this.country,
    this.latitude,
    this.longitude,
  });

  final String? name;
  final String? phoneNumber;
  final String? flat;
  final String? floor;
  final String? address;
  final String? city;
  final String? state;
  final String? country;
  final double? latitude;
  final double? longitude;

  factory PartnerJobAddress.fromJson(Map<String, dynamic> json) {
    return PartnerJobAddress(
      name: json['name'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      flat: json['flat'] as String?,
      floor: json['floor'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      country: json['country'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  /// Multi-line address for job cards / detail.
  List<String> get lines {
    final line1 = [
      if ((flat ?? '').trim().isNotEmpty) flat!.trim(),
      if ((floor ?? '').trim().isNotEmpty) 'Floor ${floor!.trim()}',
      if ((address ?? '').trim().isNotEmpty) address!.trim(),
    ].join(', ');

    final line2 = [
      if ((city ?? '').trim().isNotEmpty) city!.trim(),
      if ((state ?? '').trim().isNotEmpty) state!.trim(),
    ].join(', ');

    return [
      if (line1.isNotEmpty) line1,
      if (line2.isNotEmpty) line2,
      if ((country ?? '').trim().isNotEmpty) country!.trim(),
    ];
  }
}

class PartnerJob {
  const PartnerJob({
    required this.id,
    required this.status,
    required this.scheduledStartAt,
    required this.scheduledEndAt,
    required this.durationMinutes,
    this.assignedAt,
    this.startedAt,
    this.serviceName,
    this.serviceCategoryName,
    this.serviceImageUrl,
    this.addressLabel,
    this.serviceAddress,
    this.latitude,
    this.longitude,
    this.customerPhone,
    this.customerName,
    this.warehouseName,
    this.totalAmount,
    this.partnerEarning,
    this.reviewStars,
    this.reviewNote,
    this.reviewTags = const [],
  });

  final int id;
  final String status;
  final DateTime scheduledStartAt;
  final DateTime scheduledEndAt;
  final int durationMinutes;
  final DateTime? assignedAt;
  final DateTime? startedAt;
  final String? serviceName;
  final String? serviceCategoryName;
  final String? serviceImageUrl;
  final String? addressLabel;
  final PartnerJobAddress? serviceAddress;
  final double? latitude;
  final double? longitude;
  final String? customerPhone;
  final String? customerName;
  final String? warehouseName;
  final double? totalAmount;

  /// Best-effort per-job earning (rate/hour × hours). Authoritative in plan 04.
  final double? partnerEarning;

  /// Customer stars for this job (null if not rated yet).
  final int? reviewStars;
  final String? reviewNote;
  final List<String> reviewTags;

  bool get isAssigned => status == 'ASSIGNED';
  bool get isInProgress => status == 'IN_PROGRESS';
  bool get isCompleted => status == 'COMPLETED';
  bool get isNoShow => status == 'NO_SHOW';
  bool get hasReview => reviewStars != null;

  String get displayAddress {
    final fromStruct = serviceAddress?.lines.join('\n');
    if (fromStruct != null && fromStruct.trim().isNotEmpty) return fromStruct;
    return (addressLabel ?? '').trim();
  }

  factory PartnerJob.fromJson(Map<String, dynamic> json) {
    final addrJson = json['serviceAddress'];
    final review = json['review'];
    return PartnerJob(
      id: (json['id'] as num).toInt(),
      status: json['status'] as String? ?? 'ASSIGNED',
      scheduledStartAt: DateTime.parse(json['scheduledStartAt'] as String),
      scheduledEndAt: DateTime.parse(json['scheduledEndAt'] as String),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 60,
      assignedAt: json['assignedAt'] != null
          ? DateTime.tryParse(json['assignedAt'] as String)
          : null,
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'] as String)
          : null,
      serviceName: json['serviceName'] as String?,
      serviceCategoryName: json['serviceCategoryName'] as String?,
      serviceImageUrl: json['serviceImageUrl'] as String?,
      addressLabel: json['addressLabel'] as String?,
      serviceAddress: addrJson is Map<String, dynamic>
          ? PartnerJobAddress.fromJson(addrJson)
          : null,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      customerPhone: json['customerPhone'] as String?,
      customerName: json['customerName'] as String?,
      warehouseName: json['warehouseName'] as String?,
      totalAmount: (json['totalAmount'] as num?)?.toDouble(),
      partnerEarning: (json['partnerEarning'] as num?)?.toDouble(),
      reviewStars: review is Map<String, dynamic>
          ? (review['stars'] as num?)?.toInt()
          : null,
      reviewNote: review is Map<String, dynamic>
          ? review['note'] as String?
          : null,
      reviewTags: review is Map<String, dynamic>
          ? ((review['tags'] as List<dynamic>?) ?? const [])
              .map((e) => e.toString())
              .toList()
          : const [],
    );
  }
}

/// One page of completed-job history + the cursor for the next page (null = end).
class JobHistoryPage {
  const JobHistoryPage({required this.items, this.nextCursor});
  final List<PartnerJob> items;
  final int? nextCursor;
}

class JobsApi {
  JobsApi(this._dio);
  final Dio _dio;

  Future<List<PartnerJob>> list() async {
    final res = await _dio.get<Map<String, dynamic>>('/partner/jobs');
    final items = res.data?['items'] as List<dynamic>? ?? const [];
    return items
        .map((e) => PartnerJob.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PartnerJob> get(int id) async {
    final res = await _dio.get<Map<String, dynamic>>('/partner/jobs/$id');
    return PartnerJob.fromJson(res.data ?? const {});
  }

  /// Paginated completed / no-show job history.
  Future<JobHistoryPage> history({int? cursor, int limit = 20}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/partner/jobs/history',
      queryParameters: {
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
      },
    );
    final data = res.data ?? const {};
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map((e) => PartnerJob.fromJson(e as Map<String, dynamic>))
        .toList();
    return JobHistoryPage(
      items: items,
      nextCursor: (data['nextCursor'] as num?)?.toInt(),
    );
  }

  Future<PartnerJob> start(int id, String startOtp) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/partner/jobs/$id/start',
      data: {'startOtp': startOtp},
    );
    return PartnerJob.fromJson(res.data ?? const {});
  }

  Future<PartnerJob> complete(int id, String endOtp) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/partner/jobs/$id/complete',
      data: {'endOtp': endOtp},
    );
    return PartnerJob.fromJson(res.data ?? const {});
  }
}

final jobsApiProvider = Provider<JobsApi>((ref) {
  return JobsApi(ref.watch(dioProvider));
});
