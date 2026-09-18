import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:turanta_xpert/core/network/dio_client.dart';

void main() {
  test('a token that arrives is passed straight through', () async {
    expect(await idTokenOrTimeout(() async => 'abc'), 'abc');
  });

  test('a token that never arrives does not hang the request', () async {
    // Firebase's getIdToken waits on the network with no deadline, and it runs
    // before every request in the app: without this the splash spins forever
    // and nothing reaches the logs.
    final never = Completer<String?>();
    await expectLater(
      idTokenOrTimeout(
        () => never.future,
        timeout: const Duration(milliseconds: 50),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });
}
