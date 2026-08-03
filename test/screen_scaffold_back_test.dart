import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turanta_xpert/app/shell/xpert_screen_scaffold.dart';
import 'package:turanta_xpert/app/theme.dart';

Future<GoRouter> _pump(WidgetTester tester) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => context.push('/pushed'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/pushed',
        builder: (_, _) => const XpertScreenScaffold(
          title: 'Refer & Earn',
          child: SizedBox.shrink(),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(routerConfig: router, theme: XpertTheme.light),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('a root screen shows no back button', (tester) async {
    await _pump(tester);

    // The bottom-nav tabs have nothing to go back to.
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
  });

  testWidgets('a pushed screen grows one by itself', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Refer & Earn'), findsOneWidget);
    // Refer a friend adopted this scaffold as a pushed route and inherited no
    // way out — on iOS, with no system back button, a dead end.
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
  });

  testWidgets('and it actually goes back', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
    expect(find.text('Refer & Earn'), findsNothing);
  });
}
