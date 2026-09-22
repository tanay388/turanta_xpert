import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dio_client.dart';

/// What the server says about the build running right now.
@immutable
class AppVersionStatus {
  const AppVersionStatus({
    this.supported = true,
    this.updateAvailable = false,
    this.latestBuild = 0,
  });

  /// False only when this build is below the admin's minimum and must be
  /// blocked. Defaults true everywhere so nothing bricks the app.
  final bool supported;

  /// A newer build is published and this one may be offered it. Never true
  /// while [supported] is false — that case has a blocking screen instead.
  final bool updateAvailable;
  final int latestBuild;
}

/// Cold-start version gate: asks the backend about this build
/// (`GET /app-version/check`, public; both thresholds are set by the admin in
/// Platform Settings). Fails open — a network error must never brick the app.
final appVersionGateProvider = FutureProvider<AppVersionStatus>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    final build = int.tryParse(info.buildNumber) ?? 0;
    final dio = ref.watch(dioProvider);
    final res = await dio.get<Map<String, dynamic>>(
      '/app-version/check',
      queryParameters: {'app': 'partner', 'build': build},
    );
    final data = res.data ?? const {};
    return AppVersionStatus(
      supported: (data['supported'] as bool?) ?? true,
      updateAvailable: (data['updateAvailable'] as bool?) ?? false,
      latestBuild: (data['latestBuild'] as num?)?.toInt() ?? 0,
    );
  } catch (_) {
    return const AppVersionStatus();
  }
});

/// How long "Later" buys before the offer comes back.
const _snooze = Duration(days: 3);

const _snoozeKeyPrefix = 'update_snoozed_until_';

/// Whether to put the update sheet in front of them now.
///
/// An offer they have already declined has to stay gone for a while, or the
/// app reads as broken — but it must come back, or nobody ever updates. The
/// snooze is keyed by build, so publishing a newer one asks again immediately
/// rather than inheriting the old dismissal.
Future<bool> shouldOfferUpdate(int latestBuild) async {
  if (latestBuild <= 0) return false;
  try {
    final prefs = await SharedPreferences.getInstance();
    final until = prefs.getInt('$_snoozeKeyPrefix$latestBuild');
    if (until == null) return true;
    return DateTime.now().millisecondsSinceEpoch >= until;
  } catch (_) {
    return true;
  }
}

Future<void> snoozeUpdateOffer(int latestBuild) async {
  if (latestBuild <= 0) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      '$_snoozeKeyPrefix$latestBuild',
      DateTime.now().add(_snooze).millisecondsSinceEpoch,
    );
  } catch (_) {
    // Losing the snooze only means asking again sooner than intended.
  }
}
