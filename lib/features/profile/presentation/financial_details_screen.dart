import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../app/shell/xpert_list_group.dart';
import '../../../app/shell/xpert_sections.dart';
import '../../../core/i18n/context_t.dart';
import '../../../core/models/partner_user.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../../auth/data/partner_auth_api.dart';

/// The partner's bank and tax details, read-only.
///
/// Editing has been taken out of the app. `PATCH /partner/kyc/financial` still
/// exists and admins still use it — what is gone is the partner-facing form,
/// so a partner who spots a wrong account number now has to go through support
/// rather than change it themselves. The screen says so plainly instead of
/// leaving them looking for a button that is not there.
///
/// Almost everything here arrives masked from the server, which is the whole
/// character of the screen: it is for confirming that the details on file are
/// the right ones, not for reading them back out.
class FinancialDetailsScreen extends ConsumerStatefulWidget {
  const FinancialDetailsScreen({super.key});

  @override
  ConsumerState<FinancialDetailsScreen> createState() =>
      _FinancialDetailsScreenState();
}

class _FinancialDetailsScreenState
    extends ConsumerState<FinancialDetailsScreen> {
  PartnerKyc? _kyc;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _kyc = await ref.read(partnerAuthApiProvider).getKyc();
    } catch (_) {
      // The raw exception was previously printed onto the screen.
      _error = ref.t('financial.error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kyc = _kyc;

    return Scaffold(
      backgroundColor: XpertColors.background,
      appBar: AppBar(title: Text(ref.t('financial.title'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  XpertSpacing.lg,
                  XpertSpacing.md,
                  XpertSpacing.lg,
                  XpertSpacing.xxl,
                ),
                children: [
                  if (_error != null)
                    EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: ref.t('financial.error'),
                      body: ref.t('financial.error.body'),
                    )
                  else ...[
                    if (kyc?.status != null) ...[
                      _KycStatus(status: kyc!.status!),
                      const SizedBox(height: XpertSpacing.xl),
                    ],
                    SectionLabel(ref.t('financial.bank')),
                    const SizedBox(height: XpertSpacing.sm),
                    XpertListGroup(
                      children: [
                        _Detail(
                          label: ref.t('financial.holder'),
                          value: kyc?.accountHolderName,
                        ),
                        _Detail(
                          label: ref.t('financial.bank_name'),
                          value: kyc?.bankName,
                        ),
                        _Detail(
                          label: ref.t('financial.account_no'),
                          value: kyc?.bankAccountNumberMasked,
                          numeric: true,
                        ),
                        _Detail(
                          label: ref.t('financial.ifsc'),
                          value: kyc?.bankIfsc,
                          numeric: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: XpertSpacing.xl),
                    SectionLabel(ref.t('financial.identity')),
                    const SizedBox(height: XpertSpacing.sm),
                    XpertListGroup(
                      children: [
                        _Detail(
                          label: ref.t('financial.pan'),
                          value: kyc?.panNumberMasked,
                          numeric: true,
                        ),
                        _Detail(
                          label: ref.t('financial.aadhaar'),
                          value: kyc?.aadhaarNumberMasked,
                          numeric: true,
                        ),
                        _Detail(
                          label: ref.t('financial.gst'),
                          value: kyc?.gstNumber,
                          numeric: true,
                        ),
                        _Detail(
                          label: ref.t('financial.uan'),
                          value: kyc?.uanNumber,
                          numeric: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: XpertSpacing.lg),
                    // With no edit button, this is the answer to "these are
                    // wrong, now what" — the screen has to give it.
                    _Note(text: ref.t('financial.readonly_note')),
                  ],
                ],
              ),
            ),
    );
  }
}

/// One label→value pair. Values that are account or document numbers are set
/// in tabular figures so masked digits line up down the column.
class _Detail extends StatelessWidget {
  const _Detail({required this.label, this.value, this.numeric = false});

  final String label;
  final String? value;
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    final missing = value == null || value!.trim().isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: XpertSpacing.md,
        vertical: XpertSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: XpertTypography.caption.copyWith(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: XpertSpacing.sm),
          Flexible(
            child: Text(
              missing ? '—' : value!,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: numeric && !missing
                  ? XpertTypography.metric.copyWith(fontSize: 14.5)
                  : XpertTypography.label.copyWith(
                      fontSize: 14.5,
                      color: missing ? XpertColors.border : null,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where the partner's verification stands. It was on the payload all along
/// and this screen never showed it, which left "why can't I be paid" with no
/// answer anywhere in the app.
class _KycStatus extends ConsumerWidget {
  const _KycStatus({required this.status});

  final PartnerKycStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (color, icon, key) = switch (status) {
      PartnerKycStatus.approved => (
        XpertColors.success,
        Icons.verified_rounded,
        'financial.kyc.approved',
      ),
      PartnerKycStatus.rejected => (
        XpertColors.danger,
        Icons.error_outline_rounded,
        'financial.kyc.rejected',
      ),
      PartnerKycStatus.draft || PartnerKycStatus.submitted => (
        const Color(0xFFF57C00),
        Icons.hourglass_bottom_rounded,
        'financial.kyc.pending',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(XpertSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(XpertRadius.lg),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: XpertSpacing.sm),
          Expanded(
            child: Text(
              ref.t(key),
              style: XpertTypography.label.copyWith(
                fontSize: 14,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lock_outline_rounded, size: 15, color: XpertColors.muted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: XpertTypography.caption.copyWith(fontSize: 12, height: 1.45),
          ),
        ),
      ],
    );
  }
}
