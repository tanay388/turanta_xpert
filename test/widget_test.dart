import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:turanta_xpert/app/app.dart';

void main() {
  testWidgets('Turanta Xpert app builds', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: TurantaXpertApp()),
    );
    await tester.pump();
    expect(find.text('Turanta Xpert'), findsWidgets);
    // Settle splash boot delay / async auth so no pending timers remain.
    await tester.pump(const Duration(seconds: 2));
  });
}
