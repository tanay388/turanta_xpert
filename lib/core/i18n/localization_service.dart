import 'dart:convert';

import 'package:flutter/services.dart';

import 'app_locale.dart';

class LocalizationService {
  LocalizationService._(this.locale, this._strings, this._fallback);

  final AppLocale locale;
  final Map<String, String> _strings;
  final Map<String, String> _fallback;

  static Future<LocalizationService> load(AppLocale locale) async {
    final strings = await _loadBundle(locale.code);
    final fallback =
        locale == AppLocale.en ? strings : await _loadBundle(AppLocale.en.code);
    return LocalizationService._(locale, strings, fallback);
  }

  static Future<Map<String, String>> _loadBundle(String code) async {
    final raw = await rootBundle.loadString('assets/i18n/$code.json');
    final decoded = json.decode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v.toString()));
  }

  String t(String key, [Map<String, dynamic>? vars]) {
    final template = _strings[key] ?? _fallback[key] ?? key;
    if (vars == null || vars.isEmpty) return template;
    var out = template;
    vars.forEach((k, v) => out = out.replaceAll('{$k}', v.toString()));
    return out;
  }
}
