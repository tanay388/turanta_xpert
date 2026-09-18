import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turanta_xpert/app/shell/xpert_shell_scaffold.dart';
import 'package:turanta_xpert/app/theme.dart';
import 'package:turanta_xpert/core/i18n/app_locale.dart';
import 'package:turanta_xpert/core/i18n/locale_provider.dart';
import 'package:turanta_xpert/core/i18n/localization_service.dart';
import 'package:turanta_xpert/core/theme/xpert_tokens.dart';
import 'package:turanta_xpert/features/jobs/data/jobs_api.dart';
import 'package:turanta_xpert/features/jobs/presentation/jobs_controller.dart';

class _FakeJobs extends JobsController {
  _FakeJobs(JobsState seed) : super(JobsApi(Dio())) {
    state = seed;
  }
  @override
  Future<void> refresh({bool silent = false}) async {}
  @override
  void startPolling({Duration interval = const Duration(seconds: 30)}) {}
}

PartnerJob _job(int id, String status) {
  final start = DateTime.now().add(Duration(hours: id));
  return PartnerJob(
    id: id,
    status: status,
    scheduledStartAt: start,
    scheduledEndAt: start.add(const Duration(hours: 1)),
    durationMinutes: 60,
    serviceName: 'Cleaning',
  );
}

const _tabs = ['/home', '/jobs', '/leave', '/paisa', '/target'];

Future<void> _pump(
  WidgetTester tester, {
  List<PartnerJob> jobs = const [],
  int tab = 0,
  Size size = const Size(390, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final translations = await tester.runAsync(
    () => LocalizationService.load(AppLocale.en),
  );
  final router = GoRouter(
    initialLocation: _tabs[tab],
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => XpertShellScaffold(navigationShell: shell),
        branches: [
          for (final path in _tabs)
            StatefulShellBranch(
              routes: [GoRoute(path: path, builder: (_, _) => Text(path))],
            ),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        translationsProvider.overrideWith((_) async => translations!),
        jobsProvider.overrideWith((ref) => _FakeJobs(JobsState(jobs: jobs))),
      ],
      child: MaterialApp.router(routerConfig: router, theme: XpertTheme.light),
    ),
  );
  await tester.pumpAndSettle();
}

TextStyle _labelStyle(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style!;

void main() {
  testWidgets('the tab you are on is the one that is coloured', (tester) async {
    await _pump(tester, tab: 2);

    // Selected and unselected icons were both black on a pale pill you had to
    // look for, so the bar never said where you were.
    expect(_labelStyle(tester, 'Leaves').color, XpertColors.heroAccent);
    expect(_labelStyle(tester, 'Jobs').color, XpertColors.muted);
    expect(
      _labelStyle(tester, 'Leaves').fontWeight!.value,
      greaterThan(_labelStyle(tester, 'Jobs').fontWeight!.value),
    );
  });

  testWidgets('the jobs tab counts the work waiting', (tester) async {
    await _pump(
      tester,
      jobs: [_job(1, 'ASSIGNED'), _job(2, 'IN_PROGRESS'), _job(3, 'COMPLETED')],
    );

    // Assigned and running count; a finished job is not work waiting.
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('no badge when there is nothing to do', (tester) async {
    await _pump(tester, jobs: [_job(3, 'COMPLETED')]);

    expect(find.byType(Badge), findsNothing);
  });

  testWidgets('tapping a tab moves to it', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Paisa'));
    await tester.pumpAndSettle();

    expect(find.text('/paisa'), findsOneWidget);
  });
}
