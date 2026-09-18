import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turanta_xpert/app/theme.dart';
import 'package:turanta_xpert/core/i18n/app_locale.dart';
import 'package:turanta_xpert/core/i18n/locale_provider.dart';
import 'package:turanta_xpert/core/i18n/localization_service.dart';
import 'package:turanta_xpert/core/models/partner_user.dart';
import 'package:turanta_xpert/features/auth/data/partner_auth_api.dart';
import 'package:turanta_xpert/features/gender/presentation/gender_screen.dart';

class FakeApi extends PartnerAuthApi {
  FakeApi({this.fails = false}) : super(Dio());

  final bool fails;
  String? saved;

  @override
  Future<PartnerUser> updateProfile({
    String? name,
    String? gender,
    String? phone,
    String? photoPath,
  }) async {
    if (fails) {
      throw DioException.connectionError(
        requestOptions: RequestOptions(),
        reason: 'offline',
      );
    }
    saved = gender;
    return PartnerUser(
      id: 'u1',
      role: UserRole.partner,
      status: UserStatus.active,
      gender: gender,
    );
  }
}

class _FakeLocale extends LocaleController {
  @override
  AppLocale build() => AppLocale.en;
}

late FakeApi api;

Future<void> _pump(
  WidgetTester tester, {
  bool fails = false,
  AppLocale locale = AppLocale.en,
  Size size = const Size(320, 700),
}) async {
  api = FakeApi(fails: fails);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final translations = await tester.runAsync(
    () => LocalizationService.load(locale),
  );
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const GenderScreen()),
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(body: Text('login')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        translationsProvider.overrideWith((_) async => translations!),
        localeProvider.overrideWith(_FakeLocale.new),
        partnerAuthApiProvider.overrideWith((_) => api),
      ],
      child: MaterialApp.router(routerConfig: router, theme: XpertTheme.light),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _cta() => find.widgetWithText(FilledButton, 'Continue');

void main() {
  testWidgets('offers all three, with nothing chosen for them', (tester) async {
    await _pump(tester);

    expect(find.text('Male'), findsOneWidget);
    expect(find.text('Female'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
    // Nothing is pre-selected, so the answer is always the partner's own.
    expect(tester.widget<FilledButton>(_cta()).onPressed, isNull);
  });

  testWidgets('saves the one that was tapped', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Female'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(_cta()).onPressed, isNotNull);

    await tester.tap(_cta());
    await tester.pumpAndSettle();

    expect(api.saved, 'Female');
  });

  testWidgets('a failed save says so and keeps the pick', (tester) async {
    await _pump(tester, fails: true);

    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();
    await tester.tap(_cta());
    await tester.pumpAndSettle();

    expect(find.textContaining("Couldn't save"), findsOneWidget);
    expect(_cta(), findsOneWidget);
    expect(tester.widget<FilledButton>(_cta()).onPressed, isNotNull);
  });

  testWidgets('three boxes fit a narrow phone in Hindi', (tester) async {
    await _pump(tester, locale: AppLocale.hi, size: const Size(320, 700));

    expect(tester.takeException(), isNull);
  });
}
