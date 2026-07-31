import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/jobs_api.dart';

class JobsState {
  const JobsState({
    this.jobs = const [],
    this.loading = false,
    this.error,
  });

  final List<PartnerJob> jobs;
  final bool loading;
  final String? error;

  /// Next job to work: in-progress first, else soonest assigned.
  PartnerJob? get nextJob {
    if (jobs.isEmpty) return null;
    final inProgress = jobs.where((j) => j.isInProgress).toList();
    if (inProgress.isNotEmpty) return inProgress.first;
    return jobs.first;
  }

  JobsState copyWith({
    List<PartnerJob>? jobs,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return JobsState(
      jobs: jobs ?? this.jobs,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class JobsController extends StateNotifier<JobsState> {
  JobsController(this._api) : super(const JobsState());

  final JobsApi _api;
  Timer? _pollTimer;

  Future<void> refresh({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(loading: true, clearError: true);
    }
    try {
      final jobs = await _api.list();
      state = state.copyWith(jobs: jobs, loading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: silent ? state.error : e.toString(),
      );
    }
  }

  /// Poll for newly assigned jobs while the partner is on home / checked in.
  void startPolling({Duration interval = const Duration(seconds: 30)}) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) {
      unawaited(refresh(silent: true));
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}

final jobsProvider =
    StateNotifierProvider<JobsController, JobsState>((ref) {
  final controller = JobsController(ref.watch(jobsApiProvider));
  ref.onDispose(controller.stopPolling);
  return controller;
});

final partnerJobProvider =
    FutureProvider.autoDispose.family<PartnerJob, int>((ref, id) async {
  return ref.watch(jobsApiProvider).get(id);
});

// ─── Completed-job history (paginated) ─────────────────────────

class JobHistoryState {
  const JobHistoryState({
    this.jobs = const [],
    this.loading = false,
    this.loadingMore = false,
    this.loaded = false,
    this.nextCursor,
    this.error,
  });

  final List<PartnerJob> jobs;
  final bool loading;
  final bool loadingMore;
  final bool loaded;
  final int? nextCursor;
  final String? error;

  bool get hasMore => nextCursor != null;
}

class JobHistoryController extends StateNotifier<JobHistoryState> {
  JobHistoryController(this._api) : super(const JobHistoryState());
  final JobsApi _api;

  /// Loads the first page. Safe to call repeatedly; use [force] to reload.
  Future<void> load({bool force = false}) async {
    if (state.loading) return;
    if (state.loaded && !force) return;
    state = const JobHistoryState(loading: true);
    try {
      final page = await _api.history();
      state = JobHistoryState(
        jobs: page.items,
        nextCursor: page.nextCursor,
        loaded: true,
      );
    } catch (e) {
      state = JobHistoryState(loaded: true, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || state.loading || state.nextCursor == null) return;
    state = JobHistoryState(
      jobs: state.jobs,
      nextCursor: state.nextCursor,
      loaded: true,
      loadingMore: true,
    );
    try {
      final page = await _api.history(cursor: state.nextCursor);
      state = JobHistoryState(
        jobs: [...state.jobs, ...page.items],
        nextCursor: page.nextCursor,
        loaded: true,
      );
    } catch (e) {
      state = JobHistoryState(
        jobs: state.jobs,
        nextCursor: state.nextCursor,
        loaded: true,
        error: e.toString(),
      );
    }
  }
}

final jobHistoryProvider =
    StateNotifierProvider<JobHistoryController, JobHistoryState>((ref) {
  return JobHistoryController(ref.watch(jobsApiProvider));
});
