import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/dio_client.dart';

/// One friend who signed up with the partner's code.
class ReferralInvite {
  const ReferralInvite({
    required this.id,
    this.refereeDisplayName,
    required this.status,
    required this.rewardAmount,
    required this.jobsDone,
    required this.jobsNeeded,
    required this.paid,
    this.joinedAt,
  });

  final int id;
  final String? refereeDisplayName;
  final String status;
  final double rewardAmount;
  final int jobsDone;
  final int jobsNeeded;

  /// The bonus for this friend has been added to a payout.
  final bool paid;
  final DateTime? joinedAt;

  int get jobsLeft => (jobsNeeded - jobsDone).clamp(0, jobsNeeded);
  double get progress =>
      jobsNeeded <= 0 ? 0 : (jobsDone / jobsNeeded).clamp(0, 1).toDouble();

  factory ReferralInvite.fromJson(Map<String, dynamic> json) {
    final created = json['createdAt'];
    return ReferralInvite(
      id: (json['id'] as num).toInt(),
      refereeDisplayName: json['refereeDisplayName'] as String?,
      status: json['status'] as String? ?? 'SIGNED_UP',
      rewardAmount: (json['rewardAmount'] as num?)?.toDouble() ?? 0,
      jobsDone:
          (json['jobsDone'] as num?)?.toInt() ??
          (json['stepsCompleted'] as num?)?.toInt() ??
          0,
      jobsNeeded: (json['jobsNeeded'] as num?)?.toInt() ?? 0,
      paid:
          json['paid'] as bool? ??
          json['referrerPaidAt'] != null ||
              json['status'] == 'REWARDED',
      joinedAt: created is String ? DateTime.tryParse(created) : null,
    );
  }
}

/// The partner's own joining bonus, when they came in on someone's code.
class JoiningBonus {
  const JoiningBonus({
    required this.amount,
    required this.jobsDone,
    required this.jobsNeeded,
    required this.paid,
  });

  final double amount;
  final int jobsDone;
  final int jobsNeeded;
  final bool paid;

  int get jobsLeft => (jobsNeeded - jobsDone).clamp(0, jobsNeeded);

  factory JoiningBonus.fromJson(Map<String, dynamic> json) {
    return JoiningBonus(
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      jobsDone: (json['jobsDone'] as num?)?.toInt() ?? 0,
      jobsNeeded: (json['jobsNeeded'] as num?)?.toInt() ?? 0,
      paid: json['paidAt'] != null,
    );
  }
}

class ReferralSummary {
  const ReferralSummary({
    required this.code,
    required this.shareLink,
    required this.enabled,
    required this.referrerAmount,
    required this.referrerJobs,
    required this.refereeAmount,
    required this.refereeJobs,
    required this.totalEarned,
    required this.pendingAmount,
    required this.friends,
    this.joiningBonus,
  });

  final String code;
  final String shareLink;
  final bool enabled;

  /// What the partner earns, and after how many jobs by their friend.
  final double referrerAmount;
  final int referrerJobs;

  /// What their friend earns for their own first jobs.
  final double refereeAmount;
  final int refereeJobs;

  final double totalEarned;

  /// Bonuses for friends who have joined but not yet finished their jobs.
  final double pendingAmount;
  final List<ReferralInvite> friends;
  final JoiningBonus? joiningBonus;

  factory ReferralSummary.fromJson(Map<String, dynamic> json) {
    final friends = json['active'] as List<dynamic>? ?? const [];
    final bonus = json['joiningBonus'];
    return ReferralSummary(
      code: json['code'] as String? ?? '',
      shareLink: json['shareLink'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      referrerAmount:
          (json['referrerAmount'] as num?)?.toDouble() ??
          (json['rewardAmount'] as num?)?.toDouble() ??
          0,
      referrerJobs:
          (json['referrerJobs'] as num?)?.toInt() ??
          (json['milestoneJobs'] as num?)?.toInt() ??
          0,
      refereeAmount: (json['refereeAmount'] as num?)?.toDouble() ?? 0,
      refereeJobs: (json['refereeJobs'] as num?)?.toInt() ?? 0,
      totalEarned: (json['totalEarned'] as num?)?.toDouble() ?? 0,
      pendingAmount: (json['pendingAmount'] as num?)?.toDouble() ?? 0,
      friends: friends
          .map((e) => ReferralInvite.fromJson(e as Map<String, dynamic>))
          .toList(),
      joiningBonus: bonus is Map<String, dynamic>
          ? JoiningBonus.fromJson(bonus)
          : null,
    );
  }
}

/// The offer as the server currently sets it, for screens that have no
/// referral summary to read from (signup, KYC).
class ReferralOffer {
  const ReferralOffer({
    required this.refereeAmount,
    required this.refereeJobs,
  });

  final double refereeAmount;
  final int refereeJobs;

  factory ReferralOffer.fromJson(Map<String, dynamic> json) {
    return ReferralOffer(
      refereeAmount: (json['refereeAmount'] as num?)?.toDouble() ?? 0,
      refereeJobs: (json['refereeJobs'] as num?)?.toInt() ?? 0,
    );
  }
}

/// What a code is worth before anyone signs up — used by the login screen.
class ReferralCodeCheck {
  const ReferralCodeCheck({required this.valid, this.referrerName});

  final bool valid;
  final String? referrerName;

  factory ReferralCodeCheck.fromJson(Map<String, dynamic> json) {
    return ReferralCodeCheck(
      valid: json['valid'] as bool? ?? false,
      referrerName: json['referrerName'] as String?,
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

  /// Unauthenticated: checked while typing, before an OTP is ever sent.
  Future<ReferralCodeCheck> checkCode(String code) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/referral/code/${code.trim().toUpperCase()}',
    );
    return ReferralCodeCheck.fromJson(res.data ?? const {});
  }

  Future<ReferralOffer> getOffer() async {
    final res = await _dio.get<Map<String, dynamic>>('/referral/offer');
    return ReferralOffer.fromJson(res.data ?? const {});
  }

  /// Attaches a code after signing up — allowed until the first job is done.
  Future<Map<String, dynamic>> applyCode(String code) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/partner/referrals/apply',
      data: {'code': code.trim().toUpperCase()},
    );
    return res.data ?? const {};
  }
}

final referralApiProvider = Provider<ReferralApi>(
  (ref) => ReferralApi(ref.watch(dioProvider)),
);

final referralOfferProvider = FutureProvider<ReferralOffer>(
  (ref) => ref.watch(referralApiProvider).getOffer(),
);
