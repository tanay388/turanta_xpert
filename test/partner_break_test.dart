import 'package:flutter_test/flutter_test.dart';
import 'package:turanta_xpert/core/models/partner_break.dart';

void main() {
  test('reads the partner break the server sends', () {
    final b = PartnerBreak.fromJson({
      'startTime': '13:00',
      'durationMinutes': 30,
    })!;
    expect(b.hasWindow, isTrue);
    expect(b.windowLabel, '13:00 – 13:30');
  });

  test('a break with no fixed time has no window but keeps its length', () {
    final b = PartnerBreak.fromJson({
      'startTime': null,
      'durationMinutes': 45,
    })!;
    expect(b.hasWindow, isFalse);
    expect(b.windowLabel, isNull);
    expect(b.durationMinutes, 45);
    expect(b.stateAt(DateTime(2026, 9, 16, 13)), BreakWindowState.none);
  });

  test('no break from the server is no break, not a made-up default', () {
    expect(PartnerBreak.fromJson(null), isNull);
    expect(
      PartnerBreak.fromJson({'maxPerSession': 1, 'maxDurationMinutes': 45}),
      isNull,
    );
  });

  test('an overnight break wraps past midnight', () {
    const b = PartnerBreak(startTime: '23:45', durationMinutes: 30);
    expect(b.windowLabel, '23:45 – 00:15');
    expect(b.stateAt(DateTime(2026, 9, 17, 0, 5)), BreakWindowState.now);
    expect(b.stateAt(DateTime(2026, 9, 16, 22)), BreakWindowState.upcoming);
    expect(b.stateAt(DateTime(2026, 9, 17, 2)), BreakWindowState.passed);
  });
}
