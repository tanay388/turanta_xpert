import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/dio_client.dart';

class ReferralWorkProfile {
  const ReferralWorkProfile({required this.id, required this.name});

  final int id;
  final String name;

  factory ReferralWorkProfile.fromJson(Map<String, dynamic> json) {
    return ReferralWorkProfile(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
    );
  }
}

class ReferralInvite {
  const ReferralInvite({
    required this.id,
    this.refereeDisplayName,
    this.serviceName,
    required this.status,
    required this.rewardAmount,
    required this.stepsCompleted,
  });

  final int id;
  final String? refereeDisplayName;
  final String? serviceName;
  final String status;
  final double rewardAmount;
  final int stepsCompleted;

  bool get isInvited => status == 'INVITED';
  bool get isSignedUp => status == 'SIGNED_UP';
  bool get isActive => status == 'ACTIVE';
  bool get isRewarded => status == 'REWARDED';
  bool get isLapsed => status == 'LAPSED';

  factory ReferralInvite.fromJson(Map<String, dynamic> json) {
    return ReferralInvite(
      id: (json['id'] as num).toInt(),
      refereeDisplayName: json['refereeDisplayName'] as String?,
      serviceName: json['serviceName'] as String?,
      status: json['status'] as String? ?? 'INVITED',
      rewardAmount: (json['rewardAmount'] as num?)?.toDouble() ?? 0,
      stepsCompleted: (json['stepsCompleted'] as num?)?.toInt() ?? 0,
    );
  }
}

class ReferralSummary {
  const ReferralSummary({
    required this.code,
    required this.shareLink,
    required this.rewardAmount,
    required this.milestoneJobs,
    required this.totalEarned,
    required this.active,
    required this.lapsed,
  });

  final String code;
  final String shareLink;
  final double rewardAmount;
  final int milestoneJobs;
  final double totalEarned;
  final List<ReferralInvite> active;
  final List<ReferralInvite> lapsed;

  factory ReferralSummary.fromJson(Map<String, dynamic> json) {
    final active = json['active'] as List<dynamic>? ?? const [];
    final lapsed = json['lapsed'] as List<dynamic>? ?? const [];
    return ReferralSummary(
      code: json['code'] as String? ?? '',
      shareLink: json['shareLink'] as String? ?? '',
      rewardAmount: (json['rewardAmount'] as num?)?.toDouble() ?? 0,
      milestoneJobs: (json['milestoneJobs'] as num?)?.toInt() ?? 0,
      totalEarned: (json['totalEarned'] as num?)?.toDouble() ?? 0,
      active: active
          .map((e) => ReferralInvite.fromJson(e as Map<String, dynamic>))
          .toList(),
      lapsed: lapsed
          .map((e) => ReferralInvite.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ReferralApi {
  ReferralApi(this._dio);

  final Dio _dio;

  Future<ReferralSummary> getSummary() async {
    final res = await _dio.get<Map<String, dynamic>>('/partner/referrals');
    return ReferralSummary.fromJson(res.data ?? const {});
  }

  Future<List<ReferralWorkProfile>> getWorkProfiles() async {
    final res = await _dio.get<List<dynamic>>(
      '/partner/referrals/work-profiles',
    );
    return (res.data ?? const [])
        .map((e) => ReferralWorkProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String> invite({
    String? name,
    String? phone,
    int? serviceId,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/partner/referrals/invite',
      data: {
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        'serviceId': ?serviceId,
      },
    );
    return res.data?['shareLink'] as String? ?? '';
  }
}

final referralApiProvider = Provider<ReferralApi>(
  (ref) => ReferralApi(ref.watch(dioProvider)),
);
