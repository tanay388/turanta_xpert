import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/context_t.dart';
import '../../../core/models/partner_user.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../../auth/data/partner_auth_api.dart';
import '../../auth/presentation/auth_controller.dart';

class KycWizardScreen extends HookConsumerWidget {
  const KycWizardScreen({super.key});

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

    final steps = [
      ref.t('kyc.step.personal'),
      ref.t('kyc.step.aadhaar'),
      ref.t('kyc.step.pan'),
      ref.t('kyc.step.selfie'),
      ref.t('kyc.step.bank'),
      ref.t('kyc.step.review'),
    ];

    Future<String?> pickAndUpload(ValueNotifier<String?> target) async {
      final picker = ImagePicker();
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(ref.t('kyc.picker.camera')),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(ref.t('kyc.picker.gallery')),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (source == null) return null;

      final file = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (file == null) return null;

      busy.value = true;
      error.value = null;
      try {
        final result =
            await ref.read(partnerAuthApiProvider).uploadKycImage(file.path);
        target.value = result.key;
        if (result.previewUrl != null) {
          previews.value = {...previews.value, result.key: result.previewUrl!};
        }
        return result.key;
      } on ApiException catch (e) {
        error.value = e.message;
        return null;
      } finally {
        busy.value = false;
      }
    }

    bool validateCurrent() {
      error.value = null;
      switch (step.value) {
        case 0:
          if (fullName.text.trim().length < 2) {
            error.value = ref.t('kyc.error.name_required');
            return false;
          }
          final birth = dob.value;
          if (birth == null) {
            error.value = ref.t('kyc.error.dob_required');
            return false;
          }
          final now = DateTime.now();
          var age = now.year - birth.year;
          if (now.month < birth.month ||
              (now.month == birth.month && now.day < birth.day)) {
            age -= 1;
          }
          if (age < 18) {
            error.value = ref.t('kyc.error.min_age');
            return false;
          }
          return true;
        case 1:
          if (aadhaarFront.value == null || aadhaarBack.value == null) {
            error.value = ref.t('kyc.error.aadhaar_photos_required');
            return false;
          }
          if (aadhaarNumber.text.replaceAll(RegExp(r'\s+'), '').length != 12) {
            error.value = ref.t('kyc.error.aadhaar_invalid');
            return false;
          }
          return true;
        case 2:
          if (panFront.value == null || panBack.value == null) {
            error.value = ref.t('kyc.error.pan_photos_required');
            return false;
          }
          if (panNumber.text.trim().length != 10) {
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
          final acc = account.text.trim();
          final confirm = accountConfirm.text.trim();
          if (acc.length < 8) {
            error.value = ref.t('kyc.error.account_invalid');
            return false;
          }
          if (acc != confirm) {
            error.value = ref.t('kyc.error.account_mismatch');
            return false;
          }
          if (ifsc.text.trim().length < 8) {
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
          return true;
        default:
          return true;
      }
    }

    Future<void> submit() async {
      if (!validateCurrent()) return;
      busy.value = true;
      error.value = null;
      try {
        await ref.read(partnerAuthApiProvider).upsertKyc({
          'fullName': fullName.text.trim(),
          'dateOfBirth': DateFormat('yyyy-MM-dd').format(dob.value!),
          'aadhaarFrontUrl': aadhaarFront.value,
          'aadhaarBackUrl': aadhaarBack.value,
          'aadhaarNumber': aadhaarNumber.text.replaceAll(RegExp(r'\s+'), ''),
          'panFrontUrl': panFront.value,
          'panBackUrl': panBack.value,
          'panNumber': panNumber.text.trim().toUpperCase(),
          'selfieUrl': selfie.value,
          'bankAccountNumber': account.text.trim(),
          'bankIfsc': ifsc.text.trim().toUpperCase(),
          'bankName': bankName.text.trim(),
          'accountHolderName': holderName.text.trim(),
          if (uan.text.trim().isNotEmpty) 'uanNumber': uan.text.trim(),
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
      if (!validateCurrent()) return;
      if (step.value < steps.length - 1) {
        step.value += 1;
      } else {
        await submit();
      }
    }

    Widget docTile({
      required String label,
      required ValueNotifier<String?> url,
    }) {
      final has = url.value != null;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: XpertTypography.label),
        subtitle: Text(
          has ? ref.t('kyc.status.uploaded') : ref.t('kyc.doc.tap_to_upload'),
          style: XpertTypography.caption.copyWith(
            color: has ? XpertColors.success : XpertColors.muted,
          ),
        ),
        trailing: Icon(
          has ? Icons.check_circle : Icons.upload_file,
          color: has ? XpertColors.success : XpertColors.muted,
        ),
        onTap: busy.value ? null : () => pickAndUpload(url),
      );
    }

    Widget stepBody() {
      switch (step.value) {
        case 0:
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: fullName,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: ref.t('kyc.field.full_name')),
              ),
              const SizedBox(height: XpertSpacing.md),
              OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime(1995, 1, 1),
                    firstDate: DateTime(1950),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) dob.value = picked;
                },
                child: Text(
                  dob.value == null
                      ? ref.t('kyc.field.select_dob')
                      : ref.t('kyc.field.dob_value', {
                          'date': DateFormat('dd MMM yyyy').format(dob.value!),
                        }),
                ),
              ),
            ],
          );
        case 1:
          return Column(
            children: [
              docTile(label: ref.t('kyc.doc.aadhaar_front'), url: aadhaarFront),
              docTile(label: ref.t('kyc.doc.aadhaar_back'), url: aadhaarBack),
              const SizedBox(height: XpertSpacing.md),
              TextField(
                controller: aadhaarNumber,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: ref.t('kyc.field.aadhaar_number'),
                  hintText: ref.t('kyc.field.aadhaar_hint'),
                ),
              ),
            ],
          );
        case 2:
          return Column(
            children: [
              docTile(label: ref.t('kyc.doc.pan_front'), url: panFront),
              docTile(label: ref.t('kyc.doc.pan_back'), url: panBack),
              const SizedBox(height: XpertSpacing.md),
              TextField(
                controller: panNumber,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: ref.t('kyc.field.pan_number'),
                  hintText: ref.t('kyc.field.pan_hint'),
                ),
              ),
            ],
          );
        case 3:
          return Column(
            children: [
              docTile(label: ref.t('kyc.doc.selfie'), url: selfie),
              if (selfie.value != null)
                Padding(
                  padding: const EdgeInsets.only(top: XpertSpacing.md),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(XpertRadius.md),
                    child: Image.network(
                      previews.value[selfie.value!] ?? selfie.value!,
                      height: 160,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
            ],
          );
        case 4:
          return Column(
            children: [
              TextField(
                controller: account,
                keyboardType: TextInputType.number,
                decoration:
                    InputDecoration(labelText: ref.t('kyc.field.account_number')),
              ),
              const SizedBox(height: XpertSpacing.md),
              TextField(
                controller: accountConfirm,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: ref.t('kyc.field.account_number_confirm'),
                ),
              ),
              const SizedBox(height: XpertSpacing.md),
              TextField(
                controller: ifsc,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(labelText: ref.t('kyc.field.ifsc')),
              ),
              const SizedBox(height: XpertSpacing.md),
              TextField(
                controller: bankName,
                textCapitalization: TextCapitalization.words,
                decoration:
                    InputDecoration(labelText: ref.t('kyc.field.bank_name')),
              ),
              const SizedBox(height: XpertSpacing.md),
              TextField(
                controller: holderName,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: ref.t('kyc.field.holder_name'),
                ),
              ),
              const SizedBox(height: XpertSpacing.md),
              TextField(
                controller: uan,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: ref.t('kyc.field.uan'),
                  hintText: ref.t('kyc.field.uan_hint'),
                ),
              ),
            ],
          );
        default:
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ref.t('kyc.review.name', {'value': fullName.text.trim()}),
                style: XpertTypography.body,
              ),
              Text(
                ref.t('kyc.review.dob', {
                  'value': dob.value == null
                      ? '—'
                      : DateFormat('dd MMM yyyy').format(dob.value!),
                }),
                style: XpertTypography.body,
              ),
              Text(
                ref.t('kyc.review.aadhaar', {
                  'status': aadhaarFront.value != null && aadhaarBack.value != null
                      ? ref.t('kyc.status.uploaded')
                      : ref.t('kyc.status.missing'),
                }),
                style: XpertTypography.body,
              ),
              Text(
                ref.t('kyc.review.pan', {
                  'status': panFront.value != null && panBack.value != null
                      ? ref.t('kyc.status.uploaded')
                      : ref.t('kyc.status.missing'),
                }),
                style: XpertTypography.body,
              ),
              Text(
                ref.t('kyc.review.selfie', {
                  'status': selfie.value != null
                      ? ref.t('kyc.status.uploaded')
                      : ref.t('kyc.status.missing'),
                }),
                style: XpertTypography.body,
              ),
              Text(
                ref.t('kyc.review.bank', {
                  'bankName': bankName.text.trim(),
                  'ifsc': ifsc.text.trim().toUpperCase(),
                }),
                style: XpertTypography.body,
              ),
              Text(
                ref.t('kyc.review.account', {'value': account.text.trim()}),
                style: XpertTypography.body,
              ),
              Text(
                ref.t('kyc.review.holder', {'value': holderName.text.trim()}),
                style: XpertTypography.body,
              ),
              const SizedBox(height: XpertSpacing.md),
              Text(
                ref.t('kyc.review.disclaimer'),
                style: XpertTypography.caption,
              ),
            ],
          );
      }
    }

    return Scaffold(
      backgroundColor: XpertColors.background,
      appBar: AppBar(
        title: Text(ref.t('kyc.title', {'step': steps[step.value]})),
        actions: [
          TextButton(
            onPressed: () => ref.read(authProvider.notifier).signOut(),
            child: Text(ref.t('kyc.cta.sign_out')),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(XpertSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(
                value: (step.value + 1) / steps.length,
                minHeight: 6,
                borderRadius: BorderRadius.circular(99),
              ),
              const SizedBox(height: XpertSpacing.lg),
              Expanded(child: SingleChildScrollView(child: stepBody())),
              if (error.value != null) ...[
                Text(
                  error.value!,
                  style: XpertTypography.caption.copyWith(
                    color: XpertColors.danger,
                  ),
                ),
                const SizedBox(height: XpertSpacing.sm),
              ],
              Row(
                children: [
                  if (step.value > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy.value
                            ? null
                            : () {
                                error.value = null;
                                step.value -= 1;
                              },
                        child: Text(ref.t('kyc.cta.back')),
                      ),
                    ),
                  if (step.value > 0) const SizedBox(width: XpertSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: busy.value ? null : next,
                      child: busy.value
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              step.value == steps.length - 1
                                  ? ref.t('kyc.cta.submit')
                                  : ref.t('kyc.cta.continue'),
                            ),
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
