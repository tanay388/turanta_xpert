import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../home/presentation/availability_controller.dart';
import '../../sos/presentation/sos_prompt.dart';

import '../../../app/shell/xpert_sections.dart';
import '../../../core/i18n/context_t.dart';
import '../../../core/location/location_service.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../../../core/notifications/push_providers.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../data/jobs_api.dart';
import 'jobs_controller.dart';
import 'widgets/close_without_otp_sheet.dart';
import 'widgets/job_detail_sections.dart';
import 'widgets/job_hero.dart';
import 'widgets/job_otp_field.dart';

/// One job, from a partner standing at the customer's door.
///
/// Laid out like the customer's booking screen: the stage as a headline on the
/// wash, the facts on a white sheet over it, and the code entry pinned to the
/// bottom — the only reason this screen has to be open at the door, so it
/// cannot scroll away.
class JobDetailScreen extends ConsumerStatefulWidget {
  const JobDetailScreen({super.key, required this.jobId});

  final int jobId;

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  final _otpCtrl = TextEditingController();
  bool _busy = false;
  bool _calling = false;
  bool _otpError = false;
  Timer? _pollTimer;
  StreamSubscription<JobLifecycleEvent>? _lifecycleSub;

  @override
  void initState() {
    super.initState();
    // Primary refresh path: a job-lifecycle push (e.g. the customer extended
    // the job) refetches immediately. The poll timer below is just a
    // fallback in case a push is missed.
    _lifecycleSub = ref
        .read(pushNotificationServiceProvider)
        .jobLifecycleEvents
        .listen((event) {
          if (event.bookingId != widget.jobId.toString()) return;
          ref.invalidate(partnerJobProvider(widget.jobId));
        });
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    _pollTimer?.cancel();
    _lifecycleSub?.cancel();
    super.dispose();
  }

  /// Fallback safety net for a missed push — a job-lifecycle event (above)
  /// is the primary refresh trigger while this screen is open.
  void _ensurePolling(bool inProgress) {
    if (inProgress) {
      _pollTimer ??= Timer.periodic(const Duration(minutes: 5), (_) {
        ref.invalidate(partnerJobProvider(widget.jobId));
      });
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  /// Shorter than a check-in's: this only feeds the distance warning below,
  /// and the partner is standing at a door waiting to start.
  Future<Position?> _currentPosition() => ref
      .read(locationServiceProvider)
      .current(timeLimit: const Duration(seconds: 8));

  /// How far from the customer's door a partner can be before starting the job
  /// is worth questioning. Below this, ordinary GPS scatter accounts for the
  /// gap on its own.
  static const _startRadiusMetres = 100.0;

  /// Asks before starting a job the partner does not appear to be standing at.
  ///
  /// Returns whether to go ahead. This is a check against starting the wrong
  /// job, or starting one on the way to it — not an access control, so it
  /// warns rather than blocks, and it stays silent when it has nothing solid
  /// to compare: no fix, or a job with no coordinates. The OTP remains the
  /// actual proof the partner is at the door.
  Future<bool> _confirmStartAtDistance(
    PartnerJob job,
    Position? position,
  ) async {
    final jobLat = job.latitude;
    final jobLng = job.longitude;
    if (position == null || jobLat == null || jobLng == null) return true;

    final metres = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      jobLat,
      jobLng,
    );
    if (metres <= _startRadiusMetres) return true;
    if (!mounted) return false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.wrong_location_outlined,
          color: XpertColors.danger,
        ),
        title: Text(ref.t('jobs.start.far_title')),
        content: Text(
          ref.t('jobs.start.far_body', {'distance': _formatDistance(metres)}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ref.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ref.t('jobs.start.far_confirm')),
          ),
        ],
      ),
    );
    // Dismissing by tapping outside is not consent to start.
    return confirmed ?? false;
  }

  /// Rounded to something a person standing in a street can act on — metres up
  /// to a kilometre, then one decimal of a kilometre.
  String _formatDistance(double metres) {
    if (metres < 1000) {
      return ref.t('common.distance_m', {'value': '${metres.round()}'});
    }
    return ref.t('common.distance_km', {
      'value': (metres / 1000).toStringAsFixed(1),
    });
  }

  Future<void> _closeWithoutOtp(PartnerJob job) async {
    final choice = await showCloseWithoutOtpSheet(context);
    if (choice == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final position = await _currentPosition();
      await ref
          .read(jobsApiProvider)
          .completeWithoutOtp(
            job.id,
            reason: choice.reason,
            note: choice.note,
            latitude: position?.latitude,
            longitude: position?.longitude,
          );
      ref.invalidate(partnerJobProvider(widget.jobId));
      await ref.read(jobsProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ref.t('jobs.complete.success'))));
    } on DioException catch (e) {
      final msg = _dioMessage(e) ?? ref.t('jobs.error.generic');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ref.t('jobs.error.generic'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit(PartnerJob job) async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != JobOtpField.length) {
      setState(() => _otpError = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ref.t('jobs.otp.incomplete'))));
      return;
    }

    setState(() {
      _busy = true;
      _otpError = false;
    });
    try {
      final api = ref.read(jobsApiProvider);
      // Best-effort GPS snapshot for the booking timeline — never blocks the
      // OTP flow if permission/location is unavailable.
      final position = await _currentPosition();
      if (job.isAssigned) {
        // Returning here still runs the finally below, which clears _busy.
        if (!await _confirmStartAtDistance(job, position)) return;
        await api.start(
          job.id,
          otp,
          latitude: position?.latitude,
          longitude: position?.longitude,
        );
      } else if (job.isInProgress) {
        await api.complete(
          job.id,
          otp,
          latitude: position?.latitude,
          longitude: position?.longitude,
        );
      }
      _otpCtrl.clear();
      ref.invalidate(partnerJobProvider(widget.jobId));
      await ref.read(jobsProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            job.isAssigned
                ? ref.t('jobs.start.success')
                : ref.t('jobs.complete.success'),
          ),
        ),
      );
    } on DioException catch (e) {
      final msg = _dioMessage(e) ?? ref.t('jobs.error.generic');
      if (mounted) {
        setState(() => _otpError = true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _otpError = true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ref.t('jobs.error.generic'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _dioMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final message = data['message'];
      if (message is String && message.isNotEmpty) return message;
      if (message is Map && message['message'] is String) {
        return message['message'] as String;
      }
      if (message is List && message.isNotEmpty) {
        return message.first.toString();
      }
    }
    return null;
  }

  Future<void> _openMaps(PartnerJob job) async {
    if (job.latitude == null || job.longitude == null) return;
    await launchUrl(
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=${job.latitude},${job.longitude}',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  /// Nothing is dialled from the handset. The backend asks Exotel to ring this
  /// phone first and then bridge the customer in, so neither side sees the
  /// other's number — which is also why this confirms first: without it the
  /// phone would simply ring a few seconds after a tap that looked inert.
  Future<void> _call() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.call_rounded, color: XpertColors.success),
        title: Text(ref.t('jobs.call.title')),
        content: Text(ref.t('jobs.call.body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ref.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ref.t('jobs.call.confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _calling = true);
    try {
      final result = await ref
          .read(jobsApiProvider)
          .requestCustomerCall(widget.jobId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.t('jobs.call.placed', {'number': result.displayNumber}),
          ),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_dioMessage(e) ?? ref.t('jobs.call.failed'))),
      );
    } finally {
      if (mounted) setState(() => _calling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncJob = ref.watch(partnerJobProvider(widget.jobId));
    ref.listen(partnerJobProvider(widget.jobId), (_, next) {
      _ensurePolling(next.valueOrNull?.isInProgress ?? false);
    });

    return Scaffold(
      // White, not grey: the sheet runs to the bottom of the screen, and the
      // app bar sits on the top of the hero's wash.
      backgroundColor: XpertColors.surface,
      appBar: AppBar(
        backgroundColor: XpertColors.heroTop,
        surfaceTintColor: Colors.transparent,
        title: Text(ref.t('jobs.detail.title')),
        actions: [
          // This screen is pushed over the shell, so the Home header's SOS is
          // unreachable from exactly where a helper is most likely to need it.
          if (ref.watch(attendanceProvider).isCheckedIn)
            IconButton(
              onPressed: () => showSosPrompt(context, ref),
              icon: const Icon(Icons.sos_rounded, color: XpertColors.danger),
              tooltip: ref.t('home.emergency'),
            ),
        ],
      ),
      body: asyncJob.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        // A bare centred sentence with no way to try again.
        error: (_, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            EmptyState(
              icon: Icons.cloud_off_rounded,
              title: ref.t('jobs.error.title'),
              body: ref.t('jobs.error.body'),
              action: FilledButton(
                onPressed: () =>
                    ref.invalidate(partnerJobProvider(widget.jobId)),
                child: Text(ref.t('hub.retry')),
              ),
            ),
          ],
        ),
        data: (job) => Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(partnerJobProvider(widget.jobId));
                  await ref.read(partnerJobProvider(widget.jobId).future);
                },
                child: _Body(
                  job: job,
                  onNavigate: () => _openMaps(job),
                  onCall: _call,
                  calling: _calling,
                ),
              ),
            ),
            if (job.isAssigned || job.isInProgress)
              _ActionFooter(
                job: job,
                controller: _otpCtrl,
                busy: _busy,
                hasError: _otpError,
                onSubmit: () => _submit(job),
                onCloseWithoutOtp: () => _closeWithoutOtp(job),
                onChanged: () {
                  if (_otpError) setState(() => _otpError = false);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.job,
    required this.onNavigate,
    required this.onCall,
    required this.calling,
  });

  final PartnerJob job;
  final VoidCallback onNavigate;
  final VoidCallback? onCall;
  final bool calling;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customer = (job.customerName ?? '').trim();
    final address = job.displayAddress;
    final hasMap = job.latitude != null && job.longitude != null;
    final live = job.isAssigned || job.isInProgress;
    final earning = job.partnerEarning ?? 0;

    final sections = <Widget>[
      JobSection(
        title: ref.t('jobs.detail.section.job'),
        child: JobSummaryRow(job: job),
      ),
      // Calling is bridged server-side and only while the job is live, so the
      // block earns its place when there is a name to show or a call to place
      // — not on a closed job with a masked customer.
      if (customer.isNotEmpty || live)
        JobSection(
          title: ref.t('jobs.customer'),
          child: JobCustomerRow(
            name: customer.isEmpty ? ref.t('jobs.customer') : customer,
            onCall: live ? onCall : null,
            calling: calling,
          ),
        ),
      // Only while there is still somewhere to go. Once a job is closed the
      // address is a customer's home with nothing to do with it.
      if (address.isNotEmpty && !job.isClosed)
        JobSection(
          title: ref.t('jobs.address'),
          child: JobAddressBlock(
            address: address,
            onNavigate: hasMap ? onNavigate : null,
          ),
        ),
      if (job.hasReview)
        JobSection(
          title: ref.t('jobs.review.title'),
          child: JobRatingBlock(job: job),
        ),
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        JobHero(job: job),
        // Pulled up onto the hero so the sheet's corners curve over the wash;
        // the hero reserves the same amount at its bottom.
        Transform.translate(
          offset: const Offset(0, -jobSheetOverlap),
          child: Container(
            decoration: const BoxDecoration(
              color: XpertColors.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(XpertRadius.sheetTop),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(
              XpertSpacing.lg,
              XpertSpacing.xl,
              XpertSpacing.lg,
              XpertSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (job.isCompleted && earning > 0) ...[
                  JobEarnedCard(amount: earning),
                  const SizedBox(height: XpertSpacing.xl),
                ],
                for (var i = 0; i < sections.length; i++) ...[
                  if (i > 0) const JobDivider(),
                  sections[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Pinned. The code entry is the reason the screen is open at the door, and it
/// used to be whatever was left at the bottom of a scroll.
class _ActionFooter extends ConsumerWidget {
  const _ActionFooter({
    required this.job,
    required this.controller,
    required this.busy,
    required this.hasError,
    required this.onSubmit,
    required this.onChanged,
    this.onCloseWithoutOtp,
  });

  final PartnerJob job;
  final TextEditingController controller;
  final bool busy;
  final bool hasError;
  final VoidCallback onSubmit;
  final VoidCallback onChanged;
  final VoidCallback? onCloseWithoutOtp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        XpertSpacing.lg,
        XpertSpacing.md,
        XpertSpacing.lg,
        XpertSpacing.sm + MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(XpertRadius.xl),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A0B1720),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              job.isAssigned
                  ? ref.t('jobs.start.otp_hint')
                  : ref.t('jobs.complete.otp_hint'),
              textAlign: TextAlign.center,
              style: XpertTypography.label.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: XpertSpacing.md),
            JobOtpField(
              controller: controller,
              enabled: !busy,
              hasError: hasError,
              onCompleted: (_) => onChanged(),
            ),
            const SizedBox(height: XpertSpacing.md),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : onSubmit,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(XpertRadius.pill),
                  ),
                ),
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        job.isAssigned
                            ? ref.t('jobs.start.cta')
                            : ref.t('jobs.complete.cta'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            // Offered only once the booked time is up, which is the same line
            // the server draws. Showing it earlier would just be a way to skip
            // the code.
            if (job.isInProgress &&
                DateTime.now().isAfter(job.scheduledEndAt) &&
                onCloseWithoutOtp != null) ...[
              const SizedBox(height: XpertSpacing.xs),
              TextButton(
                onPressed: busy ? null : onCloseWithoutOtp,
                style: TextButton.styleFrom(foregroundColor: XpertColors.muted),
                child: Text(
                  ref.t('jobs.close_no_otp.link'),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
