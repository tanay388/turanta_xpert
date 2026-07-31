import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'app/app.dart';
import 'core/notifications/fcm_background.dart';
import 'firebase_options.dart';

bool _firebaseReady = false;

Future<void> _initGoogleMaps() async {
  final platform = GoogleMapsFlutterPlatform.instance;
  if (platform is! GoogleMapsFlutterAndroid) return;

  platform.useAndroidViewSurface = true;
  try {
    await platform.initializeWithRenderer(AndroidMapRenderer.latest);
  } on PlatformException catch (e) {
    // Hot restart re-runs main() while the native renderer is still alive.
    if (e.code != 'Renderer already initialized') rethrow;
  }
}

Future<void> _initializeFirebase() async {
  if (Firebase.apps.isNotEmpty) {
    _firebaseReady = true;
    return;
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _firebaseReady = true;
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      _firebaseReady = true;
      return;
    }
    // Placeholder firebase_options will fail until flutterfire configure.
    if (kDebugMode) {
      debugPrint(
        'Firebase init failed (run flutterfire configure): ${e.message}',
      );
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Firebase init failed (run flutterfire configure): $e');
    }
  }
}

void _configureCrashReporting() {
  if (!_firebaseReady || Firebase.apps.isEmpty) return;

  FlutterError.onError = (details) {
    FirebaseCrashlytics.instance.recordFlutterError(details);
    if (kDebugMode) FlutterError.dumpErrorToConsole(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  unawaited(
    FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode),
  );
}

void _reportUncaughtError(Object error, StackTrace stack) {
  if (_firebaseReady && Firebase.apps.isNotEmpty) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return;
  }
  if (kDebugMode) {
    debugPrint('Uncaught error: $error');
    debugPrintStack(stackTrace: stack);
  }
}

Future<void> main() async {
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await _initGoogleMaps();
    await _initializeFirebase();
    if (_firebaseReady) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }
    _configureCrashReporting();
    runApp(const ProviderScope(child: TurantaXpertApp()));
  }, _reportUncaughtError);
}
