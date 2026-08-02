import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/shell/xpert_screen_scaffold.dart';
import '../../../app/shell/xpert_sections.dart';
import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../data/jobs_api.dart';
import 'jobs_controller.dart';
import 'widgets/job_cards.dart';

/// The Jobs tab.
///
/// The Active list used to be one flat run of identical rows, so a job running
/// right now sat at the same weight as one booked for Tuesday. It is split
/// into Now and Upcoming, and history is grouped by day instead of repeating
/// the same date down a column.
class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({super.key});

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen> {
  int _tab = 0; // 0 = Active, 1 = History

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(jobsProvider.notifier).refresh();
    });
  }

  void _selectTab(int tab) {
    setState(() => _tab = tab);
    if (tab == 1) {
      // Lazy-load history the first time it's opened.
      ref.read(jobHistoryProvider.notifier).load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(jobsProvider).jobs.length;

    return XpertScreenScaffold(
      title: ref.t('jobs.title'),
      tabs: [
        // The count belongs on the tab: it is the answer to why you'd tap it.
        active > 0
            ? '${ref.t('jobs.tab.active')}  $active'
            : ref.t('jobs.tab.active'),
        ref.t('jobs.tab.history'),
      ],
      selectedTab: _tab,
      onTabSelected: _selectTab,
      child: _tab == 0 ? const _ActiveJobsList() : const _HistoryList(),
    );
  }
}

class _ActiveJobsList extends ConsumerWidget {
  const _ActiveJobsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(jobsProvider);

    if (state.loading && state.jobs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final ongoing = state.jobs.where((j) => j.isInProgress).toList();
    final upcoming = state.jobs.where((j) => !j.isInProgress).toList();

    return RefreshIndicator(
      onRefresh: () => ref.read(jobsProvider.notifier).refresh(),
      child: state.jobs.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                EmptyState(
                  icon: Icons.work_outline_rounded,
                  title: ref.t('jobs.empty.active.title'),
                  body: ref.t('jobs.empty.active.body'),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                XpertSpacing.lg,
                XpertSpacing.lg,
                XpertSpacing.lg,
                XpertSpacing.xxl,
              ),
              children: [
                if (ongoing.isNotEmpty) ...[
                  SectionLabel(ref.t('jobs.section.now')),
                  const SizedBox(height: XpertSpacing.sm),
                  for (final job in ongoing) ...[
                    OngoingJobCard(
                      job: job,
                      onTap: () => context.push('/jobs/${job.id}'),
                    ),
                    const SizedBox(height: XpertSpacing.sm),
                  ],
                  if (upcoming.isNotEmpty)
                    const SizedBox(height: XpertSpacing.md),
                ],
                if (upcoming.isNotEmpty) ...[
                  SectionLabel(ref.t('jobs.section.upcoming')),
                  const SizedBox(height: XpertSpacing.sm),
                  for (final job in upcoming) ...[
                    UpcomingJobCard(
                      job: job,
                      onTap: () => context.push('/jobs/${job.id}'),
                    ),
                    const SizedBox(height: XpertSpacing.sm),
                  ],
                ],
              ],
            ),
    );
  }
}

class _HistoryList extends ConsumerStatefulWidget {
  const _HistoryList();

  @override
  ConsumerState<_HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends ConsumerState<_HistoryList> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      ref.read(jobHistoryProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(jobHistoryProvider);

    if (state.loading && state.jobs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.jobs.isEmpty) {
      return RefreshIndicator(
        onRefresh: () =>
            ref.read(jobHistoryProvider.notifier).load(force: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            EmptyState(
              icon: Icons.receipt_long_rounded,
              title: ref.t('jobs.empty.history.title'),
              body: ref.t('jobs.empty.history.body'),
            ),
          ],
        ),
      );
    }

    // Grouped by day, and each day carries what it paid — a partner scrolling
    // history is usually answering "what did I make", not "what did I do".
    final rows = _groupByDay(state.jobs, ref);

    return RefreshIndicator(
      onRefresh: () => ref.read(jobHistoryProvider.notifier).load(force: true),
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(
          XpertSpacing.lg,
          XpertSpacing.lg,
          XpertSpacing.lg,
          XpertSpacing.xxl,
        ),
        itemCount: rows.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= rows.length) {
            return const Padding(
              padding: EdgeInsets.all(XpertSpacing.md),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          final row = rows[i];
          return switch (row) {
            _DayHeader(:final label, :final earned) => Padding(
              padding: EdgeInsets.only(
                top: i == 0 ? 0 : XpertSpacing.lg,
                bottom: XpertSpacing.sm,
              ),
              child: SectionLabel(
                label,
                trailing: earned <= 0
                    ? null
                    : Text(
                        '₹${earned.toStringAsFixed(0)}',
                        style: XpertTypography.metric.copyWith(fontSize: 13),
                      ),
              ),
            ),
            _JobRow(:final job) => Padding(
              padding: const EdgeInsets.only(bottom: XpertSpacing.sm),
              child: CompletedJobCard(
                job: job,
                onTap: () => context.push('/jobs/${job.id}'),
              ),
            ),
          };
        },
      ),
    );
  }
}

sealed class _Row {
  const _Row();
}

class _DayHeader extends _Row {
  const _DayHeader(this.label, this.earned);
  final String label;
  final double earned;
}

class _JobRow extends _Row {
  const _JobRow(this.job);
  final PartnerJob job;
}

List<_Row> _groupByDay(List<PartnerJob> jobs, WidgetRef ref) {
  final rows = <_Row>[];
  final now = DateTime.now();
  DateTime? currentDay;
  var pendingIndex = -1;
  var dayEarned = 0.0;

  for (final job in jobs) {
    final start = job.scheduledStartAt.toLocal();
    final day = DateTime(start.year, start.month, start.day);

    if (currentDay == null || !DateUtils.isSameDay(currentDay, day)) {
      if (pendingIndex >= 0) {
        rows[pendingIndex] =
            _DayHeader((rows[pendingIndex] as _DayHeader).label, dayEarned);
      }
      currentDay = day;
      dayEarned = 0;
      rows.add(_DayHeader(_dayLabel(day, now, ref), 0));
      pendingIndex = rows.length - 1;
    }

    dayEarned += job.partnerEarning ?? 0;
    rows.add(_JobRow(job));
  }

  // The last day's total is only known once its jobs have all been counted.
  if (pendingIndex >= 0) {
    rows[pendingIndex] =
        _DayHeader((rows[pendingIndex] as _DayHeader).label, dayEarned);
  }
  return rows;
}

String _dayLabel(DateTime day, DateTime now, WidgetRef ref) {
  if (DateUtils.isSameDay(day, now)) return ref.t('jobs.day.today');
  if (DateUtils.isSameDay(day, now.subtract(const Duration(days: 1)))) {
    return ref.t('jobs.day.yesterday');
  }
  return DateFormat('EEE, d MMM').format(day);
}
