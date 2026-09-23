import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'token_store.dart';

/// Bumped on every sign-out. The app's `ProviderScope` is keyed on it, so
/// every provider and controller is thrown away with the old partner's data.
final sessionGeneration = ValueNotifier<int>(0);

/// Why the last session was torn down, for the login screen of the fresh
/// scope to show once.
String? pendingSessionEndReason;

/// Preferences that belong to the device rather than to whoever signed in.
/// The device id must survive: the backend binds a partner to it.
bool _isDevicePreference(String key) =>
    key == 'xpert_device_id' ||
    key == 'xpert_locale' ||
    key == 'auth_installed' ||
    key.startsWith('update_snoozed_until_');

Future<void> endSession({String? reason}) async {
  pendingSessionEndReason = reason;
  await TokenStore.instance.clear();
  try {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      if (!_isDevicePreference(key)) await prefs.remove(key);
    }
  } catch (_) {
    // A preference that could not be removed must not keep the user signed in.
  }
  sessionGeneration.value++;
}
