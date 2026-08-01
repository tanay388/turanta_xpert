import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'dio_client.dart';

/// Cold-start version gate: asks the backend whether this build is still
/// supported (`GET /app-version/check`, public; minimum build is set by the
/// admin in Platform Settings). Fails open — a network error must never
/// brick the app.
final appVersionGateProvider = FutureProvider<bool>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    final build = int.tryParse(info.buildNumber) ?? 0;
    final dio = ref.watch(dioProvider);
    final res = await dio.get<Map<String, dynamic>>(
      '/app-version/check',
      queryParameters: {'app': 'partner', 'build': build},
    );
    return (res.data?['supported'] as bool?) ?? true;
  } catch (_) {
    return true;
  }
});
