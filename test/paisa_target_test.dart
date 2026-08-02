import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turanta_xpert/app/theme.dart';
import 'package:turanta_xpert/core/i18n/app_locale.dart';
import 'package:turanta_xpert/core/i18n/locale_provider.dart';
import 'package:turanta_xpert/core/i18n/localization_service.dart';
import 'package:turanta_xpert/features/paisa/data/earning_api.dart';
import 'package:turanta_xpert/features/paisa/data/earning_models.dart';
import 'package:turanta_xpert/features/paisa/presentation/paisa_screen.dart';
import 'package:turanta_xpert/features/target/data/performance_api.dart';
import 'package:turanta_xpert/features/target/presentation/target_screen.dart';
import 'package:turanta_xpert/features/target/presentation/widgets/rate_ladder.dart';
import 'package:turanta_xpert/features/target/presentation/widgets/metric_tile.dart';

final _summary = EarningSummary(
  currentCycleId: 7,
  periodStart: DateTime.now().subtract(const Duration(days: 5)),
  periodEnd: DateTime.now().add(const Duration(days: 9)),
  totalAmount: 4820,
  status: PayoutStatus.accruing,
  ratePerHour: 130,
  band: const RateBand(label: 'Silver', ratePerHour: 130),
  rating: 4.3,
);

final _cycles = [
  PayoutCycle(
    id: 6,
    periodStart: DateTime(2026, 7, 16),
    periodEnd: DateTime(2026, 7, 31),
    totalAmount: 9140,
    status: PayoutStatus.paid,
    paidAt: DateTime(2026, 8, 2),
  ),
  PayoutCycle(
    id: 5,
    periodStart: DateTime(2026, 7, 1),
    periodEnd: DateTime(2026, 7, 15),
    totalAmount: 7630,
    status: PayoutStatus.pending,
  ),
];

const _perf = PartnerPerformance(
  rating: 4.3,
  ratingCount: 42,
  currentRatePerHour: 130,
  currentBandLabel: 'Silver',
  ladder: [
    RateLadderBand(
      label: 'Bronze',
      minRating: 0,
      maxRating: 3.9,
      ratePerHour: 110,
    ),
    RateLadderBand(
      label: 'Silver',
      minRating: 4.0,
      maxRating: 4.4,
      ratePerHour: 130,
      current: true,
    ),
    RateLadderBand(
      label: 'Gold',
      minRating: 4.5,
      maxRating: 5,
      ratePerHour: 150,
    ),
  ],
  ratingMetric: PerformanceMetric(value: 4.3, threshold: 4.0, ok: true),
  unavailableMetric: PerformanceMetric(value: 1, threshold: 3, ok: true),
  cancellationsMetric: PerformanceMetric(value: 4, threshold: 2, ok: false),
  lateShowMetric: PerformanceMetric(value: 0, threshold: 2, ok: true),
);


Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  required List<Override> overrides,
  AppLocale locale = AppLocale.en,
  Size screenSize = const Size(390, 1100),
}) async {
  tester.view.physicalSize = screenSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final translations = await tester.runAsync(
    () => LocalizationService.load(locale),
  );

  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => screen),
      GoRoute(
        path: '/paisa/cycles/:id',
        builder: (_, _) => const Scaffold(body: Text('detail')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        translationsProvider.overrideWith((_) async => translations!),
        ...overrides,
      ],
      child: MaterialApp.router(routerConfig: router, theme: XpertTheme.light),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('paisa', () {
    testWidgets('the cycle total leads and the window shows its progress', (
      tester,
    ) async {
      await _pump(
        tester,
        const PaisaScreen(),
        overrides: [
          earningSummaryProvider.overrideWith((_) => _summary),
          payoutCyclesProvider.overrideWith((_) => _cycles),
        ],
      );

      expect(find.text('\u20b94820'), findsOneWidget);
      // Five days into a fourteen-day window.
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator).first,
      );
      expect(bar.value, closeTo(5 / 14, 0.02));
    });

    testWidgets('the previous total counts only what was actually paid', (
      tester,
    ) async {
      await _pump(
        tester,
        const PaisaScreen(),
        overrides: [
          earningSummaryProvider.overrideWith((_) => _summary),
          payoutCyclesProvider.overrideWith((_) => _cycles),
        ],
      );

      // 9140 paid + 7630 still processing — only the first has landed.
      expect(find.text('\u20b99140'), findsNWidgets(2));
      expect(find.text('\u20b916770'), findsNothing);
    });

    testWidgets('the accruing cycle is not repeated in the list below', (
      tester,
    ) async {
      await _pump(
        tester,
        const PaisaScreen(),
        overrides: [
          earningSummaryProvider.overrideWith((_) => _summary),
          payoutCyclesProvider.overrideWith(
            (_) => [
              PayoutCycle(
                id: 7,
                periodStart: _summary.periodStart,
                periodEnd: _summary.periodEnd,
                totalAmount: 4820,
                status: PayoutStatus.accruing,
              ),
              ..._cycles,
            ],
          ),
        ],
      );

      expect(find.text('\u20b94820'), findsOneWidget);
    });
  });

  group('target', () {
    testWidgets('the ladder climbs, with the best-paying band on top', (
      tester,
    ) async {
      await _pump(
        tester,
        const TargetScreen(),
        overrides: [performanceProvider.overrideWith((_) => _perf)],
      );

      expect(find.byType(RateLadder), findsOneWidget);
      final gold = tester.getTopLeft(find.text('Gold')).dy;
      final silver = tester.getTopLeft(find.text('Silver')).dy;
      final bronze = tester.getTopLeft(find.text('Bronze')).dy;
      expect(gold, lessThan(silver));
      expect(silver, lessThan(bronze));
    });

    testWidgets('the next rung says what it costs and what it pays', (
      tester,
    ) async {
      await _pump(
        tester,
        const TargetScreen(),
        overrides: [performanceProvider.overrideWith((_) => _perf)],
      );

      // 4.5 needed, 4.3 held.
      expect(find.textContaining('0.2'), findsWidgets);
      expect(find.textContaining('150'), findsWidgets);
    });

    testWidgets('a metric bar fills in the direction that means better', (
      tester,
    ) async {
      await _pump(
        tester,
        const TargetScreen(),
        overrides: [performanceProvider.overrideWith((_) => _perf)],
      );

      final bars = tester
          .widgetList<LinearProgressIndicator>(
            find.descendant(
              of: find.byType(MetricTile),
              matching: find.byType(LinearProgressIndicator),
            ),
          )
          .toList();

      expect(bars[0].value, 1.0); // rating 4.3 against a 4.0 floor
      expect(bars[1].value, closeTo(2 / 3, 0.01)); // 1 of 3 unavailable days used
      expect(bars[2].value, 0.0); // 4 cancellations against a limit of 2
      expect(bars[3].value, 1.0); // no late shows at all
    });

    testWidgets('survives a small screen in Hindi', (tester) async {
      await _pump(
        tester,
        const TargetScreen(),
        overrides: [performanceProvider.overrideWith((_) => _perf)],
        locale: AppLocale.hi,
        screenSize: const Size(320, 640),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
