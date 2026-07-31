import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_locale.dart';
import 'localization_service.dart';

const _prefsKey = 'xpert_locale';

class LocaleController extends Notifier<AppLocale> {
  @override
  AppLocale build() {
    // Sync load from prefs happens in bootstrap(); default until then.
    Future.microtask(_hydrateFromPrefs);
    return AppLocale.en;
  }

  Future<void> _hydrateFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = AppLocale.tryParse(prefs.getString(_prefsKey));
    if (stored != null && stored != state) {
      state = stored;
    }
  }

  Future<void> set(AppLocale locale, {bool persistLocal = true}) async {
    state = locale;
    if (persistLocal) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, locale.code);
    }
  }

  Future<void> syncFromProfile(String? languageCode) async {
    final locale = AppLocale.tryParse(languageCode);
    if (locale == null) return;
    await set(locale);
  }
}

final localeProvider = NotifierProvider<LocaleController, AppLocale>(
  LocaleController.new,
);

final translationsProvider = FutureProvider<LocalizationService>((ref) async {
  final locale = ref.watch(localeProvider);
  return LocalizationService.load(locale);
});
