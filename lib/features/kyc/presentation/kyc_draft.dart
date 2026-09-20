import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// What the KYC wizard had typed, kept on the phone between launches.
///
/// Seven steps is a long walk, and the wizard held everything in widget state:
/// a phone call, a low-memory kill, or a tap on the wrong thing and a partner
/// started again from their name. Uploads already survive as storage keys, so
/// only the text and the keys need saving.
///
/// Signed preview links are deliberately absent — they expire in fifteen
/// minutes, so a restored draft re-resolves them rather than showing a broken
/// thumbnail.
class KycDraft {
  const KycDraft(this.values);

  final Map<String, String> values;

  static String _keyFor(String uid) => 'kyc_draft_$uid';

  String? operator [](String field) {
    final value = values[field];
    return (value == null || value.isEmpty) ? null : value;
  }

  static Future<KycDraft?> load(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyFor(uid));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return KycDraft({
        for (final entry in decoded.entries)
          if (entry.value is String)
            entry.key.toString(): entry.value as String,
      });
    } catch (_) {
      // A draft that cannot be read is not worth failing onboarding over.
      return null;
    }
  }

  static Future<void> save(String uid, Map<String, String?> values) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clean = {
        for (final entry in values.entries)
          if (entry.value != null && entry.value!.isNotEmpty)
            entry.key: entry.value!,
      };
      if (clean.isEmpty) return;
      await prefs.setString(_keyFor(uid), jsonEncode(clean));
    } catch (_) {
      // Best effort: losing a draft is a nuisance, losing the submit is not.
    }
  }

  /// Called once the KYC is safely with the server.
  static Future<void> clear(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyFor(uid));
    } catch (_) {}
  }
}
