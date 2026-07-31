import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Set when a push notification is opened; consumed by [HomeScreen] / router.
final pendingDeepLinkProvider = StateProvider<String?>((ref) => null);
