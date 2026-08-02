import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/i18n/context_t.dart';
import '../../../../core/theme/xpert_tokens.dart';
import '../../../legal/data/legal_document_api.dart';

/// Matches the `{terms}` / `{privacy}` slots in `login.legal.consent`.
///
/// The sentence is a template rather than three concatenated fragments because
/// word order moves between languages — Hindi and Marathi both put the
/// documents before the verb — and a link glued on by position would land
/// mid-sentence.
final _slot = RegExp(r'\{(terms|privacy)\}');

/// The consent line under the sign-in button: which documents pressing it
/// accepts, each opening its PDF in-app.
///
/// The documents come from the API, which means they can be absent — not yet
/// tagged, deactivated, or the request simply hasn't landed. The statement is
/// what has to be on screen, so an unresolved document degrades to plain text
/// instead of a dead link or a missing sentence.
class AuthLegalConsent extends HookConsumerWidget {
  const AuthLegalConsent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consent = ref.watch(legalConsentProvider).valueOrNull;

    // One recognizer per slot, kept across rebuilds — the login screen rebuilds
    // on every keystroke in the phone field. `onTap` is reassigned below, since
    // the document it opens only arrives once the request resolves.
    final recognizers = useMemoized(() => <String, TapGestureRecognizer>{});
    useEffect(() {
      return () {
        for (final recognizer in recognizers.values) {
          recognizer.dispose();
        }
      };
    }, [recognizers]);

    final documents = <String, LegalDocumentSummary?>{
      'terms': consent?.terms,
      'privacy': consent?.privacyPolicy,
    };
    final labels = <String, String>{
      'terms': ref.t('login.legal.terms'),
      'privacy': ref.t('login.legal.privacy'),
    };

    const base = TextStyle(
      fontSize: 12,
      height: 1.45,
      color: XpertColors.muted,
    );
    final link = base.copyWith(
      color: XpertColors.onSurface,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: XpertColors.onSurface,
    );

    TextSpan spanFor(String slot) {
      final label = labels[slot] ?? slot;
      final document = documents[slot];
      if (document == null) return TextSpan(text: label, style: base);

      final recognizer = recognizers.putIfAbsent(
        slot,
        TapGestureRecognizer.new,
      )..onTap = () => context.push(
        '/legal-document',
        extra: (document.name, document.pdfUrl),
      );

      return TextSpan(
        text: label,
        style: link,
        recognizer: recognizer,
        semanticsLabel: label,
      );
    }

    final template = ref.t('login.legal.consent');
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final match in _slot.allMatches(template)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(text: template.substring(cursor, match.start), style: base),
        );
      }
      spans.add(spanFor(match.group(1)!));
      cursor = match.end;
    }
    if (cursor < template.length) {
      spans.add(TextSpan(text: template.substring(cursor), style: base));
    }

    return Text.rich(
      TextSpan(children: spans),
      textAlign: TextAlign.center,
      style: base,
    );
  }
}
