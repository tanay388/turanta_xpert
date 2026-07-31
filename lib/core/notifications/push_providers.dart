import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../network/dio_client.dart';
import 'pending_deep_link.dart';
import 'push_notification_service.dart';

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  final deviceInfo = ref.watch(deviceInfoServiceProvider);
  final dio = ref.watch(dioProvider);

  final service = PushNotificationService(
    registerToken: (token) async {
      deviceInfo.setNotificationToken(token);

      // Only hit the API when Firebase Auth has a session.
      if (FirebaseAuth.instance.currentUser == null) return;

      await dio.post<Map<String, dynamic>>(
        '/user/firebase-token',
        options: Options(
          headers: {'notification-token': token},
        ),
      );
    },
    onOpenedLink: (link) {
      ref.read(pendingDeepLinkProvider.notifier).state = link;
    },
  );

  ref.onDispose(() => service.dispose());
  return service;
});
