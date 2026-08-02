import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turanta_xpert/app/shell/xpert_list_group.dart';
import 'package:turanta_xpert/app/theme.dart';
import 'package:turanta_xpert/core/i18n/app_locale.dart';
import 'package:turanta_xpert/core/i18n/locale_provider.dart';
import 'package:turanta_xpert/core/i18n/localization_service.dart';
import 'package:turanta_xpert/features/legal/data/legal_document_api.dart';
import 'package:turanta_xpert/features/profile/presentation/profile_screen.dart';
import 'package:turanta_xpert/features/settings/presentation/settings_screen.dart';

class _FakeLocale extends LocaleController {
  @override
  AppLocale build() => AppLocale.en;
}

const _docs = [
  LegalDocumentSummary(id: 1, name: 'Privacy Policy', pdfUrl: 'https://x/p.pdf'),
  LegalDocumentSummary(id: 2, name: 'Terms & Conditions', pdfUrl: 'https://x/t.pdf'),
];


Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(390, 1100),
  AppLocale locale = AppLocale.en,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final translations = await tester.runAsync(
    () => LocalizationService.load(locale),
  );
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => screen)],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        translationsProvider.overrideWith((_) async => translations!),
        legalDocumentsProvider.overrideWith((_) => _docs),
        localeProvider.overrideWith(_FakeLocale.new),
      ],
      child: MaterialApp.router(routerConfig: router, theme: XpertTheme.light),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('profile', () {
    testWidgets('offers exactly one way to edit', (tester) async {
      await _pump(tester, const ProfileScreen());

      // Edit profile used to sit in the app bar *and* as a full-width button
      // underneath, on the same screen.
      expect(find.text('Edit profile'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('does not repeat the name and phone it already shows', (
      tester,
    ) async {
      await _pump(tester, const ProfileScreen());

      // The headline carries both; the list below used to state them again as
      // two more bordered cards.
      expect(find.text('Partner'), findsOneWidget);
      expect(find.text('Name'), findsNothing);
      expect(find.text('Phone'), findsNothing);
    });

    testWidgets('the avatar says it can be changed', (tester) async {
      await _pump(tester, const ProfileScreen());

      // `profile.change_photo` was a translated string with nothing on this
      // screen attached to it.
      expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
    });

    testWidgets('carries no sign out of its own', (tester) async {
      await _pump(tester, const ProfileScreen());

      // It lives in Settings, one row down this very screen.
      expect(find.byIcon(Icons.logout_rounded), findsNothing);
    });
  });

  group('settings', () {
    testWidgets('groups preferences, legal and account', (tester) async {
      await _pump(tester, const SettingsScreen());

      expect(find.text('PREFERENCES'), findsOneWidget);
      expect(find.text('LEGAL & DOCUMENTS'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.byType(XpertListGroup), findsNWidgets(3));
    });

    testWidgets('says what each alert toggle controls', (tester) async {
      await _pump(tester, const SettingsScreen());

      // Two unexplained switches previously.
      expect(find.textContaining('WhatsApp'), findsWidgets);
      expect(find.text('Push alerts for new jobs and reminders'), findsOneWidget);
    });

    testWidgets('sign out asks before it acts', (tester) async {
      await _pump(tester, const SettingsScreen());

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      // It was one unguarded tap that ended the session.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Sign out?'), findsOneWidget);
    });

    testWidgets('the language sheet marks the one in use', (tester) async {
      await _pump(tester, const SettingsScreen());

      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();

      // Which language was active was previously not indicated at all.
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('survives a small screen in Hindi', (tester) async {
      await _pump(
        tester,
        const SettingsScreen(),
        size: const Size(320, 900),
        locale: AppLocale.hi,
      );

      expect(tester.takeException(), isNull);
    });
  });
}
