import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../app/shell/xpert_list_group.dart';
import '../../../app/shell/xpert_sections.dart';
import '../../../core/i18n/context_t.dart';
import '../../../core/models/partner_user.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../../auth/data/partner_auth_api.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/widgets/auth_text_field.dart';
import 'widgets/kyc_chrome.dart';
import 'widgets/kyc_inputs.dart';

/// Verification: six steps between signing in and being allowed to work.
///
/// Every field was a bare `TextField` whose only guard was a keyboard hint, so
/// nothing stopped letters in an account number until the step was validated;
/// documents reported "Uploaded" with no way to see what had been uploaded;
/// and the review step was a wall of text with no way back to fix a line.
///
/// The one field the API accepts that this wizard never collected is GST — it
/// was declared on the DTO, stored on the entity and displayed on Financial
/// details, where it could only ever read "—".
class KycWizardScreen extends HookConsumerWidget {
  const KycWizardScreen({super.key});

  static const _steps = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = useState(0);
    final busy = useState(false);
    final error = useState<String?>(null);

    final fullName = useTextEditingController();
    final dob = useState<DateTime?>(null);
    final aadhaarFront = useState<String?>(null);
    final aadhaarBack = useState<String?>(null);
    final aadhaarNumber = useTextEditingController();
    final panFront = useState<String?>(null);
    final panBack = useState<String?>(null);
    final panNumber = useTextEditingController();
    final selfie = useState<String?>(null);
    // Stored values are private storage keys, which cannot be rendered
    // directly — keep the short-lived signed preview links separately, keyed
    // by the stored key.
    final previews = useState<Map<String, String>>(const {});
    final account = useTextEditingController();
    final accountConfirm = useTextEditingController();
    final ifsc = useTextEditingController();
    final bankName = useTextEditingController();
    final holderName = useTextEditingController();
    final uan = useTextEditingController();
    final gst = useTextEditingController();

    final stepNames = [
      ref.t('kyc.step.personal'),
      ref.t('kyc.step.aadhaar'),
      ref.t('kyc.step.pan'),
      ref.t('kyc.step.selfie'),
      ref.t('kyc.step.bank'),
      ref.t('kyc.step.review'),
    ];

    Future<void> pickAndUpload(ValueNotifier<String?> target) async {
      final picker = ImagePicker();
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: XpertColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(XpertRadius.sheetTop),
          ),
        ),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: XpertSpacing.sm),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_rounded,
                  color: XpertColors.primary,
                ),
                title: Text(ref.t('kyc.picker.camera')),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: XpertColors.primary,
                ),
                title: Text(ref.t('kyc.picker.gallery')),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: XpertSpacing.sm),
            ],
          ),
        ),
      );
      if (source == null) return;

      final file = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (file == null) return;

      busy.value = true;
      error.value = null;
      try {
        final result = await ref
            .read(partnerAuthApiProvider)
            .uploadKycImage(file.path);
        target.value = result.key;
        if (result.previewUrl != null) {
          previews.value = {...previews.value, result.key: result.previewUrl!};
        }
      } on ApiException catch (e) {
        error.value = e.message;
      } finally {
        busy.value = false;
      }
    }

    bool validate(int which) {
      error.value = null;
      switch (which) {
        case 0:
          if (fullName.text.trim().length < 2) {
            error.value = ref.t('kyc.error.name_required');
            return false;
          }
          if (dob.value == null) {
            error.value = ref.t('kyc.error.dob_required');
            return false;
          }
          return true;
        case 1:
          if (aadhaarFront.value == null || aadhaarBack.value == null) {
            error.value = ref.t('kyc.error.aadhaar_photos_required');
            return false;
          }
          if (KycInputs.bare(aadhaarNumber.text).length != 12) {
            error.value = ref.t('kyc.error.aadhaar_invalid');
            return false;
          }
          return true;
        case 2:
          if (panFront.value == null || panBack.value == null) {
            error.value = ref.t('kyc.error.pan_photos_required');
            return false;
          }
          // Length 10 was the only check; ABCDE1234F is the actual shape.
          if (!KycInputs.panPattern.hasMatch(panNumber.text.trim())) {
            error.value = ref.t('kyc.error.pan_invalid');
            return false;
          }
          return true;
        case 3:
          if (selfie.value == null) {
            error.value = ref.t('kyc.error.selfie_required');
            return false;
          }
          return true;
        case 4:
          if (account.text.trim().length < 8) {
            error.value = ref.t('kyc.error.account_invalid');
            return false;
          }
          if (account.text.trim() != accountConfirm.text.trim()) {
            error.value = ref.t('kyc.error.account_mismatch');
            return false;
          }
          if (!KycInputs.ifscPattern.hasMatch(ifsc.text.trim())) {
            error.value = ref.t('kyc.error.ifsc_invalid');
            return false;
          }
          if (bankName.text.trim().isEmpty) {
            error.value = ref.t('kyc.error.bank_name_required');
            return false;
          }
          if (holderName.text.trim().isEmpty) {
            error.value = ref.t('kyc.error.holder_name_required');
            return false;
          }
          // Optional, but if given it has to be the right shape — otherwise
          // it silently fails verification later.
          final gstValue = gst.text.trim();
          if (gstValue.isNotEmpty && !KycInputs.gstPattern.hasMatch(gstValue)) {
            error.value = ref.t('kyc.error.gst_invalid');
            return false;
          }
          final uanValue = uan.text.trim();
          if (uanValue.isNotEmpty && uanValue.length != 12) {
            error.value = ref.t('kyc.error.uan_invalid');
            return false;
          }
          return true;
        default:
          return true;
      }
    }

    Future<void> submit() async {
      // Every step is re-checked, not just the last one — a partner can jump
      // back from review, clear a field and return without passing through.
      for (var i = 0; i < _steps - 1; i++) {
        if (!validate(i)) {
          step.value = i;
          return;
        }
      }

      busy.value = true;
      error.value = null;
      try {
        await ref.read(partnerAuthApiProvider).upsertKyc({
          'fullName': fullName.text.trim(),
          'dateOfBirth': DateFormat('yyyy-MM-dd').format(dob.value!),
          'aadhaarFrontUrl': aadhaarFront.value,
          'aadhaarBackUrl': aadhaarBack.value,
          'aadhaarNumber': KycInputs.bare(aadhaarNumber.text),
          'panFrontUrl': panFront.value,
          'panBackUrl': panBack.value,
          'panNumber': panNumber.text.trim(),
          'selfieUrl': selfie.value,
          'bankAccountNumber': account.text.trim(),
          'bankIfsc': ifsc.text.trim(),
          'bankName': bankName.text.trim(),
          'accountHolderName': holderName.text.trim(),
          if (uan.text.trim().isNotEmpty) 'uanNumber': uan.text.trim(),
          if (gst.text.trim().isNotEmpty) 'gstNumber': gst.text.trim(),
          'submit': true,
        });
        await ref.read(authProvider.notifier).refreshProfile();
        if (context.mounted) context.go('/pending-approval');
      } on ApiException catch (e) {
        error.value = e.message;
      } finally {
        busy.value = false;
      }
    }

    Future<void> next() async {
      if (!validate(step.value)) return;
      if (step.value < _steps - 1) {
        step.value += 1;
      } else {
        await submit();
      }
    }

    Future<void> confirmSignOut() async {
      // Abandoning verification mid-way was one unguarded tap in the app bar.
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ref.t('kyc.signout.title')),
          content: Text(ref.t('kyc.signout.body')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ref.t('leave.no')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: XpertColors.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ref.t('kyc.cta.sign_out')),
            ),
          ],
        ),
      );
      if (ok == true) await ref.read(authProvider.notifier).signOut();
    }

    Widget body() {
      switch (step.value) {
        case 0:
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Intro(text: ref.t('kyc.intro.personal')),
              AuthTextField(
                label: ref.t('kyc.field.full_name'),
                controller: fullName,
                hint: ref.t('kyc.field.full_name_hint'),
                enabled: !busy.value,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: XpertSpacing.md),
              _DobField(
                value: dob.value,
                enabled: !busy.value,
                onPick: (picked) => dob.value = picked,
              ),
            ],
          );
        case 1:
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Intro(text: ref.t('kyc.intro.aadhaar')),
              KycDocTile(
                label: ref.t('kyc.doc.aadhaar_front'),
                hint: ref.t('kyc.doc.tap_to_upload'),
                storageKey: aadhaarFront.value,
                previewUrl: previews.value[aadhaarFront.value],
                enabled: !busy.value,
                onTap: () => pickAndUpload(aadhaarFront),
              ),
              const SizedBox(height: XpertSpacing.sm),
              KycDocTile(
                label: ref.t('kyc.doc.aadhaar_back'),
                hint: ref.t('kyc.doc.tap_to_upload'),
                storageKey: aadhaarBack.value,
                previewUrl: previews.value[aadhaarBack.value],
                enabled: !busy.value,
                onTap: () => pickAndUpload(aadhaarBack),
              ),
              const SizedBox(height: XpertSpacing.lg),
              AuthTextField(
                label: ref.t('kyc.field.aadhaar_number'),
                controller: aadhaarNumber,
                hint: ref.t('kyc.field.aadhaar_hint'),
                enabled: !busy.value,
                keyboardType: TextInputType.number,
                inputFormatters: KycInputs.aadhaar,
              ),
            ],
          );
        case 2:
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Intro(text: ref.t('kyc.intro.pan')),
              KycDocTile(
                label: ref.t('kyc.doc.pan_front'),
                hint: ref.t('kyc.doc.tap_to_upload'),
                storageKey: panFront.value,
                previewUrl: previews.value[panFront.value],
                enabled: !busy.value,
                onTap: () => pickAndUpload(panFront),
              ),
              const SizedBox(height: XpertSpacing.sm),
              KycDocTile(
                label: ref.t('kyc.doc.pan_back'),
                hint: ref.t('kyc.doc.tap_to_upload'),
                storageKey: panBack.value,
                previewUrl: previews.value[panBack.value],
                enabled: !busy.value,
                onTap: () => pickAndUpload(panBack),
              ),
              const SizedBox(height: XpertSpacing.lg),
              AuthTextField(
                label: ref.t('kyc.field.pan_number'),
                controller: panNumber,
                hint: ref.t('kyc.field.pan_hint'),
                enabled: !busy.value,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: KycInputs.pan,
              ),
            ],
          );
        case 3:
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Intro(text: ref.t('kyc.intro.selfie')),
              KycDocTile(
                label: ref.t('kyc.doc.selfie'),
                hint: ref.t('kyc.doc.selfie_hint'),
                storageKey: selfie.value,
                previewUrl: previews.value[selfie.value],
                enabled: !busy.value,
                onTap: () => pickAndUpload(selfie),
              ),
            ],
          );
        case 4:
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Intro(text: ref.t('kyc.intro.bank')),
              AuthTextField(
                label: ref.t('kyc.field.account_number'),
                controller: account,
                hint: ref.t('kyc.field.account_hint'),
                enabled: !busy.value,
                keyboardType: TextInputType.number,
                inputFormatters: KycInputs.account,
              ),
              const SizedBox(height: XpertSpacing.md),
              AuthTextField(
                label: ref.t('kyc.field.account_number_confirm'),
                controller: accountConfirm,
                hint: ref.t('kyc.field.account_hint'),
                enabled: !busy.value,
                keyboardType: TextInputType.number,
                inputFormatters: KycInputs.account,
              ),
              const SizedBox(height: XpertSpacing.md),
              AuthTextField(
                label: ref.t('kyc.field.ifsc'),
                controller: ifsc,
                hint: ref.t('kyc.field.ifsc_hint'),
                enabled: !busy.value,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: KycInputs.ifsc,
              ),
              const SizedBox(height: XpertSpacing.md),
              AuthTextField(
                label: ref.t('kyc.field.bank_name'),
                controller: bankName,
                hint: ref.t('kyc.field.bank_name_hint'),
                enabled: !busy.value,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: XpertSpacing.md),
              AuthTextField(
                label: ref.t('kyc.field.holder_name'),
                controller: holderName,
                hint: ref.t('kyc.field.holder_name_hint'),
                enabled: !busy.value,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: XpertSpacing.xl),
              SectionLabel(ref.t('kyc.section.optional')),
              const SizedBox(height: XpertSpacing.sm),
              AuthTextField(
                label: ref.t('kyc.field.uan'),
                controller: uan,
                hint: ref.t('kyc.field.uan_hint'),
                enabled: !busy.value,
                keyboardType: TextInputType.number,
                inputFormatters: KycInputs.uan,
              ),
              const SizedBox(height: XpertSpacing.md),
              // The field the API always accepted and the app never sent.
              AuthTextField(
                label: ref.t('kyc.field.gst'),
                controller: gst,
                hint: ref.t('kyc.field.gst_hint'),
                enabled: !busy.value,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: KycInputs.gst,
              ),
            ],
          );
        default:
          final docsOk =
              aadhaarFront.value != null &&
              aadhaarBack.value != null &&
              panFront.value != null &&
              panBack.value != null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Intro(text: ref.t('kyc.intro.review')),
              XpertListGroup(
                children: [
                  KycReviewRow(
                    label: ref.t('kyc.field.full_name'),
                    value: _orDash(fullName.text.trim()),
                    onEdit: () => step.value = 0,
                    ok: fullName.text.trim().length >= 2,
                  ),
                  KycReviewRow(
                    label: ref.t('kyc.field.dob'),
                    value: dob.value == null
                        ? '—'
                        : DateFormat('dd MMM yyyy').format(dob.value!),
                    onEdit: () => step.value = 0,
                    ok: dob.value != null,
                  ),
                  KycReviewRow(
                    label: ref.t('kyc.field.aadhaar_number'),
                    value: _orDash(aadhaarNumber.text.trim()),
                    onEdit: () => step.value = 1,
                    ok: KycInputs.bare(aadhaarNumber.text).length == 12,
                  ),
                  KycReviewRow(
                    label: ref.t('kyc.field.pan_number'),
                    value: _orDash(panNumber.text.trim()),
                    onEdit: () => step.value = 2,
                    ok: KycInputs.panPattern.hasMatch(panNumber.text.trim()),
                  ),
                  KycReviewRow(
                    label: ref.t('kyc.review.documents'),
                    value: docsOk && selfie.value != null
                        ? ref.t('kyc.status.uploaded')
                        : ref.t('kyc.status.missing'),
                    onEdit: () => step.value = 1,
                    ok: docsOk && selfie.value != null,
                  ),
                ],
              ),
              const SizedBox(height: XpertSpacing.lg),
              SectionLabel(ref.t('kyc.step.bank')),
              const SizedBox(height: XpertSpacing.sm),
              XpertListGroup(
                children: [
                  KycReviewRow(
                    label: ref.t('kyc.field.holder_name'),
                    value: _orDash(holderName.text.trim()),
                    onEdit: () => step.value = 4,
                    ok: holderName.text.trim().isNotEmpty,
                  ),
                  KycReviewRow(
                    label: ref.t('kyc.field.account_number'),
                    value: _orDash(account.text.trim()),
                    onEdit: () => step.value = 4,
                    ok: account.text.trim().length >= 8,
                  ),
                  KycReviewRow(
                    label: ref.t('kyc.field.ifsc'),
                    value: _orDash(ifsc.text.trim()),
                    onEdit: () => step.value = 4,
                    ok: KycInputs.ifscPattern.hasMatch(ifsc.text.trim()),
                  ),
                  KycReviewRow(
                    label: ref.t('kyc.field.bank_name'),
                    value: _orDash(bankName.text.trim()),
                    onEdit: () => step.value = 4,
                    ok: bankName.text.trim().isNotEmpty,
                  ),
                ],
              ),
              const SizedBox(height: XpertSpacing.lg),
              _Intro(text: ref.t('kyc.review.disclaimer')),
            ],
          );
      }
    }

    return Scaffold(
      backgroundColor: XpertColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(ref.t('kyc.title_plain')),
        actions: [
          TextButton(
            onPressed: busy.value ? null : confirmSignOut,
            child: Text(ref.t('kyc.cta.sign_out')),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                XpertSpacing.lg,
                XpertSpacing.sm,
                XpertSpacing.lg,
                XpertSpacing.md,
              ),
              child: KycStepper(
                step: step.value,
                total: _steps,
                label: stepNames[step.value],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  XpertSpacing.lg,
                  0,
                  XpertSpacing.lg,
                  XpertSpacing.lg,
                ),
                child: body(),
              ),
            ),
            _Footer(
              error: error.value,
              busy: busy.value,
              canGoBack: step.value > 0,
              isLast: step.value == _steps - 1,
              onBack: () {
                error.value = null;
                step.value -= 1;
              },
              onNext: next,
            ),
          ],
        ),
      ),
    );
  }
}

String _orDash(String value) => value.isEmpty ? '—' : value;

/// One sentence at the top of a step saying why it is being asked for. The
/// wizard previously asked for photographs of government ID with no
/// explanation at all.
class _Intro extends StatelessWidget {
  const _Intro({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: XpertSpacing.lg),
      child: Text(
        text,
        style: XpertTypography.caption.copyWith(fontSize: 13, height: 1.45),
      ),
    );
  }
}

/// Date of birth, capped so an under-18 date cannot be picked in the first
/// place — it used to be selectable up to today and rejected afterwards.
class _DobField extends ConsumerWidget {
  const _DobField({
    required this.value,
    required this.onPick,
    required this.enabled,
  });

  final DateTime? value;
  final ValueChanged<DateTime> onPick;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final latest = DateTime(now.year - 18, now.month, now.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ref.t('kyc.field.dob').toUpperCase(),
          style: XpertTypography.eyebrow.copyWith(
            color: XpertColors.muted,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: XpertSpacing.sm),
        Material(
          color: const Color(0xFFF6F9FB),
          borderRadius: BorderRadius.circular(XpertRadius.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(XpertRadius.lg),
            onTap: !enabled
                ? null
                : () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: value ?? DateTime(latest.year - 7),
                      firstDate: DateTime(1950),
                      lastDate: latest,
                      helpText: ref.t('kyc.field.select_dob'),
                    );
                    if (picked != null) onPick(picked);
                  },
            child: Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: XpertSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(XpertRadius.lg),
                border: Border.all(color: const Color(0xFFDCE4EA), width: 1.2),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.cake_outlined,
                    size: 19,
                    color: XpertColors.primary,
                  ),
                  const SizedBox(width: XpertSpacing.sm),
                  Expanded(
                    child: Text(
                      value == null
                          ? ref.t('kyc.field.select_dob')
                          : DateFormat('dd MMM yyyy').format(value!),
                      style: XpertTypography.body.copyWith(
                        fontSize: 16,
                        fontWeight: value == null
                            ? FontWeight.w400
                            : FontWeight.w600,
                        color: value == null
                            ? const Color(0xFFA8B6C0)
                            : XpertColors.onSurface,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: XpertColors.border,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          ref.t('kyc.field.dob_hint'),
          style: XpertTypography.caption.copyWith(fontSize: 11.5),
        ),
      ],
    );
  }
}

/// The action bar, pinned so Continue is always where the thumb expects it
/// rather than scrolling away under a long step.
class _Footer extends ConsumerWidget {
  const _Footer({
    required this.error,
    required this.busy,
    required this.canGoBack,
    required this.isLast,
    required this.onBack,
    required this.onNext,
  });

  final String? error;
  final bool busy;
  final bool canGoBack;
  final bool isLast;
  final VoidCallback onBack;
  final Future<void> Function() onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        XpertSpacing.lg,
        XpertSpacing.md,
        XpertSpacing.lg,
        XpertSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: XpertColors.surface,
        border: Border(top: BorderSide(color: Color(0xFFE8EDF1))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (error != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 15,
                  color: XpertColors.danger,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    error!,
                    style: XpertTypography.caption.copyWith(
                      color: XpertColors.danger,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: XpertSpacing.sm),
          ],
          Row(
            children: [
              if (canGoBack) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onBack,
                    child: Text(ref.t('kyc.cta.back')),
                  ),
                ),
                const SizedBox(width: XpertSpacing.sm),
              ],
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: busy ? null : onNext,
                  child: busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          isLast
                              ? ref.t('kyc.cta.submit')
                              : ref.t('kyc.cta.continue'),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
