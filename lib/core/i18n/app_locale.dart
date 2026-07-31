enum AppLocale {
  en('en', 'English', 'English'),
  hinglish('hinglish', 'Hinglish', 'Hinglish'),
  hi('hi', 'Hindi', 'हिन्दी'),
  mr('mr', 'Marathi', 'मराठी');

  const AppLocale(this.code, this.labelEn, this.labelNative);
  final String code;
  final String labelEn;
  final String labelNative;

  static AppLocale? tryParse(String? code) {
    if (code == null || code.isEmpty) return null;
    for (final locale in AppLocale.values) {
      if (locale.code == code) return locale;
    }
    return null;
  }

  static AppLocale fromCode(String? code) => tryParse(code) ?? AppLocale.en;
}
