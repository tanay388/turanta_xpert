import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../data/referral_api.dart';
import 'referral_controller.dart';

/// Pick a work profile, optionally name/phone, then share the referral link.
class InviteSheet extends ConsumerStatefulWidget {
  const InviteSheet({
    super.key,
    required this.code,
    required this.workProfiles,
  });

  final String code;
  final List<ReferralWorkProfile> workProfiles;

  @override
  ConsumerState<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<InviteSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  ReferralWorkProfile? _selected;
  String _query = '';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ReferralWorkProfile> get _filtered {
    if (_query.trim().isEmpty) return widget.workProfiles;
    final q = _query.trim().toLowerCase();
    return widget.workProfiles
        .where((p) => p.name.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(referralProvider);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        XpertSpacing.lg,
        XpertSpacing.lg,
        XpertSpacing.lg,
        XpertSpacing.lg + bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              ref.t('referral.invite.title'),
              style: XpertTypography.title.copyWith(fontSize: 22),
            ),
            const SizedBox(height: XpertSpacing.lg),
            Text(
              ref.t('referral.invite.work_profile'),
              style: XpertTypography.caption,
            ),
            const SizedBox(height: XpertSpacing.xs),
            TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: ref.t('referral.invite.search_hint'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(XpertRadius.md),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: XpertSpacing.md,
                ),
              ),
            ),
            const SizedBox(height: XpertSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: _filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: XpertSpacing.md,
                      ),
                      child: Text(
                        ref.t('referral.invite.no_profiles'),
                        style: XpertTypography.caption,
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filtered.length,
                      itemBuilder: (context, i) {
                        final profile = _filtered[i];
                        final isSelected = _selected?.id == profile.id;
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => setState(() => _selected = profile),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: XpertSpacing.xs,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_unchecked,
                                    size: 20,
                                    color: isSelected
                                        ? XpertColors.primary
                                        : XpertColors.muted,
                                  ),
                                  const SizedBox(width: XpertSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      profile.name,
                                      style: isSelected
                                          ? XpertTypography.body.copyWith(
                                              fontWeight: FontWeight.w700)
                                          : XpertTypography.body,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: XpertSpacing.md),
            Text(
              ref.t('referral.invite.select_contact'),
              style: XpertTypography.caption,
            ),
            const SizedBox(height: XpertSpacing.xs),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: ref.t('referral.invite.name_hint'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(XpertRadius.md),
                ),
              ),
            ),
            const SizedBox(height: XpertSpacing.sm),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: ref.t('referral.invite.phone_hint'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(XpertRadius.md),
                ),
              ),
            ),
            if (state.error != null) ...[
              const SizedBox(height: XpertSpacing.sm),
              Text(
                state.error!,
                style: XpertTypography.caption.copyWith(color: XpertColors.danger),
              ),
            ],
            const SizedBox(height: XpertSpacing.lg),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: state.isSubmitting ? null : _submit,
                icon: state.isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: XpertColors.onPrimary,
                        ),
                      )
                    : const Icon(Icons.share_rounded),
                label: Text(
                  ref.t('referral.invite.send'),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final shareLink = await ref.read(referralProvider.notifier).invite(
          name: _nameCtrl.text,
          phone: _phoneCtrl.text,
          serviceId: _selected?.id,
        );
    if (!mounted) return;

    final link = shareLink != null && shareLink.isNotEmpty
        ? shareLink
        : 'https://myturanta.com/refer/${widget.code}';
    final message = ref.t('referral.share.message', {
      'code': widget.code,
      'link': link,
    });

    await SharePlus.instance.share(ShareParams(text: message));
    if (mounted) Navigator.pop(context, shareLink != null);
  }
}
