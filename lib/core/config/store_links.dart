import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Where to send someone to update, or null when this platform has nowhere.
///
/// One place per app on purpose: these were duplicated across the blocking
/// update screen and the dismissible one, which is how the iOS link sat as a
/// placeholder in both long after the consumer app was published.
class StoreLinks {
  const StoreLinks._();

  static const playStore =
      'https://play.google.com/store/apps/details?id=com.turanta.turanta_xpert';

  /// TODO: Xpert is not on the App Store. Set this to
  /// `https://apps.apple.com/app/id<numeric id>` once it is published —
  /// without a `/us/` storefront prefix, so Apple resolves the region from
  /// the device rather than telling everyone outside it that the app is
  /// unavailable.
  static const String? appStore = null;

  /// Null on iOS until Xpert ships there. Deliberately not falling back to
  /// Play: that link opens a dead web page on an iPhone, which is worse than
  /// no button at all.
  static String? get forThisPlatform =>
      (!kIsWeb && Platform.isIOS) ? appStore : playStore;
}
