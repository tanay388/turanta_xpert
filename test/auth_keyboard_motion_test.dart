import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turanta_xpert/app/theme.dart';
import 'package:turanta_xpert/core/i18n/app_locale.dart';
import 'package:turanta_xpert/core/i18n/locale_provider.dart';
import 'package:turanta_xpert/core/i18n/localization_service.dart';
import 'package:turanta_xpert/features/auth/presentation/login_screen.dart';
import 'package:turanta_xpert/features/auth/presentation/widgets/auth_shell.dart';

/// Drives the keyboard inset the way the platform does, so the shell sees a
/// real MediaQuery change rather than a rebuild with a different widget.
class _Host extends StatefulWidget {
  const _Host({super.key});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  double inset = 0;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        viewInsets: EdgeInsets.only(bottom: inset),
      ),
      child: const LoginScreen(),
    );
  }
}

double _heroOpacity(WidgetTester tester) {
  final fade = tester.widget<FadeTransition>(
    find.descendant(
      of: find.byKey(heroFadeKey),
      matching: find.byType(FadeTransition),
    ),
  );
  return fade.opacity.value;
}

void main() {
  testWidgets('the Xpert fades out as the keyboard arrives, and comes back', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final translations = await tester.runAsync(
      () => LocalizationService.load(AppLocale.en),
    );

    final key = GlobalKey<_HostState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          translationsProvider.overrideWith((_) async => translations!),
        ],
        child: MaterialApp.router(
          theme: XpertTheme.light,
          routerConfig: GoRouter(
            routes: [GoRoute(path: '/', builder: (_, _) => _Host(key: key))],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_heroOpacity(tester), 1);

    key.currentState!.setState(() => key.currentState!.inset = 280);
    await tester.pump();

    // She is still there the frame the keyboard arrives — the complaint was
    // that she vanished between one frame and the next.
    expect(find.byKey(heroFadeKey), findsOneWidget);
    expect(_heroOpacity(tester), 1);

    await tester.pump(const Duration(milliseconds: 130));
    final midway = _heroOpacity(tester);
    expect(midway, greaterThan(0));
    expect(midway, lessThan(1));

    await tester.pumpAndSettle();
    expect(_heroOpacity(tester), 0);
    // Gone from view, still in the tree, so coming back is a fade and not a
    // rebuild that decodes the image again.
    expect(find.byKey(heroFadeKey), findsOneWidget);

    key.currentState!.setState(() => key.currentState!.inset = 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));
    final returning = _heroOpacity(tester);
    expect(returning, greaterThan(0));
    expect(returning, lessThan(1));

    await tester.pumpAndSettle();
    expect(_heroOpacity(tester), 1);
  });
}
