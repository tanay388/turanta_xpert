import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turanta_xpert/app/theme.dart';
import 'package:turanta_xpert/app/shell/xpert_sections.dart';
import 'package:turanta_xpert/core/i18n/app_locale.dart';
import 'package:turanta_xpert/core/i18n/locale_provider.dart';
import 'package:turanta_xpert/core/i18n/localization_service.dart';
import 'package:turanta_xpert/features/jobs/data/jobs_api.dart';
import 'package:turanta_xpert/features/jobs/presentation/jobs_controller.dart';
import 'package:turanta_xpert/features/jobs/presentation/jobs_screen.dart';
import 'package:turanta_xpert/features/jobs/presentation/live_job_timer.dart';
import 'package:turanta_xpert/features/jobs/presentation/widgets/job_cards.dart';
import 'package:turanta_xpert/features/leave/presentation/widgets/leave_balance.dart';
import 'package:turanta_xpert/features/referral/presentation/widgets/referral_funnel.dart';
import 'package:turanta_xpert/features/leave/data/leave_api.dart';
import 'package:turanta_xpert/features/leave/presentation/leave_controller.dart';
import 'package:turanta_xpert/features/leave/presentation/leave_screen.dart';
import 'package:turanta_xpert/features/referral/data/referral_api.dart';
import 'package:turanta_xpert/features/referral/presentation/referral_controller.dart';
import 'package:turanta_xpert/features/referral/presentation/referral_screen.dart';

PartnerJob _job({
  required int id,
  required String status,
  int offsetMinutes = 0,
  double? earning,
  int? stars,
}) {
  final start = DateTime.now().add(Duration(minutes: offsetMinutes));
  return PartnerJob(
    id: id,
    status: status,
    scheduledStartAt: start,
    scheduledEndAt: start.add(const Duration(hours: 2)),
    durationMinutes: 120,
    startedAt: status == 'IN_PROGRESS'
        ? DateTime.now().subtract(const Duration(minutes: 40))
        : null,
    serviceName: 'Deep house cleaning',
    serviceCategoryName: 'Cleaning',
    customerName: 'Aanya Sharma',
    addressLabel: 'Flat 4B, Apex Tower\nPowai, Mumbai',
    partnerEarning: earning,
    reviewStars: stars,
  );
}

/// Real controllers with their fetches stubbed out — the screens call refresh
/// from initState, and a live Dio would replace the seeded state with an error.
class _FakeJobs extends JobsController {
  _FakeJobs(JobsState seed) : super(JobsApi(Dio())) {
    state = seed;
  }
  @override
  Future<void> refresh({bool silent = false}) async {}
  @override
  void startPolling({Duration interval = const Duration(seconds: 30)}) {}
}


Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  required List<Override> overrides,
  AppLocale locale = AppLocale.en,
  Size screenSize = const Size(390, 1000),
}) async {
  tester.view.physicalSize = screenSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final translations = await tester.runAsync(
    () => LocalizationService.load(locale),
  );

  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => screen),
      GoRoute(
        path: '/jobs/:id',
        builder: (_, _) => const Scaffold(body: Text('detail')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        translationsProvider.overrideWith((_) async => translations!),
        ...overrides,
      ],
      child: MaterialApp.router(routerConfig: router, theme: XpertTheme.light),
    ),
  );
  // Not pumpAndSettle: the live job card ticks its clock every second.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 60));
}

List<Override> _jobsWith(List<PartnerJob> jobs) => [
  jobsProvider.overrideWith((ref) => _FakeJobs(JobsState(jobs: jobs))),
];

List<Override> _leaveWith(LeaveSummary summary) => [
  leaveProvider.overrideWith(() => _FakeLeave(LeaveState(summary: summary))),
];

const _summary = LeaveSummary(
  balanceDays: 10,
  pendingDays: 2,
  availableDays: 4,
  lapsedDaysTotal: 1,
  lastLapsedDays: 1,
  canApplyPaid: true,
  canApplyUnpaid: false,
  maxUnpaidDays: 5,
  maxAdvanceDays: 30,
  today: '2026-08-02',
  maxDate: '2026-09-01',
  requests: [
    LeaveRequestItem(
      id: 1,
      startDate: '2026-08-10',
      endDate: '2026-08-12',
      daysCount: 3,
      status: 'PENDING',
    ),
  ],
);

void main() {
  group('jobs', () {
    testWidgets('splits running work from what is merely booked', (
      tester,
    ) async {
      await _pump(
        tester,
        const JobsScreen(),
        overrides: _jobsWith([
          _job(id: 1, status: 'IN_PROGRESS'),
          _job(id: 2, status: 'ASSIGNED', offsetMinutes: 180),
        ]),
      );

      // One flat list gave a job running right now the same weight as one
      // booked for Tuesday.
      expect(find.text('NOW'), findsOneWidget);
      expect(find.text('UPCOMING'), findsOneWidget);
      expect(find.byType(OngoingJobCard), findsOneWidget);
      expect(find.byType(UpcomingJobCard), findsOneWidget);
    });

    testWidgets('a running job carries its full clock, not a caption', (
      tester,
    ) async {
      await _pump(
        tester,
        const JobsScreen(),
        overrides: _jobsWith([_job(id: 1, status: 'IN_PROGRESS')]),
      );

      final timer = tester.widget<LiveJobTimerCard>(
        find.byType(LiveJobTimerCard),
      );
      expect(timer.compact, isFalse);
    });

    testWidgets('an empty list says what will appear and what to do', (
      tester,
    ) async {
      await _pump(tester, const JobsScreen(), overrides: _jobsWith([]));

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.textContaining('Stay checked in'), findsOneWidget);
    });

    testWidgets('survives a small screen in Hindi', (tester) async {
      await _pump(
        tester,
        const JobsScreen(),
        overrides: _jobsWith([
          _job(id: 1, status: 'IN_PROGRESS'),
          _job(id: 2, status: 'ASSIGNED', offsetMinutes: 180),
        ]),
        locale: AppLocale.hi,
        screenSize: const Size(320, 640),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('leave', () {
    testWidgets('the balance meter has real height', (tester) async {
      await _pump(
        tester,
        const LeaveScreen(),
        overrides: _leaveWith(_summary),
      );

      // A childless ColoredBox takes constraints.smallest, and a Row's cross
      // axis is loose — so this bar once rendered at zero height, invisible
      // and silent. Nothing but a measurement catches that.
      final bar = find.descendant(
        of: find.byType(LeaveBalance),
        matching: find.byType(ClipRRect),
      );
      expect(tester.getSize(bar.first).height, 8);
      expect(tester.getSize(bar.first).width, greaterThan(100));
    });

    testWidgets('reasons are tappable, not hidden in a dropdown', (
      tester,
    ) async {
      await _pump(
        tester,
        const LeaveScreen(),
        overrides: _leaveWith(_summary),
      );

      await tester.tap(find.text('Ask for leave'));
      await tester.pumpAndSettle();

      // Five fixed options, all visible — one tap instead of tap, scroll, tap.
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      for (final reason in ['Sick / Medical', 'Personal work', 'Other']) {
        expect(find.text(reason), findsOneWidget);
      }
    });

    testWidgets('dates are one range behind one picker', (tester) async {
      await _pump(
        tester,
        const LeaveScreen(),
        overrides: _leaveWith(_summary),
      );

      await tester.tap(find.text('Ask for leave'));
      await tester.pumpAndSettle();

      // It used to be a From tile and a To tile, each opening its own modal.
      expect(find.text('DATES'), findsOneWidget);
      expect(find.textContaining('1 day(s) selected'), findsOneWidget);
    });
  });

  group('referral', () {
    testWidgets('the code leads, and copy actually copies', (tester) async {
      var copied = '';
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await _pump(
        tester,
        const ReferralScreen(),
        overrides: [
          referralProvider.overrideWith(() => _FakeReferral(_referralState)),
        ],
      );

      expect(find.text('K7RM2P'), findsOneWidget);

      // The old chip showed a copy icon and opened the share sheet instead.
      await tester.tap(find.byIcon(Icons.copy_rounded));
      await tester.pumpAndSettle();
      expect(copied, 'K7RM2P');
    });

    testWidgets('each invite shows where it sits in the funnel', (
      tester,
    ) async {
      await _pump(
        tester,
        const ReferralScreen(),
        overrides: [
          referralProvider.overrideWith(() => _FakeReferral(_referralState)),
        ],
      );

      expect(find.byType(ReferralFunnel), findsNWidgets(3));
      expect(stageIndexOf('INVITED'), 0);
      expect(stageIndexOf('REWARDED'), 3);
    });

    testWidgets('a zero total is not set in hero type', (tester) async {
      await _pump(
        tester,
        const ReferralScreen(),
        overrides: [
          referralProvider.overrideWith(
            () => _FakeReferral(
              const ReferralState(
                summary: ReferralSummary(
                  code: 'K7RM2P',
                  shareLink: '',
                  rewardAmount: 500,
                  milestoneJobs: 10,
                  totalEarned: 0,
                  active: [],
                  lapsed: [],
                ),
              ),
            ),
          ),
        ],
      );

      // Greeting a new partner with their own ₹0 is a discouragement.
      expect(find.text('₹0'), findsNothing);
      expect(find.byType(EmptyState), findsOneWidget);
    });
  });
}

const _referralState = ReferralState(
  summary: ReferralSummary(
    code: 'K7RM2P',
    shareLink: 'https://turanta.app/r/K7RM2P',
    rewardAmount: 500,
    milestoneJobs: 10,
    totalEarned: 1500,
    active: [
      ReferralInvite(
        id: 1,
        refereeDisplayName: 'Ramesh Kumar',
        status: 'ACTIVE',
        rewardAmount: 500,
        stepsCompleted: 7,
      ),
      ReferralInvite(
        id: 2,
        status: 'INVITED',
        rewardAmount: 500,
        stepsCompleted: 0,
      ),
      ReferralInvite(
        id: 3,
        refereeDisplayName: 'Sunita Devi',
        status: 'REWARDED',
        rewardAmount: 500,
        stepsCompleted: 10,
      ),
    ],
    lapsed: [],
  ),
);

class _FakeReferral extends ReferralController {
  _FakeReferral(this._seed);
  final ReferralState _seed;
  @override
  ReferralState build() => _seed;
  @override
  Future<void> refresh() async {}
}

class _FakeLeave extends LeaveController {
  _FakeLeave(this._seed);
  final LeaveState _seed;
  @override
  LeaveState build() => _seed;
  @override
  Future<void> refresh() async {}
}
