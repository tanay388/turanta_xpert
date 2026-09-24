import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'token_store.dart';

/// One signed-in lifetime of the app. The root `ProviderScope` is keyed on
/// [generation], so every sign-out throws away each provider and controller
/// along with the old partner's data.
///
/// [endReason] travels with the epoch rather than through a provider: the
/// outgoing scope keeps running for a frame after the reset and would
/// otherwise consume the message on a screen that is about to disappear.
class SessionEpoch {
  const SessionEpoch(this.generation, [this.endReason]);
  final int generation;

  /// i18n key explaining why the last session ended, or null.
  final String? endReason;
}

final sessionEpoch = ValueNotifier(const SessionEpoch(0));

/// Preferences that belong to the device rather than to whoever signed in.
/// The device id must survive: the backend binds a partner to it.
bool _isDevicePreference(String key) =>
    key == 'xpert_device_id' ||
    key == 'xpert_locale' ||
    key == 'auth_installed' ||
    key.startsWith('update_snoozed_until_');

Future<void> endSession({String? reason}) async {
  await TokenStore.instance.clear();
  try {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      if (!_isDevicePreference(key)) await prefs.remove(key);
    }
  } catch (_) {
    // A preference that could not be removed must not keep the user signed in.
  }
  sessionEpoch.value = SessionEpoch(sessionEpoch.value.generation + 1, reason);
}
