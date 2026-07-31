import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/i18n/context_t.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../../../core/notifications/push_providers.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../data/jobs_api.dart';
import 'jobs_controller.dart';
import 'live_job_timer.dart';

class JobDetailScreen extends ConsumerStatefulWidget {
  const JobDetailScreen({super.key, required this.jobId});
  final int jobId;

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  final _otpCtrl = TextEditingController();
  bool _busy = false;
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

  Future<void> _submit(PartnerJob job) async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.t('jobs.otp.incomplete'))),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final api = ref.read(jobsApiProvider);
      if (job.isAssigned) {
        await api.start(job.id, otp);
      } else if (job.isInProgress) {
        await api.complete(job.id, otp);
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.t('jobs.error.generic'))),
        );
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
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${job.latitude},${job.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
        error: (_, _) => Center(child: Text(ref.t('jobs.error.generic'))),
        data: (job) {
          final when = DateFormat('EEE, d MMM · h:mm a')
              .format(job.scheduledStartAt.toLocal());
          final hours = (job.durationMinutes / 60).toStringAsFixed(1);
          final canAct = job.isAssigned || job.isInProgress;

          return ListView(
            padding: const EdgeInsets.all(XpertSpacing.lg),
            children: [
              Text(
                job.serviceName ?? ref.t('jobs.service_fallback'),
                style: XpertTypography.title.copyWith(fontSize: 22),
              ),
              const SizedBox(height: XpertSpacing.xs),
              Text(when, style: XpertTypography.body.copyWith(
                color: XpertColors.muted,
              )),
              if (job.isInProgress) ...[
                const SizedBox(height: XpertSpacing.md),
                LiveJobTimerCard(job: job),
              ],
              const SizedBox(height: XpertSpacing.md),
              _InfoCard(
                children: [
                  _InfoRow(
                    icon: Icons.schedule,
                    label: ref.t('jobs.duration'),
                    value: '$hours hr',
                  ),
                  if (job.partnerEarning != null)
                    _InfoRow(
                      icon: Icons.account_balance_wallet_outlined,
                      label: (job.isCompleted || job.isNoShow)
                          ? ref.t('jobs.earning.label')
                          : ref.t('jobs.earning.estimated_label'),
                      value: job.partnerEarning! <= 0
                          ? '—'
                          : '₹${job.partnerEarning!.toStringAsFixed(0)}',
                    ),
                  if (job.displayAddress.isNotEmpty)
                    _InfoRow(
                      icon: Icons.location_on_outlined,
                      label: ref.t('jobs.address'),
                      value: job.displayAddress,
                    ),
                  if ((job.customerName ?? '').trim().isNotEmpty)
                    _InfoRow(
                      icon: Icons.person_outline,
                      label: ref.t('jobs.customer'),
                      value: job.customerName!.trim(),
                    ),
                  if ((job.customerPhone ?? '').trim().isNotEmpty)
                    _InfoRow(
                      icon: Icons.phone_outlined,
                      label: ref.t('jobs.phone'),
                      value: job.customerPhone!.trim(),
                    ),
                ],
              ),
              if (job.hasReview) ...[
                const SizedBox(height: XpertSpacing.md),
                _InfoCard(
                  children: [
                    _InfoRow(
                      icon: Icons.star_rounded,
                      label: ref.t('jobs.review.title'),
                      value: '${job.reviewStars}/5',
                    ),
                    if ((job.reviewNote ?? '').trim().isNotEmpty)
                      _InfoRow(
                        icon: Icons.chat_bubble_outline,
                        label: ref.t('jobs.review.note'),
                        value: job.reviewNote!.trim(),
                      ),
                  ],
                ),
              ],
              if (job.latitude != null && job.longitude != null) ...[
                const SizedBox(height: XpertSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => _openMaps(job),
                  icon: const Icon(Icons.directions),
                  label: Text(ref.t('jobs.navigate')),
                ),
              ],
              if (canAct) ...[
                const SizedBox(height: XpertSpacing.xl),
                Text(
                  job.isAssigned
                      ? ref.t('jobs.start.otp_hint')
                      : ref.t('jobs.complete.otp_hint'),
                  style: XpertTypography.label,
                ),
                const SizedBox(height: XpertSpacing.sm),
                TextField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••',
                    filled: true,
                    fillColor: XpertColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(XpertRadius.md),
                    ),
                  ),
                  style: XpertTypography.title.copyWith(
                    letterSpacing: 8,
                    fontSize: 28,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: XpertSpacing.md),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _busy ? null : () => _submit(job),
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            job.isAssigned
                                ? ref.t('jobs.start.cta')
                                : ref.t('jobs.complete.cta'),
                          ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(XpertSpacing.md),
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.md),
        border: Border.all(color: XpertColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: XpertSpacing.md),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: XpertColors.muted),
        const SizedBox(width: XpertSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: XpertTypography.caption),
              Text(value, style: XpertTypography.body),
            ],
          ),
        ),
      ],
    );
  }
}
