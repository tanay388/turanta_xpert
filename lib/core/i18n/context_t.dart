import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'locale_provider.dart';
import 'localization_service.dart';

extension TranslateExtension on WidgetRef {
  String t(String key, [Map<String, dynamic>? vars]) {
    final translations = watch(translationsProvider).valueOrNull;
    return translations?.t(key, vars) ?? key;
  }

  LocalizationService? get translations =>
      watch(translationsProvider).valueOrNull;
}
