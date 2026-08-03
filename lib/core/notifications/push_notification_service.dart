import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

typedef FcmTokenRegistrar = Future<void> Function(String token);
typedef NotificationOpenHandler = void Function(String? hyperLink);

/// A job-lifecycle push (`job_assigned`, `job_started`, `job_extended`,
/// `job_ending_soon`, `job_overdue`, `job_completed`, …) — the `event` +
/// `bookingId` tags the backend already sets in the FCM `data` payload.
class JobLifecycleEvent {
  const JobLifecycleEvent({required this.event, this.bookingId});
  final String event;
  final String? bookingId;
}

/// Requests permission, obtains the FCM token, registers it with the backend,
/// and shows foreground notifications on Android.
class PushNotificationService {
  PushNotificationService({
    required this.registerToken,
    this.onOpenedLink,
  });

  final FcmTokenRegistrar registerToken;
  final NotificationOpenHandler? onOpenedLink;

  // Lazy, so constructing the service does not require Firebase to be
  // initialised — a screen that only listens to [jobLifecycleEvents] can then
  // be exercised in a widget test.
  late final _messaging = FirebaseMessaging.instance;
  late final _local = FlutterLocalNotificationsPlugin();
  final _jobLifecycle = StreamController<JobLifecycleEvent>.broadcast();

  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  bool _initialized = false;
  String? _lastRegisteredToken;

  /// Emits whenever a job-lifecycle push arrives (foreground or tapped-open),
  /// so an open job screen can refresh immediately instead of waiting on its
  /// fallback poll.
  Stream<JobLifecycleEvent> get jobLifecycleEvents => _jobLifecycle.stream;

  static const _androidChannel = AndroidNotificationChannel(
    'turanta_xpert_default',
    'Turanta Xpert',
    description: 'Partner job and account notifications',
    importance: Importance.high,
  );

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Background handler is registered once in main.dart.

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await _initLocalNotifications();
    await _requestPermission();

    _foregroundSub = FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);
    _tokenSub = _messaging.onTokenRefresh.listen((token) {
      unawaited(_persistToken(token));
    });

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      _onOpened(initial);
    }
  }

  Future<void> syncTokenWithBackend() async {
    try {
      if (!await _ensureApnsReady()) {
        // Simulator / APNs not provisioned yet — onTokenRefresh will retry later.
        return;
      }

      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[FCM] No token available yet');
        return;
      }
      await _persistToken(token);
    } on FirebaseException catch (e) {
      if (e.code == 'apns-token-not-set') {
        debugPrint(
          '[FCM] APNs token unavailable (normal on iOS Simulator). '
          'Use a physical device with Push Notifications capability.',
        );
        return;
      }
      debugPrint('[FCM] syncToken failed: ${e.code} ${e.message}');
    } catch (e) {
      debugPrint('[FCM] syncToken failed: $e');
    }
  }

  /// iOS requires an APNs device token before FCM can mint an FCM token.
  Future<bool> _ensureApnsReady() async {
    if (kIsWeb || !Platform.isIOS) return true;

    // Already present?
    final existing = await _messaging.getAPNSToken();
    if (existing != null && existing.isNotEmpty) return true;

    // Poll briefly — APNs registration is async after permission grant.
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final token = await _messaging.getAPNSToken();
      if (token != null && token.isNotEmpty) return true;
    }

    debugPrint(
      '[FCM] APNs token not set after wait — skipping FCM getToken for now',
    );
    return false;
  }

  Future<void> dispose() async {
    await _tokenSub?.cancel();
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
    await _jobLifecycle.close();
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('[FCM] permission=${settings.authorizationStatus}');

    if (!kIsWeb && Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> _initLocalNotifications() async {
    try {
      const androidInit =
          AndroidInitializationSettings('@drawable/ic_stat_final_notification');
      const iosInit = DarwinInitializationSettings();
      await _local.initialize(
        settings: const InitializationSettings(android: androidInit, iOS: iosInit),
      );

      if (!kIsWeb && Platform.isAndroid) {
        await _local
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(_androidChannel);
      }
    } on MissingPluginException catch (e) {
      // Hot restart can leave plugins unregistered — full restart fixes it.
      debugPrint('[FCM] local_notifications unavailable: $e');
    } catch (e) {
      debugPrint('[FCM] local_notifications init failed: $e');
    }
  }

  Future<void> _persistToken(String token) async {
    if (token == _lastRegisteredToken) return;
    try {
      await registerToken(token);
      _lastRegisteredToken = token;
      debugPrint('[FCM] token registered (${token.substring(0, 12)}…)');
    } catch (e) {
      debugPrint('[FCM] registerToken failed: $e');
    }
  }

  void _emitJobLifecycle(RemoteMessage message) {
    final event = message.data['event']?.toString();
    if (event == null || event.isEmpty) return;
    if (_jobLifecycle.isClosed) return;
    _jobLifecycle.add(
      JobLifecycleEvent(
        event: event,
        bookingId: message.data['bookingId']?.toString(),
      ),
    );
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    debugPrint(
      '[FCM][fg] id=${message.messageId} title=${message.notification?.title} '
      'event=${message.data['event']}',
    );

    _emitJobLifecycle(message);

    final notification = message.notification;
    if (notification == null) return;

    // iOS presents automatically via setForegroundNotificationPresentationOptions.
    if (!kIsWeb && Platform.isIOS) return;

    try {
      await _local.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_stat_final_notification',
          ),
        ),
        payload: message.data['hyperLink']?.toString(),
      );
    } catch (e) {
      debugPrint('[FCM] local show failed: $e');
    }
  }

  void _onOpened(RemoteMessage message) {
    debugPrint(
      '[FCM][open] id=${message.messageId} data=${message.data}',
    );
    _emitJobLifecycle(message);
    final link = message.data['hyperLink']?.toString();
    if (link != null && link.isNotEmpty) {
      onOpenedLink?.call(link);
    }
  }
}
