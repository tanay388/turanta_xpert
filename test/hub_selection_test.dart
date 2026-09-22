import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turanta_xpert/app/theme.dart';
import 'package:turanta_xpert/core/i18n/app_locale.dart';
import 'package:turanta_xpert/core/i18n/locale_provider.dart';
import 'package:turanta_xpert/core/i18n/localization_service.dart';
import 'package:turanta_xpert/features/hub/data/location_api.dart';
import 'package:turanta_xpert/features/hub/presentation/hub_selection_screen.dart';
import 'package:turanta_xpert/features/hub/presentation/widgets/searchable_picker_screen.dart';

/// Ordered as the server would with a fix near Thane: closest first.
const _cities = [
  HubCity(
    id: 3,
    name: 'Thane',
    state: 'Maharashtra',
    distanceKm: 0,
    areas: [HubArea(id: 30, name: 'Diva')],
  ),
  HubCity(
    id: 1,
    name: 'Mumbai',
    state: 'Maharashtra',
    distanceKm: 19,
    areas: [
      HubArea(id: 10, name: 'Wadala East'),
      HubArea(id: 11, name: 'Bandra Kurla Complex'),
    ],
  ),
  HubCity(
    id: 4,
    name: 'Bengaluru',
    state: 'Karnataka',
    distanceKm: 851.7,
    areas: [HubArea(id: 40, name: 'Bengaluru Central')],
  ),
  HubCity(id: 5, name: 'Pune', state: 'Maharashtra', areas: []),
];

const _hubsByArea = {
  10: [HubOption(id: 100, name: 'Wadala East', address: 'Wadala East')],
  11: [
    HubOption(id: 101, name: 'BKC'),
    HubOption(id: 102, name: 'BKC Annexe'),
  ],
  30: <HubOption>[],
  40: [HubOption(id: 400, name: 'Koramangala')],
};

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final translations = await tester.runAsync(
    () => LocalizationService.load(AppLocale.en),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        translationsProvider.overrideWith((_) async => translations!),
        hubCitiesProvider.overrideWith((_) async => _cities),
        hubsInAreaProvider.overrideWith(
          (_, areaId) async => _hubsByArea[areaId] ?? const [],
        ),
      ],
      child: MaterialApp.router(
        theme: XpertTheme.light,
        routerConfig: GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, _) => const HubSelectionScreen()),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The Continue button, which must stay dead until a hub is actually chosen.
bool _canContinue(WidgetTester tester) {
  final button = tester.widget<FilledButton>(find.byType(FilledButton));
  return button.onPressed != null;
}

Future<void> _choose(WidgetTester tester, String row, String option) async {
  await tester.tap(find.text(row.toUpperCase()));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('each answer opens its own searchable screen', (tester) async {
    await _pump(tester);

    // Nothing is chosen, so the rows say what they want and Continue is dead.
    expect(find.text('Tap to choose'), findsOneWidget);
    expect(find.text('Pick a city first'), findsOneWidget);
    expect(find.text('Pick an area first'), findsOneWidget);
    expect(_canContinue(tester), isFalse);

    await tester.tap(find.text('CITY'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchablePickerScreen), findsOneWidget);
    expect(find.text('Mumbai'), findsOneWidget);

    await tester.tap(find.text('Mumbai'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchablePickerScreen), findsNothing);
    expect(find.text('Mumbai'), findsOneWidget);

    await _choose(tester, 'area', 'Bandra Kurla Complex');
    await _choose(tester, 'hub', 'BKC Annexe');

    expect(_canContinue(tester), isTrue);
  });

  testWidgets('the closest city leads and says how far it is', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('CITY'));
    await tester.pumpAndSettle();

    final labels = tester
        .widgetList<SearchablePickerScreen>(find.byType(SearchablePickerScreen))
        .single
        .options
        .map((o) => o.label)
        .toList();
    expect(labels.first, 'Thane');
    expect(find.text('Nearest'), findsOneWidget);
    expect(find.textContaining('19 km away'), findsOneWidget);
    // A city with no coordinates still lists, just without a distance.
    expect(find.text('Pune'), findsOneWidget);
  });

  testWidgets('search narrows a long list to what was typed', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('CITY'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ben');
    await tester.pumpAndSettle();

    expect(find.text('Bengaluru'), findsOneWidget);
    expect(find.text('Mumbai'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.textContaining('Nothing matches'), findsOneWidget);
  });

  testWidgets('changing the city drops the area and hub under it', (
    tester,
  ) async {
    await _pump(tester);

    await _choose(tester, 'city', 'Mumbai');
    await _choose(tester, 'area', 'Wadala East');
    await _choose(tester, 'hub', 'Wadala East');
    expect(_canContinue(tester), isTrue);

    await _choose(tester, 'city', 'Bengaluru');

    expect(_canContinue(tester), isFalse);
    // Area is open again, and hub has gone back to waiting on it.
    expect(find.text('Tap to choose'), findsOneWidget);
    expect(find.text('Pick an area first'), findsOneWidget);
  });

  testWidgets('an area with no hubs says so instead of stalling', (
    tester,
  ) async {
    await _pump(tester);

    await _choose(tester, 'city', 'Thane');
    await _choose(tester, 'area', 'Diva');

    await tester.tap(find.text('HUB'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No hubs in this area'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(_canContinue(tester), isFalse);
  });
}
