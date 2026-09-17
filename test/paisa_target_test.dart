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
import 'package:turanta_xpert/features/paisa/presentation/payout_detail_screen.dart';
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
      GoRoute(
        path: '/jobs/:id',
        builder: (_, state) =>
            Scaffold(body: Text('job ${state.pathParameters['id']}')),
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

      expect(find.text('\u20b94,820'), findsOneWidget);
      // Five days into a fourteen-day window.
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator).first,
      );
      expect(bar.value, closeTo(5 / 14, 0.02));
      // The window's own answer to "when does this pay out?".
      expect(find.text('9 days left'), findsOneWidget);
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
      expect(find.text('\u20b99,140 paid'), findsOneWidget);
      expect(find.textContaining('\u20b916,770'), findsNothing);
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

      expect(find.text('\u20b94,820'), findsOneWidget);
    });
  });

  group('payout detail', () {
    final detail = PayoutCycleDetail(
      cycle: _cycles.first,
      items: [
        EarningLineItem(
          bookingId: 101,
          serviceName: 'Deep house cleaning',
          ratePerHour: 130,
          hours: 2,
          amount: 260,
          earnedAt: DateTime(2026, 7, 30),
        ),
        EarningLineItem(
          bookingId: 102,
          serviceName: 'Laundry & ironing',
          ratePerHour: 130,
          hours: 1.5,
          amount: 195,
          earnedAt: DateTime(2026, 7, 29),
        ),
      ],
    );

    List<Override> overrides() => [
      payoutCycleDetailProvider(6).overrideWith((_) => detail),
    ];

    testWidgets('the payout says what it is made of, and adds up', (
      tester,
    ) async {
      await _pump(
        tester,
        const PayoutDetailScreen(cycleId: 6),
        overrides: overrides(),
      );

      expect(find.text('2 jobs · 3.5 hr'), findsOneWidget);
      // The rows and the total are the same money, so the total is printed
      // where someone checking the arithmetic looks for it.
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('\u20b99,140'), findsNWidgets(2));
    });

    testWidgets('a line opens the job that earned it', (tester) async {
      await _pump(
        tester,
        const PayoutDetailScreen(cycleId: 6),
        overrides: overrides(),
      );

      await tester.tap(find.text('Laundry & ironing'));
      await tester.pumpAndSettle();

      expect(find.text('job 102'), findsOneWidget);
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
      // Scoped to the ladder: the band a partner is in is also named on the
      // rate card above it.
      double rungTop(String label) => tester
          .getTopLeft(
            find.descendant(
              of: find.byType(RateLadder),
              matching: find.text(label),
            ),
          )
          .dy;
      final gold = rungTop('Gold');
      final silver = rungTop('Silver');
      final bronze = rungTop('Bronze');
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

    testWidgets('an off-target metric keeps the line it crossed in view', (
      tester,
    ) async {
      await _pump(
        tester,
        const TargetScreen(),
        overrides: [performanceProvider.overrideWith((_) => _perf)],
      );

      // 4 cancellations against a limit of 2. The tile used to replace the
      // limit with "Needs work", leaving the number with nothing to measure.
      expect(find.text('Target: ≤ 2'), findsNWidgets(2));
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('the top band says so instead of dangling a next step', (
      tester,
    ) async {
      const top = PartnerPerformance(
        rating: 4.8,
        ratingCount: 120,
        currentRatePerHour: 150,
        currentBandLabel: 'Gold',
        ladder: [
          RateLadderBand(
            label: 'Silver',
            minRating: 4.0,
            maxRating: 4.4,
            ratePerHour: 130,
          ),
          RateLadderBand(
            label: 'Gold',
            minRating: 4.5,
            maxRating: 5,
            ratePerHour: 150,
            current: true,
          ),
        ],
        ratingMetric: PerformanceMetric(value: 4.8, threshold: 4.0, ok: true),
        unavailableMetric: PerformanceMetric(value: 0, threshold: 3, ok: true),
        cancellationsMetric: PerformanceMetric(
          value: 0,
          threshold: 2,
          ok: true,
        ),
        lateShowMetric: PerformanceMetric(value: 1, threshold: 2, ok: true),
      );

      await _pump(
        tester,
        const TargetScreen(),
        overrides: [performanceProvider.overrideWith((_) => top)],
      );

      expect(find.text('Top band — you earn the highest rate'), findsOneWidget);
      expect(find.textContaining('to go'), findsNothing);
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
      expect(
        bars[1].value,
        closeTo(2 / 3, 0.01),
      ); // 1 of 3 unavailable days used
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
