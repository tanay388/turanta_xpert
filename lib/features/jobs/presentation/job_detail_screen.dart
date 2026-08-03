import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/shell/xpert_sections.dart';
import '../../../core/i18n/context_t.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../../../core/notifications/push_providers.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../data/jobs_api.dart';
import 'jobs_controller.dart';
import 'live_job_timer.dart';
import 'widgets/job_otp_field.dart';
import 'widgets/job_service_icon.dart';

/// One job, from a partner standing at the customer's door.
///
/// The code entry — the only reason this screen has to be open at that moment
/// — used to be the last thing in a scrolling list, so on a long job it was
/// below the fold. It is now pinned to the bottom and cannot scroll away.
///
/// The customer's phone number was printed as text with nothing to tap. A
/// partner outside a locked gate needs to call, not read out digits into
/// another app.
class JobDetailScreen extends ConsumerStatefulWidget {
  const JobDetailScreen({super.key, required this.jobId});

  final int jobId;

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  final _otpCtrl = TextEditingController();
  bool _busy = false;
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

  Future<Position?> _currentPosition() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      return null;
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

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'\s+'), ''));
    if (!await launchUrl(uri) && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ref.t('jobs.call.failed'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncJob = ref.watch(partnerJobProvider(widget.jobId));
    ref.listen(partnerJobProvider(widget.jobId), (_, next) {
      _ensurePolling(next.valueOrNull?.isInProgress ?? false);
    });

    return Scaffold(
      backgroundColor: XpertColors.background,
      appBar: AppBar(title: Text(ref.t('jobs.detail.title'))),
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
  });

  final PartnerJob job;
  final VoidCallback onNavigate;
  final Future<void> Function(String phone) onCall;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone = (job.customerPhone ?? '').trim();
    final customer = (job.customerName ?? '').trim();
    final address = job.displayAddress;
    final hasMap = job.latitude != null && job.longitude != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        XpertSpacing.lg,
        XpertSpacing.lg,
        XpertSpacing.lg,
        XpertSpacing.xl,
      ),
      children: [
        Row(
          children: [
            JobServiceIcon(job: job, size: 46),
            const SizedBox(width: XpertSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    job.serviceName ?? ref.t('jobs.service_fallback'),
                    style: XpertTypography.title.copyWith(fontSize: 19),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DateFormat(
                      'EEE, d MMM · h:mm a',
                    ).format(job.scheduledStartAt.toLocal()),
                    style: XpertTypography.caption.copyWith(fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: XpertSpacing.md),
        // The detail screen never said what state the job was in — only the
        // list did.
        Align(alignment: Alignment.centerLeft, child: _StatusPill(job: job)),
        if (job.isInProgress) ...[
          const SizedBox(height: XpertSpacing.lg),
          LiveJobTimerCard(job: job),
        ],
        const SizedBox(height: XpertSpacing.xl),
        // Duration and earning are numbers, so they are set as numbers rather
        // than as two more label-over-value rows in a list of five.
        Row(
          children: [
            Expanded(
              child: _Metric(
                label: ref.t('jobs.duration'),
                value: '${_hours(job.durationMinutes)} hr',
              ),
            ),
            const SizedBox(width: XpertSpacing.sm),
            Expanded(
              child: _Metric(
                label: (job.isCompleted || job.isNoShow)
                    ? ref.t('jobs.earning.label')
                    : ref.t('jobs.earning.estimated_label'),
                value: (job.partnerEarning ?? 0) <= 0
                    ? '—'
                    : '₹${job.partnerEarning!.toStringAsFixed(0)}',
              ),
            ),
          ],
        ),
        if (customer.isNotEmpty || phone.isNotEmpty) ...[
          const SizedBox(height: XpertSpacing.xl),
          SectionLabel(ref.t('jobs.customer')),
          const SizedBox(height: XpertSpacing.sm),
          _ContactCard(
            name: customer.isEmpty ? ref.t('jobs.customer') : customer,
            phone: phone,
            onCall: phone.isEmpty ? null : () => onCall(phone),
          ),
        ],
        // Only while there is still somewhere to go. Once a job is closed the
        // address is a customer's home address with nothing to do with it —
        // and Copy and Navigate below it are actions on a finished job.
        if (address.isNotEmpty && !job.isClosed) ...[
          const SizedBox(height: XpertSpacing.xl),
          SectionLabel(ref.t('jobs.address')),
          const SizedBox(height: XpertSpacing.sm),
          _AddressCard(
            address: address,
            onNavigate: hasMap ? onNavigate : null,
          ),
        ],
        if (job.hasReview) ...[
          const SizedBox(height: XpertSpacing.xl),
          SectionLabel(ref.t('jobs.review.title')),
          const SizedBox(height: XpertSpacing.sm),
          _ReviewCard(job: job),
        ],
      ],
    );
  }
}

String _hours(int minutes) {
  final hours = minutes / 60;
  return hours % 1 == 0 ? hours.toStringAsFixed(0) : hours.toStringAsFixed(1);
}

class _StatusPill extends ConsumerWidget {
  const _StatusPill({required this.job});

  final PartnerJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (color, key) = job.isInProgress
        ? (XpertColors.primary, 'jobs.status.in_progress')
        : job.isCompleted
        ? (XpertColors.success, 'jobs.status.completed')
        : job.isNoShow
        ? (XpertColors.danger, 'jobs.status.no_show')
        : (const Color(0xFFF57C00), 'jobs.status.assigned');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(XpertRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          // Flexible even inside an Align: the pill is sized by its label, and
          // a translated status can be wider than the screen.
          Flexible(
            child: Text(
              ref.t(key).toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(XpertSpacing.md),
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
        border: Border.all(color: XpertColors.border.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: XpertTypography.metric.copyWith(fontSize: 20),
            maxLines: 1,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: XpertTypography.caption.copyWith(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// The customer, with a way to reach them. Calling was the gap: the number was
/// printed as text and a partner at a locked gate had to retype it.
class _ContactCard extends ConsumerWidget {
  const _ContactCard({
    required this.name,
    required this.phone,
    required this.onCall,
  });

  final String name;
  final String phone;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(XpertSpacing.md),
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
        border: Border.all(color: XpertColors.border.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: XpertColors.secondary,
              borderRadius: BorderRadius.circular(XpertRadius.md),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.person_outline_rounded,
              size: 20,
              color: XpertColors.onSurface,
            ),
          ),
          const SizedBox(width: XpertSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: XpertTypography.label.copyWith(fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    phone,
                    style: XpertTypography.metric.copyWith(
                      fontSize: 13,
                      color: XpertColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onCall != null) ...[
            const SizedBox(width: XpertSpacing.sm),
            Semantics(
              button: true,
              label: ref.t('jobs.call'),
              child: Material(
                color: XpertColors.success.withValues(alpha: 0.12),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onCall,
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.call_rounded,
                      size: 20,
                      color: XpertColors.success,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddressCard extends ConsumerWidget {
  const _AddressCard({required this.address, required this.onNavigate});

  final String address;
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(XpertSpacing.md),
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
        border: Border.all(color: XpertColors.border.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 18,
                color: XpertColors.primary,
              ),
              const SizedBox(width: XpertSpacing.sm),
              Expanded(
                child: Text(
                  address,
                  style: XpertTypography.body.copyWith(
                    fontSize: 14.5,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: XpertSpacing.md),
          Row(
            children: [
              // Copyable, because half the time the destination gets pasted
              // into whichever maps app the partner actually uses.
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: address));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ref.t('jobs.address.copied'))),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 17),
                  // Neither button ellipsises on its own, and both labels grow
                  // in Hindi and Marathi.
                  label: Text(
                    ref.t('jobs.address.copy'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (onNavigate != null) ...[
                const SizedBox(width: XpertSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onNavigate,
                    icon: const Icon(Icons.directions_rounded, size: 17),
                    label: Text(
                      ref.t('jobs.navigate'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends ConsumerWidget {
  const _ReviewCard({required this.job});

  final PartnerJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = (job.reviewNote ?? '').trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(XpertSpacing.md),
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
        border: Border.all(color: XpertColors.border.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Icon(
                    i <= (job.reviewStars ?? 0)
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 20,
                    color: i <= (job.reviewStars ?? 0)
                        ? const Color(0xFFF5A623)
                        : XpertColors.border,
                  ),
                ),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: XpertSpacing.sm),
            Text(
              note,
              style: XpertTypography.body.copyWith(
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
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
  });

  final PartnerJob job;
  final TextEditingController controller;
  final bool busy;
  final bool hasError;
  final VoidCallback onSubmit;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        XpertSpacing.lg,
        XpertSpacing.md,
        XpertSpacing.lg,
        XpertSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: XpertColors.surface,
        border: Border(top: BorderSide(color: Color(0xFFE8EDF1))),
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
              style: XpertTypography.caption.copyWith(fontSize: 13),
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
              height: 54,
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : onSubmit,
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
          ],
        ),
      ),
    );
  }
}
