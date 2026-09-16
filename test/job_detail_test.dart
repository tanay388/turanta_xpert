import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turanta_xpert/app/theme.dart';
import 'package:turanta_xpert/core/i18n/app_locale.dart';
import 'package:turanta_xpert/core/i18n/locale_provider.dart';
import 'package:turanta_xpert/core/i18n/localization_service.dart';
import 'package:turanta_xpert/core/notifications/push_notification_service.dart';
import 'package:turanta_xpert/core/notifications/push_providers.dart';
import 'package:turanta_xpert/features/jobs/data/jobs_api.dart';
import 'package:turanta_xpert/features/jobs/presentation/job_detail_screen.dart';
import 'package:turanta_xpert/features/jobs/presentation/jobs_controller.dart';
import 'package:turanta_xpert/features/jobs/presentation/widgets/job_otp_field.dart';

PartnerJob _job({
  String status = 'ASSIGNED',
  String? phone = '+919876543210',
  double? lat = 19.076,
  int? stars,
  Duration startsIn = const Duration(hours: 2),
}) {
  final start = DateTime.now().add(startsIn);
  return PartnerJob(
    id: 1,
    status: status,
    scheduledStartAt: start,
    scheduledEndAt: start.add(const Duration(hours: 2)),
    durationMinutes: 120,
    startedAt: status == 'IN_PROGRESS'
        ? DateTime.now().subtract(const Duration(minutes: 30))
        : null,
    serviceName: 'Deep house cleaning',
    serviceCategoryName: 'Cleaning',
    customerName: 'Aanya Sharma',
    customerPhone: phone,
    addressLabel: 'Flat 4B, Apex Tower\nPowai, Mumbai',
    latitude: lat,
    longitude: lat == null ? null : 72.87,
    partnerEarning: 260,
    reviewStars: stars,
  );
}

class _FakeLocale extends LocaleController {
  @override
  AppLocale build() => AppLocale.en;
}

class _FakeJobsApi extends JobsApi {
  _FakeJobsApi() : super(Dio());
}

Future<void> _pump(
  WidgetTester tester, {
  required PartnerJob job,
  AppLocale locale = AppLocale.en,
  Size size = const Size(390, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final translations = await tester.runAsync(
    () => LocalizationService.load(locale),
  );
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const JobDetailScreen(jobId: 1)),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        translationsProvider.overrideWith((_) async => translations!),
        localeProvider.overrideWith(_FakeLocale.new),
        jobsApiProvider.overrideWith((_) => _FakeJobsApi()),
        // Constructing the real service needs Firebase; this one just never
        // emits a lifecycle event.
        pushNotificationServiceProvider.overrideWith(
          (_) => PushNotificationService(registerToken: (_) async {}),
        ),
        partnerJobProvider(1).overrideWith((_) => job),
      ],
      child: MaterialApp.router(routerConfig: router, theme: XpertTheme.light),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 60));
}

void main() {
  testWidgets('the code entry is pinned, not left at the end of a scroll', (
    tester,
  ) async {
    await _pump(tester, job: _job());

    // It is the reason the screen is open at the customer's door.
    final field = tester.getRect(find.byType(JobOtpField));
    final screen = tester.getRect(find.byType(Scaffold));
    expect(field.bottom, lessThanOrEqualTo(screen.bottom));
    expect(field.top, greaterThan(screen.height * 0.5));
  });

  testWidgets('the customer can be called, not just read', (tester) async {
    await _pump(tester, job: _job());

    // The number used to be printed as text with nothing to tap.
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
  });

  testWidgets('calling no longer depends on holding the number', (
    tester,
  ) async {
    await _pump(tester, job: _job(phone: null));

    // The call is bridged server-side, so a masked job still offers one.
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
  });

  testWidgets('the customer number is never printed', (tester) async {
    await _pump(tester, job: _job());

    expect(find.text('+919876543210'), findsNothing);
    expect(
      find.text('Number hidden — calls connect through Turanta'),
      findsOneWidget,
    );
  });

  testWidgets('a finished job offers no call', (tester) async {
    await _pump(tester, job: _job(status: 'COMPLETED'));

    expect(find.byIcon(Icons.call_rounded), findsNothing);
  });

  testWidgets('the address can be copied as well as navigated to', (
    tester,
  ) async {
    await _pump(tester, job: _job());

    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Navigate'), findsOneWidget);
  });

  testWidgets('navigate is hidden without coordinates', (tester) async {
    await _pump(tester, job: _job(lat: null));

    expect(find.text('Navigate'), findsNothing);
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('the job says what state it is in', (tester) async {
    await _pump(tester, job: _job(status: 'IN_PROGRESS'));

    // It used to be a caption-sized pill; the stage is the headline now.
    expect(find.text('Job in progress'), findsOneWidget);
  });

  testWidgets('an upcoming job leads with when it starts', (tester) async {
    await _pump(tester, job: _job());

    expect(find.textContaining('Starts in'), findsOneWidget);
    expect(find.text('Running late'), findsNothing);
  });

  testWidgets('a job past its start says the partner is running late', (
    tester,
  ) async {
    await _pump(tester, job: _job(startsIn: const Duration(minutes: -10)));

    expect(find.text('Running late'), findsOneWidget);
    expect(find.textContaining('Starts in'), findsNothing);
  });

  testWidgets('a finished job leads with what it earned, once', (tester) async {
    await _pump(tester, job: _job(status: 'COMPLETED'));

    expect(find.text('Earned for this job'), findsOneWidget);
    expect(find.text('₹260'), findsOneWidget);
  });

  testWidgets('a no-show does not promise the booked estimate', (tester) async {
    await _pump(tester, job: _job(status: 'NO_SHOW'));

    // The server fills partnerEarning with the booked estimate when nothing
    // was settled, and a no-show settles nothing.
    expect(find.text('₹260'), findsNothing);
    expect(find.text('Marked as a no-show'), findsOneWidget);
  });

  testWidgets('a finished job offers no code entry', (tester) async {
    await _pump(tester, job: _job(status: 'COMPLETED', stars: 4));

    expect(find.byType(JobOtpField), findsNothing);
    expect(find.text('Job completed'), findsOneWidget);
    // Four filled stars out of five.
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
    expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
  });

  testWidgets('a finished job drops the address entirely', (tester) async {
    await _pump(tester, job: _job(status: 'COMPLETED'));

    // There is nowhere left to go, and Copy/Navigate would be actions on a
    // job that is already over.
    expect(find.text('ADDRESS'), findsNothing);
    expect(find.text('Navigate'), findsNothing);
    expect(find.text('Copy'), findsNothing);
    expect(find.textContaining('Apex Tower'), findsNothing);
  });

  testWidgets('a no-show drops it too', (tester) async {
    await _pump(tester, job: _job(status: 'NO_SHOW'));

    expect(find.text('ADDRESS'), findsNothing);
  });

  testWidgets('a live job keeps the address', (tester) async {
    await _pump(tester, job: _job(status: 'IN_PROGRESS'));

    expect(find.text('ADDRESS'), findsOneWidget);
    expect(find.text('Navigate'), findsOneWidget);
  });

  testWidgets('survives a small screen in Hindi', (tester) async {
    await _pump(
      tester,
      job: _job(status: 'IN_PROGRESS'),
      locale: AppLocale.hi,
      size: const Size(320, 640),
    );

    expect(tester.takeException(), isNull);
  });
}
