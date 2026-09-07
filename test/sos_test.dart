import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turanta_xpert/core/i18n/app_locale.dart';
import 'package:turanta_xpert/core/i18n/locale_provider.dart';
import 'package:turanta_xpert/core/i18n/localization_service.dart';
import 'package:turanta_xpert/features/home/presentation/widgets/home_header.dart';
import 'package:turanta_xpert/features/sos/data/sos_api.dart';
import 'package:turanta_xpert/features/sos/presentation/sos_controller.dart';
import 'package:turanta_xpert/features/sos/presentation/widgets/sos_active_card.dart';

class _FakeLocale extends LocaleController {
  @override
  AppLocale build() => AppLocale.en;
}

class _FakeSos extends SosController {
  _FakeSos(this._state);
  final SosState _state;
  @override
  SosState build() => _state;
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  SosState sos = const SosState(),
  AppLocale locale = AppLocale.en,
}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final translations = await tester.runAsync(
    () => LocalizationService.load(locale),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        translationsProvider.overrideWith((_) async => translations!),
        localeProvider.overrideWith(_FakeLocale.new),
        sosProvider.overrideWith(() => _FakeSos(sos)),
      ],
      child: MaterialApp(
        home: Scaffold(body: ListView(children: [child])),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 60));
}

void main() {
  testWidgets('the SOS button is absent off shift', (tester) async {
    await _pump(tester, HomeHeader(onEmergency: () {}, showEmergency: false));

    // Off shift there is no live location and no job, so the button is gone
    // rather than present and useless.
    expect(find.byIcon(Icons.sos_rounded), findsNothing);
  });

  testWidgets('the SOS button is there while checked in', (tester) async {
    await _pump(tester, HomeHeader(onEmergency: () {}, showEmergency: true));

    expect(find.byIcon(Icons.sos_rounded), findsOneWidget);
  });

  testWidgets('a raised alert says so without the helper doing anything', (
    tester,
  ) async {
    await _pump(
      tester,
      const SosActiveCard(),
      sos: const SosState(
        phase: SosPhase.sent,
        alert: SosAlert(id: 1, status: 'RAISED'),
      ),
    );

    expect(find.text('Alert sent'), findsOneWidget);
    expect(find.text("I'm safe — cancel alert"), findsOneWidget);
  });

  testWidgets('a failed alert offers a way back, not silence', (tester) async {
    await _pump(
      tester,
      const SosActiveCard(),
      sos: const SosState(phase: SosPhase.failed),
    );

    // The old button lied by showing "sent" unconditionally; a failure has to
    // be visible or the helper waits for help that was never called.
    expect(find.text('Alert not sent'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('nothing is shown when no alert is in flight', (tester) async {
    await _pump(tester, const SosActiveCard());

    expect(find.text('Alert sent'), findsNothing);
  });

  testWidgets('survives a small screen in Hindi', (tester) async {
    await _pump(
      tester,
      const SosActiveCard(),
      sos: const SosState(phase: SosPhase.sent, alert: SosAlert(id: 1, status: 'RAISED')),
      locale: AppLocale.hi,
    );

    expect(tester.takeException(), isNull);
  });
}
