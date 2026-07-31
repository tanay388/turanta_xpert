import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../data/jobs_api.dart';
import 'jobs_controller.dart';
import 'live_job_timer.dart';

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
    return Scaffold(
      backgroundColor: XpertColors.background,
      appBar: AppBar(title: Text(ref.t('jobs.title'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              XpertSpacing.lg,
              XpertSpacing.md,
              XpertSpacing.lg,
              XpertSpacing.xs,
            ),
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text(ref.t('jobs.tab.active'))),
                ButtonSegment(value: 1, label: Text(ref.t('jobs.tab.history'))),
              ],
              selected: {_tab},
              showSelectedIcon: false,
              onSelectionChanged: (s) => _selectTab(s.first),
            ),
          ),
          Expanded(
            child: _tab == 0 ? const _ActiveJobsList() : const _HistoryList(),
          ),
        ],
      ),
    );
  }
}

class _ActiveJobsList extends ConsumerWidget {
  const _ActiveJobsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(jobsProvider);
    return RefreshIndicator(
      onRefresh: () => ref.read(jobsProvider.notifier).refresh(),
      child: state.loading && state.jobs.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.jobs.isEmpty
              ? _EmptyState(message: ref.t('jobs.empty'))
              : ListView.separated(
                  padding: const EdgeInsets.all(XpertSpacing.lg),
                  itemCount: state.jobs.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: XpertSpacing.sm),
                  itemBuilder: (context, i) {
                    final job = state.jobs[i];
                    return _JobTile(
                      job: job,
                      onTap: () => context.push('/jobs/${job.id}'),
                    );
                  },
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
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 300) {
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
        child: _EmptyState(message: ref.t('jobs.history.empty')),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(jobHistoryProvider.notifier).load(force: true),
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.all(XpertSpacing.lg),
        itemCount: state.jobs.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: XpertSpacing.sm),
        itemBuilder: (context, i) {
          if (i >= state.jobs.length) {
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
          final job = state.jobs[i];
          return _HistoryTile(
            job: job,
            onTap: () => context.push('/jobs/${job.id}'),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(
          Icons.work_outline,
          size: 48,
          color: XpertColors.muted.withValues(alpha: 0.6),
        ),
        const SizedBox(height: XpertSpacing.md),
        Text(
          message,
          textAlign: TextAlign.center,
          style: XpertTypography.body.copyWith(color: XpertColors.muted),
        ),
      ],
    );
  }
}

class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({required this.job, required this.onTap});
  final PartnerJob job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noShow = job.isNoShow;
    final statusLabel = noShow
        ? ref.t('jobs.status.no_show')
        : ref.t('jobs.status.completed');
    final statusColor = noShow ? XpertColors.danger : XpertColors.success;
    final earning = job.partnerEarning;

    return Material(
      color: XpertColors.surface,
      borderRadius: BorderRadius.circular(XpertRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(XpertRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(XpertSpacing.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: XpertColors.secondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  noShow ? Icons.event_busy_rounded : Icons.check_rounded,
                  color: XpertColors.onSurface,
                ),
              ),
              const SizedBox(width: XpertSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.serviceName ?? ref.t('jobs.service_fallback'),
                      style: XpertTypography.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      DateFormat('EEE, d MMM · h:mm a')
                          .format(job.scheduledStartAt.toLocal()),
                      style: XpertTypography.caption,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(XpertRadius.pill),
                      ),
                      child: Text(
                        statusLabel,
                        style: XpertTypography.caption.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (job.hasReview) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 14, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 2),
                          Text(
                            '${job.reviewStars}/5',
                            style: XpertTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: XpertSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    ref.t('jobs.earning.label'),
                    style: XpertTypography.caption.copyWith(fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (earning == null || earning <= 0)
                        ? '—'
                        : '₹${earning.toStringAsFixed(0)}',
                    style: XpertTypography.label.copyWith(
                      fontSize: 16,
                      color: noShow ? XpertColors.muted : XpertColors.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobTile extends ConsumerWidget {
  const _JobTile({required this.job, required this.onTap});
  final PartnerJob job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusLabel = job.isInProgress
        ? ref.t('jobs.status.in_progress')
        : ref.t('jobs.status.assigned');
    final statusColor =
        job.isInProgress ? XpertColors.primary : XpertColors.success;

    return Material(
      color: XpertColors.surface,
      borderRadius: BorderRadius.circular(XpertRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(XpertRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(XpertSpacing.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: XpertColors.secondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.cleaning_services_rounded,
                  color: XpertColors.onSurface,
                ),
              ),
              const SizedBox(width: XpertSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.serviceName ?? ref.t('jobs.service_fallback'),
                      style: XpertTypography.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    if (job.isInProgress)
                      LiveJobTimerCard(job: job, compact: true)
                    else
                      Text(
                        DateFormat('EEE, d MMM · h:mm a')
                            .format(job.scheduledStartAt.toLocal()),
                        style: XpertTypography.caption,
                      ),
                    if (job.displayAddress.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        job.displayAddress.replaceAll('\n', ' · '),
                        style: XpertTypography.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: XpertSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(XpertRadius.pill),
                ),
                child: Text(
                  statusLabel,
                  style: XpertTypography.caption.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
