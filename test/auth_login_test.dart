import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turanta_xpert/core/i18n/app_locale.dart';
import 'package:turanta_xpert/core/i18n/locale_provider.dart';
import 'package:turanta_xpert/core/i18n/localization_service.dart';
import 'package:turanta_xpert/features/auth/presentation/login_screen.dart';
import 'package:turanta_xpert/features/auth/presentation/widgets/auth_legal_consent.dart';
import 'package:turanta_xpert/features/auth/presentation/widgets/auth_primary_button.dart';
import 'package:turanta_xpert/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:turanta_xpert/features/legal/data/legal_document_api.dart';

const _screen = Size(360, 800);
const _keyboard = 280.0;

const _terms = LegalDocumentSummary(
  id: 1,
  name: 'Partner Terms & Conditions',
  pdfUrl: 'https://cdn.example.com/terms.pdf',
);
const _privacy = LegalDocumentSummary(
  id: 2,
  name: 'Privacy Policy',
  pdfUrl: 'https://cdn.example.com/privacy.pdf',
);

/// What the viewer route was handed, so a test can assert the tap opened the
/// right document rather than merely navigating somewhere.
(String, String)? lastOpened;

Future<void> _pumpLogin(
  WidgetTester tester, {
  double keyboardInset = 0,
  AsyncValue<LegalConsentDocuments> consent = const AsyncData(
    LegalConsentDocuments(privacyPolicy: _privacy, terms: _terms),
  ),
}) async {
  lastOpened = null;

  // Real strings, not stubs — the consent sentence is a template with
  // `{terms}` / `{privacy}` slots, and splitting it is part of what's tested.
  final translations = await tester.runAsync(
    () => LocalizationService.load(AppLocale.en),
  );

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(viewInsets: EdgeInsets.only(bottom: keyboardInset)),
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/legal-document',
        builder: (_, state) {
          lastOpened = state.extra as (String, String);
          return const Scaffold(body: Text('viewer'));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        translationsProvider.overrideWith((_) async => translations!),
        legalConsentProvider.overrideWith(
          (_) => consent.when(
            data: (value) => value,
            loading: () => Completer<LegalConsentDocuments>().future,
            error: (error, _) => Future<LegalConsentDocuments>.error(error),
          ),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

/// The white sheet — identified by its top-only 32px corner radius, which
/// nothing else in the auth tree uses.
Finder _sheet() => find.byWidgetPredicate((w) {
  if (w is! Container) return false;
  final d = w.decoration;
  if (d is! BoxDecoration) return false;
  return d.borderRadius ==
      const BorderRadius.vertical(top: Radius.circular(32));
}, description: 'auth sheet');

void main() {
  testWidgets('sheet sits on the screen bottom with no keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = _screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpLogin(tester);

    final rect = tester.getRect(_sheet().first);
    expect(rect.bottom, moreOrLessEquals(_screen.height, epsilon: 0.5));
    expect(rect.height, greaterThan(_screen.height * 0.5));
  });

  testWidgets('sheet rises to sit on top of the keyboard', (tester) async {
    tester.view.physicalSize = _screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpLogin(tester, keyboardInset: _keyboard);

    final rect = tester.getRect(_sheet().first);
    expect(
      rect.bottom,
      moreOrLessEquals(_screen.height - _keyboard, epsilon: 0.5),
    );
  });

  testWidgets('phone field and button stay above the keyboard', (tester) async {
    tester.view.physicalSize = _screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpLogin(tester, keyboardInset: _keyboard);

    final limit = _screen.height - _keyboard;
    expect(
      tester.getBottomLeft(find.byType(AuthTextField).first).dy,
      lessThanOrEqualTo(limit),
    );
    expect(
      tester.getBottomLeft(find.byType(AuthPrimaryButton)).dy,
      lessThanOrEqualTo(limit),
    );
  });

  testWidgets('survives a very tall keyboard on a short screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 560);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpLogin(tester, keyboardInset: 320);

    expect(tester.takeException(), isNull);
  });

  testWidgets('referral field is disclosed, not shown by default', (
    tester,
  ) async {
    tester.view.physicalSize = _screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpLogin(tester);

    // Optional and first-sign-in-only, so it must not compete with the phone
    // number on every later sign-in.
    expect(find.byType(AuthTextField), findsOneWidget);

    await tester.tap(find.text('Have a referral code?'));
    await tester.pumpAndSettle();

    expect(find.byType(AuthTextField), findsNWidgets(2));
  });

  testWidgets('consent line links each document', (tester) async {
    tester.view.physicalSize = _screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpLogin(tester);

    expect(find.byType(AuthLegalConsent), findsOneWidget);

    await tester.tapOnText(find.textRange.ofSubstring('Terms & Conditions'));
    await tester.pumpAndSettle();
    expect(lastOpened, (
      'Partner Terms & Conditions',
      'https://cdn.example.com/terms.pdf',
    ));
  });

  testWidgets('still states the terms when the API fails', (tester) async {
    tester.view.physicalSize = _screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpLogin(
      tester,
      consent: AsyncError(Exception('offline'), StackTrace.empty),
    );

    // The statement is the part that has to be on screen; the links are the
    // convenience. A dropped request must not silently remove the sentence.
    expect(
      find.textContaining(
        'By logging in you agree to our Terms & Conditions and Privacy Policy.',
      ),
      findsOneWidget,
    );

    await tester.tapOnText(find.textRange.ofSubstring('Privacy Policy'));
    await tester.pumpAndSettle();
    expect(lastOpened, isNull);
  });
}
