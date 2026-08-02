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
import 'package:turanta_xpert/app/shell/xpert_sections.dart';
import 'package:turanta_xpert/features/hub/data/hub_api.dart';
import 'package:turanta_xpert/features/hub/presentation/hub_screen.dart';
import 'package:turanta_xpert/features/profile/presentation/financial_details_screen.dart';

const _kyc = PartnerKyc(
  userId: 'u1',
  accountHolderName: 'Tanay Deo',
  bankName: 'HDFC Bank',
  bankAccountNumberMasked: 'XXXXXX4821',
  bankIfsc: 'HDFC0001234',
  panNumberMasked: 'XXXXX1234X',
  aadhaarNumberMasked: 'XXXX XXXX 9012',
  gstNumber: '',
  uanNumber: '100234567890',
  status: PartnerKycStatus.approved,
);

class _FakeApi extends PartnerAuthApi {
  _FakeApi() : super(Dio());
  @override
  Future<PartnerKyc> getKyc() async => _kyc;
}


Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
  AppLocale locale = AppLocale.en,
  Size size = const Size(390, 1100),
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
        partnerAuthApiProvider.overrideWith((_) => _FakeApi()),
        ...overrides,
      ],
      child: MaterialApp.router(routerConfig: router, theme: XpertTheme.light),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('financial details', () {
    testWidgets('offers no way to edit', (tester) async {
      await _pump(tester, const FinancialDetailsScreen());

      // The partner-facing form is gone; the PATCH endpoint behind it is not.
      expect(find.text('Edit'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('shows the values exactly as the server masked them', (
      tester,
    ) async {
      await _pump(tester, const FinancialDetailsScreen());

      expect(find.text('XXXXXX4821'), findsOneWidget);
      expect(find.text('XXXXX1234X'), findsOneWidget);
    });

    testWidgets('marks a detail that was never provided', (tester) async {
      await _pump(tester, const FinancialDetailsScreen());

      // GST is empty on the fixture.
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('surfaces where verification stands', (tester) async {
      await _pump(tester, const FinancialDetailsScreen());

      // It was on the payload all along and this screen never showed it.
      expect(find.text('Verified — you can be paid'), findsOneWidget);
    });

    testWidgets('says how to get a wrong detail changed', (tester) async {
      await _pump(tester, const FinancialDetailsScreen());

      // Without this, removing Edit leaves the partner with no next step.
      expect(find.textContaining('Turanta support'), findsOneWidget);
    });

    testWidgets('survives a small screen in Hindi', (tester) async {
      await _pump(
        tester,
        const FinancialDetailsScreen(),
        locale: AppLocale.hi,
        size: const Size(320, 900),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('hub', () {
    testWidgets('a failure explains itself instead of dumping the exception', (
      tester,
    ) async {
      await _pump(
        tester,
        const HubScreen(),
        overrides: [
          partnerHubProvider.overrideWith(
            (_) => Future<PartnerHub>.error(
              Exception('DioException: connection timed out'),
            ),
          ),
        ],
      );

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text("Couldn't load your hub"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      // The raw exception used to be printed onto the screen.
      expect(find.textContaining('DioException'), findsNothing);
    });
  });
}
