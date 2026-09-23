import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turanta_xpert/core/i18n/app_locale.dart';
import 'package:turanta_xpert/core/i18n/locale_provider.dart';
import 'package:turanta_xpert/core/i18n/localization_service.dart';
import 'package:turanta_xpert/core/location/location_service.dart';
import 'package:turanta_xpert/core/models/partner_shift.dart';
import 'package:turanta_xpert/features/home/data/attendance_api.dart';
import 'package:turanta_xpert/features/home/presentation/availability_controller.dart';
import 'package:turanta_xpert/features/home/presentation/widgets/shift_card.dart';

const _shift = PartnerShift(
  id: 1,
  name: 'Morning',
  startTime: '09:00',
  endTime: '18:00',
);

final _currentShift = CurrentShiftPayload(
  shift: _shift,
  workDate: '2026-08-02',
  scheduledStartAt: DateTime(2026, 8, 2, 9),
  scheduledEndAt: DateTime(2026, 8, 2, 18),
  allowedCheckinFrom: DateTime(2026, 8, 2, 8, 45),
  canCheckIn: true,
);

AttendanceState _onShift({LocationDenial? denial}) => AttendanceState(
  currentShift: _currentShift,
  locationDenial: denial,
  snapshot: AttendanceSnapshot(
    attendanceStatus: 'CHECKED_IN',
    availabilityStatus: 'AVAILABLE',
    presenceStatus: 'ONLINE',
    sessionId: 1,
    sessionStartedAt: DateTime.now().subtract(const Duration(hours: 2)),
    scheduledEndAt: DateTime(2026, 8, 2, 18),
  ),
);

class _FakeAttendance extends AttendanceController {
  _FakeAttendance(this._state);
  final AttendanceState _state;
  @override
  AttendanceState build() => _state;
}

Future<void> _pumpCard(WidgetTester tester, AttendanceState attendance) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final translations = await tester.runAsync(
    () => LocalizationService.load(AppLocale.en),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        translationsProvider.overrideWith((_) async => translations!),
        attendanceProvider.overrideWith(() => _FakeAttendance(attendance)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ListView(children: [ShiftCard(attendance: attendance)]),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  /// Every denial has to reach the partner as a sentence, in their language.
  /// The controller used to hardcode one English string for all four causes,
  /// three of which it described wrongly.
  group('denial messages', () {
    test('every cause has a key', () {
      for (final denial in LocationDenial.values) {
        expect(denialMessageKey(denial), isNotEmpty);
      }
    });

    test('every key exists in every language', () {
      final keys = [
        ...LocationDenial.values.map(denialMessageKey),
        'location.lost_title',
        'location.open_settings',
        'location.turn_on',
      ];
      for (final locale in ['en', 'hi', 'hinglish', 'mr']) {
        final json =
            jsonDecode(File('assets/i18n/$locale.json').readAsStringSync())
                as Map<String, dynamic>;
        for (final key in keys) {
          expect(
            json[key],
            isA<String>().having((s) => s.trim(), 'text', isNotEmpty),
            reason: '$key missing from $locale.json',
          );
        }
      }
    });

    test('the causes do not share one sentence', () {
      final en =
          jsonDecode(File('assets/i18n/en.json').readAsStringSync())
              as Map<String, dynamic>;
      final sentences = LocationDenial.values
          .map((d) => en[denialMessageKey(d)] as String)
          .toSet();
      expect(sentences, hasLength(LocationDenial.values.length));
    });
  });

  group('on shift without a fix', () {
    test('is location lost', () {
      expect(_onShift(denial: LocationDenial.blocked).isLocationLost, isTrue);
    });

    test('off shift is not, however denied', () {
      const offShift = AttendanceState(locationDenial: LocationDenial.blocked);
      expect(offShift.isLocationLost, isFalse);
    });

    test('a working fix clears it', () {
      expect(_onShift().isLocationLost, isFalse);
    });

    testWidgets('the card says dispatch cannot see them', (tester) async {
      await _pumpCard(tester, _onShift(denial: LocationDenial.blocked));

      expect(find.text("Dispatch can't see you"), findsOneWidget);
      expect(find.byIcon(Icons.location_off_rounded), findsOneWidget);
    });

    testWidgets('a blocked permission offers the way out', (tester) async {
      await _pumpCard(tester, _onShift(denial: LocationDenial.blocked));

      // The whole point: iOS never prompts twice, so without this the partner
      // has no route back at all.
      expect(find.text('Open settings'), findsOneWidget);
    });

    testWidgets('switched-off services point at the device, not the app', (
      tester,
    ) async {
      await _pumpCard(tester, _onShift(denial: LocationDenial.servicesOff));

      expect(find.text('Turn on location'), findsOneWidget);
      expect(find.text('Open settings'), findsNothing);
    });

    testWidgets('a timeout offers nothing to open, because nothing would help', (
      tester,
    ) async {
      await _pumpCard(tester, _onShift(denial: LocationDenial.unavailable));

      expect(find.text("Dispatch can't see you"), findsOneWidget);
      expect(find.text('Open settings'), findsNothing);
      expect(find.text('Turn on location'), findsNothing);
    });

    testWidgets('a working shift shows no banner', (tester) async {
      await _pumpCard(tester, _onShift());

      expect(find.text("Dispatch can't see you"), findsNothing);
    });
  });
}
