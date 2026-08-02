import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turanta_xpert/core/i18n/app_locale.dart';
import 'package:turanta_xpert/core/i18n/locale_provider.dart';
import 'package:turanta_xpert/core/i18n/localization_service.dart';
import 'package:turanta_xpert/core/models/partner_shift.dart';
import 'package:turanta_xpert/features/home/data/attendance_api.dart';
import 'package:turanta_xpert/features/home/data/summary_api.dart';
import 'package:turanta_xpert/features/home/presentation/availability_controller.dart';
import 'package:turanta_xpert/features/home/presentation/widgets/home_header.dart';
import 'package:turanta_xpert/features/home/presentation/widgets/shift_card.dart';
import 'package:turanta_xpert/features/home/presentation/widgets/shift_clock.dart';
import 'package:turanta_xpert/features/home/presentation/widgets/today_card.dart';

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

class _FakeAttendance extends AttendanceController {
  _FakeAttendance(this._state);
  final AttendanceState _state;
  @override
  AttendanceState build() => _state;
}

AttendanceState _online() => AttendanceState(
  currentShift: _currentShift,
  snapshot: AttendanceSnapshot(
    attendanceStatus: 'CHECKED_IN',
    availabilityStatus: 'AVAILABLE',
    presenceStatus: 'ONLINE',
    sessionId: 1,
    sessionStartedAt: DateTime.now().subtract(
      const Duration(hours: 2, minutes: 14, seconds: 36),
    ),
    scheduledEndAt: DateTime(2026, 8, 2, 18),
  ),
);

AttendanceState _offline() => AttendanceState(currentShift: _currentShift);

Future<void> _pump(
  WidgetTester tester, {
  required AttendanceState attendance,
  AppLocale locale = AppLocale.en,
  Size screen = const Size(390, 900),
}) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final translations = await tester.runAsync(
    () => LocalizationService.load(locale),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        translationsProvider.overrideWith((_) async => translations!),
        attendanceProvider.overrideWith(() => _FakeAttendance(attendance)),
        todaySummaryProvider.overrideWith(
          (_) => const TodaySummary(
            jobsDone: 3,
            hoursWorked: 6.5,
            earnings: 1240,
            rating: 4.8,
          ),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              HomeHeader(onEmergency: () {}),
              ShiftCard(attendance: attendance),
              const TodayCard(),
            ],
          ),
        ),
      ),
    ),
  );
  // Not pumpAndSettle: the shift clock ticks once a second forever.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// The exact payload the device returned at 11:20pm on a shift that ended at
/// 6pm: worked, auto-checked-out, `canCheckIn: false` — and, crucially, no
/// `checkInBlockedReason`, because a finished day is not a blocked one.
AttendanceState _completed() => AttendanceState(
  currentShift: CurrentShiftPayload(
    shift: _shift,
    workDate: '2026-08-02',
    scheduledStartAt: DateTime(2026, 8, 2, 9),
    scheduledEndAt: DateTime(2026, 8, 2, 18),
    allowedCheckinFrom: DateTime(2026, 8, 2, 8, 45),
    canCheckIn: false,
    dayStatus: 'COMPLETED',
    attendanceStatusToday: 'AUTO_CHECKED_OUT',
  ),
  snapshot: const AttendanceSnapshot(
    attendanceStatus: 'NOT_CHECKED_IN',
    availabilityStatus: 'OFF_SHIFT',
    presenceStatus: 'UNAVAILABLE',
  ),
);

/// Assigned, allowed, but the window has not opened yet.
AttendanceState _beforeWindow() => AttendanceState(
  currentShift: CurrentShiftPayload(
    shift: _shift,
    workDate: '2026-08-02',
    scheduledStartAt: DateTime.now().add(const Duration(hours: 3)),
    scheduledEndAt: DateTime.now().add(const Duration(hours: 11)),
    allowedCheckinFrom: DateTime.now().add(const Duration(hours: 2)),
    canCheckIn: true,
  ),
);

void main() {
  testWidgets('a running shift shows how long it has been running', (
    tester,
  ) async {
    await _pump(tester, attendance: _online());

    // The old screen could say "Checked in" but never for how long.
    expect(find.byType(ShiftClock), findsOneWidget);
    expect(find.textContaining('02:14:'), findsOneWidget);
  });

  testWidgets('an idle shift leads with check in and no clock', (tester) async {
    await _pump(tester, attendance: _offline());

    expect(find.byType(ShiftClock), findsNothing);
    expect(find.text('Check in'), findsOneWidget);
  });

  testWidgets('the header carries no sign-out', (tester) async {
    await _pump(tester, attendance: _offline());

    // It lives in Profile and Settings. Next to a panic button it is a hazard.
    expect(find.byIcon(Icons.logout), findsNothing);
    expect(find.byIcon(Icons.sos_rounded), findsOneWidget);
  });

  testWidgets('today leads with the value, not the label', (tester) async {
    await _pump(tester, attendance: _online());

    final earnings = tester.widget<Text>(find.text('₹1240'));
    final label = tester.widget<Text>(find.text('Earned today'));
    expect(
      earnings.style!.fontSize!,
      greaterThan(label.style!.fontSize! * 2),
    );
  });

  testWidgets('a finished shift does not offer check in again', (
    tester,
  ) async {
    await _pump(tester, attendance: _completed());

    expect(_completed().phase, ShiftPhase.complete);
    // The bug: this button stayed live at 11:20pm on a shift that ended at 6.
    expect(find.widgetWithText(FilledButton, 'Check in'), findsNothing);
    expect(find.text('SHIFT DONE'), findsOneWidget);  // the pill uppercases
  });

  testWidgets('before the window opens, check in is shown but dead', (
    tester,
  ) async {
    final state = _beforeWindow();
    await _pump(tester, attendance: state);

    expect(state.phase, ShiftPhase.upcoming);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('the shift card carries the date', (tester) async {
    await _pump(tester, attendance: _offline());

    // Moved off the greeting, onto the thing it is a record of.
    expect(find.textContaining(RegExp(r'^[A-Z][a-z]{2}, \d+ ')), findsOneWidget);
  });

  testWidgets('survives a small screen in Hindi', (tester) async {
    await _pump(
      tester,
      attendance: _online(),
      locale: AppLocale.hi,
      screen: const Size(320, 568),
    );

    expect(tester.takeException(), isNull);
  });
}
