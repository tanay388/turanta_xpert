import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../app/shell/xpert_list_group.dart';
import '../../../app/shell/xpert_sections.dart';
import '../../../core/i18n/context_t.dart';
import '../../../core/models/partner_user.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../../auth/data/partner_auth_api.dart';
import '../../address/presentation/widgets/address_fields.dart';
import '../../auth/presentation/auth_controller.dart';
import 'kyc_draft.dart';
import '../../auth/presentation/widgets/auth_text_field.dart';
import '../../referral/data/referral_api.dart';
import '../../../core/utils/rupees.dart';
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
///
/// Kept in the order the choices are offered; mirrors the backend enum.
const _relations = ['self', 'mother', 'father', 'spouse', 'child'];

/// The wizard's steps, in order.
///
/// These used to be a bare `static const _steps = 6` with three structures
/// keyed by index — the names, the validators, the bodies — and a review step
/// reached through `default:`. Inserting a step silently repointed every
/// hardcoded jump on the review screen, so the order lives here now and
/// nothing counts positions by hand.
enum KycStep { personal, address, aadhaar, pan, selfie, bank, review }

extension KycStepX on KycStep {
  bool get isLast => index == KycStep.values.length - 1;
  bool get isFirst => index == 0;
  KycStep get next => KycStep.values[index + 1];
  KycStep get previous => KycStep.values[index - 1];
}

class KycWizardScreen extends HookConsumerWidget {
  const KycWizardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = useState(KycStep.personal);
    final busy = useState(false);
    final error = useState<String?>(null);
    final scroll = useScrollController();

    /// Which way the next transition should slide.
    final goingBack = useState(false);

    // A short step after a long one used to leave you scrolled halfway down a
    // screen you had not read: the scroll view keeps its offset across a
    // rebuild, and only the content changed.
    useEffect(() {
      if (scroll.hasClients) scroll.jumpTo(0);
      return null;
    }, [step.value]);

    final fullName = useTextEditingController();
    final dob = useState<DateTime?>(null);
    final aadhaarFront = useState<String?>(null);
    final aadhaarBack = useState<String?>(null);
    final aadhaarNumber = useTextEditingController();
    final hasPan = useState(true);
    final panFront = useState<String?>(null);
    final panNumber = useTextEditingController();
    final selfie = useState<String?>(null);
    // Stored values are private storage keys, which cannot be rendered
    // directly — keep the short-lived signed preview links separately, keyed
    // by the stored key.
    final previews = useState<Map<String, String>>(const {});
    final line1 = useTextEditingController();
    final line2 = useTextEditingController();
    final landmark = useTextEditingController();
    final city = useTextEditingController();
    final stateName = useTextEditingController();
    final pincode = useTextEditingController();
    final pin = useState<LatLng?>(null);
    final formatted = useState<String?>(null);
    final relation = useState('self');
    final passbook = useState<String?>(null);
    final account = useTextEditingController();
    final accountConfirm = useTextEditingController();
    final ifsc = useTextEditingController();
    final bankName = useTextEditingController();
    final holderName = useTextEditingController();
    final uan = useTextEditingController();
    final gst = useTextEditingController();
    final eshram = useTextEditingController();

    final profile = ref.watch(authProvider).valueOrNull?.profile;
    final uid = profile?.id;

    useEffect(() {
      if (uid == null) return null;
      var cancelled = false;
      () async {
        final draft = await KycDraft.load(uid);
        if (cancelled) return;
        if (draft != null) {
          fullName.text = draft['fullName'] ?? fullName.text;
          aadhaarNumber.text = draft['aadhaarNumber'] ?? aadhaarNumber.text;
          panNumber.text = draft['panNumber'] ?? panNumber.text;
          line1.text = draft['addressLine1'] ?? line1.text;
          line2.text = draft['addressLine2'] ?? line2.text;
          landmark.text = draft['landmark'] ?? landmark.text;
          city.text = draft['city'] ?? city.text;
          stateName.text = draft['state'] ?? stateName.text;
          pincode.text = draft['pincode'] ?? pincode.text;
          final lat = double.tryParse(draft['latitude'] ?? '');
          final lng = double.tryParse(draft['longitude'] ?? '');
          if (lat != null && lng != null) pin.value = LatLng(lat, lng);
          formatted.value = draft['formattedAddress'] ?? formatted.value;
          account.text = draft['bankAccountNumber'] ?? account.text;
          accountConfirm.text =
              draft['bankAccountNumber'] ?? accountConfirm.text;
          ifsc.text = draft['bankIfsc'] ?? ifsc.text;
          bankName.text = draft['bankName'] ?? bankName.text;
          holderName.text = draft['accountHolderName'] ?? holderName.text;
          uan.text = draft['uanNumber'] ?? uan.text;
          gst.text = draft['gstNumber'] ?? gst.text;
          eshram.text = draft['eshramNumber'] ?? eshram.text;
          relation.value = draft['accountHolderRelation'] ?? relation.value;
          aadhaarFront.value ??= draft['aadhaarFrontUrl'];
          aadhaarBack.value ??= draft['aadhaarBackUrl'];
          panFront.value ??= draft['panFrontUrl'];
          selfie.value ??= draft['selfieUrl'];
          passbook.value ??= draft['passbookUrl'];
          final savedDob = draft['dateOfBirth'];
          if (savedDob != null) dob.value = DateTime.tryParse(savedDob);
        }
        // Two fields we can answer for them, from the hub they already chose.
        if (city.text.isEmpty) city.text = profile?.hubCity ?? '';
        if (stateName.text.isEmpty) stateName.text = profile?.hubState ?? '';
      }();
      return () => cancelled = true;
    }, [uid]);

    // Saved on every step change rather than every keystroke: the partner has
    // just told us they are done with that step, and it keeps writes rare.
    useEffect(() {
      if (uid == null) return null;
      KycDraft.save(uid, {
        'fullName': fullName.text,
        'dateOfBirth': dob.value?.toIso8601String(),
        'aadhaarNumber': aadhaarNumber.text,
        'panNumber': panNumber.text,
        'addressLine1': line1.text,
        'addressLine2': line2.text,
        'landmark': landmark.text,
        'city': city.text,
        'state': stateName.text,
        'pincode': pincode.text,
        'latitude': pin.value?.latitude.toString(),
        'longitude': pin.value?.longitude.toString(),
        'formattedAddress': formatted.value,
        'bankAccountNumber': account.text,
        'bankIfsc': ifsc.text,
        'bankName': bankName.text,
        'accountHolderName': holderName.text,
        'accountHolderRelation': relation.value,
        'uanNumber': uan.text,
        'gstNumber': gst.text,
        'eshramNumber': eshram.text,
        'aadhaarFrontUrl': aadhaarFront.value,
        'aadhaarBackUrl': aadhaarBack.value,
        'panFrontUrl': panFront.value,
        'selfieUrl': selfie.value,
        'passbookUrl': passbook.value,
      });
      return null;
    }, [step.value]);

    // A referral code applied at sign-in is confirmed here, on the first
    // screen a new partner actually lands on. Saying nothing is what made the
    // old flow feel broken even when the code had worked.
    final referralNotice = ref.watch(referralNoticeProvider);
    final offer = ref.watch(referralOfferProvider);
    useEffect(() {
      if (referralNotice == null) return null;
      final applied = referralNotice.referralApplied == true;
      final name = referralNotice.referredByName;
      final reward = offer.valueOrNull;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 6),
              backgroundColor: applied
                  ? XpertColors.success
                  : XpertColors.danger,
              content: Text(
                !applied
                    ? ref.t('login.referral.not_applied')
                    : (name != null && reward != null
                          ? ref.t('login.referral.applied', {
                              'name': name,
                              'amount': rupees(reward.refereeAmount),
                              'jobs': '${reward.refereeJobs}',
                            })
                          : ref.t('login.referral.applied_generic')),
              ),
            ),
          );
        ref.read(referralNoticeProvider.notifier).state = null;
      });
      return null;
    }, [referralNotice, offer]);

    String stepName(KycStep which) => switch (which) {
      KycStep.personal => ref.t('kyc.step.personal'),
      KycStep.address => ref.t('kyc.step.address'),
      KycStep.aadhaar => ref.t('kyc.step.aadhaar'),
      KycStep.pan => ref.t('kyc.step.pan'),
      KycStep.selfie => ref.t('kyc.step.selfie'),
      KycStep.bank => ref.t('kyc.step.bank'),
      KycStep.review => ref.t('kyc.step.review'),
    };

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

    bool validate(KycStep which) {
      error.value = null;
      switch (which) {
        case KycStep.personal:
          if (fullName.text.trim().length < 2) {
            error.value = ref.t('kyc.error.name_required');
            return false;
          }
          if (dob.value == null) {
            error.value = ref.t('kyc.error.dob_required');
            return false;
          }
          return true;
        case KycStep.address:
          if (line1.text.trim().length < 2) {
            error.value = ref.t('kyc.error.line1_required');
            return false;
          }
          if (line2.text.trim().length < 2) {
            error.value = ref.t('kyc.error.line2_required');
            return false;
          }
          if (!KycInputs.pincodePattern.hasMatch(pincode.text.trim())) {
            error.value = ref.t('kyc.error.pincode_invalid');
            return false;
          }
          if (city.text.trim().length < 2) {
            error.value = ref.t('kyc.error.city_required');
            return false;
          }
          if (stateName.text.trim().length < 2) {
            error.value = ref.t('kyc.error.state_required');
            return false;
          }
          if (pin.value == null) {
            error.value = ref.t('kyc.error.pin_required');
            return false;
          }
          return true;
        case KycStep.aadhaar:
          if (aadhaarFront.value == null || aadhaarBack.value == null) {
            error.value = ref.t('kyc.error.aadhaar_photos_required');
            return false;
          }
          if (KycInputs.bare(aadhaarNumber.text).length != 12) {
            error.value = ref.t('kyc.error.aadhaar_invalid');
            return false;
          }
          return true;
        case KycStep.pan:
          // A partner without a PAN must still be able to finish onboarding.
          if (!hasPan.value) return true;
          if (panFront.value == null) {
            error.value = ref.t('kyc.error.pan_photos_required');
            return false;
          }
          // Length 10 was the only check; ABCDE1234F is the actual shape.
          if (!KycInputs.panPattern.hasMatch(panNumber.text.trim())) {
            error.value = ref.t('kyc.error.pan_invalid');
            return false;
          }
          return true;
        case KycStep.selfie:
          if (selfie.value == null) {
            error.value = ref.t('kyc.error.selfie_required');
            return false;
          }
          return true;
        case KycStep.bank:
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
          final eshramValue = eshram.text.trim();
          if (eshramValue.isNotEmpty && eshramValue.length != 12) {
            error.value = ref.t('kyc.error.eshram_invalid');
            return false;
          }
          return true;
        case KycStep.review:
          return true;
      }
    }

    Future<void> submit() async {
      // Every step is re-checked, not just the last one — a partner can jump
      // back from review, clear a field and return without passing through.
      for (final which in KycStep.values) {
        if (which == KycStep.review) continue;
        if (!validate(which)) {
          step.value = which;
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
          'hasPan': hasPan.value,
          if (hasPan.value) 'panFrontUrl': panFront.value,
          if (hasPan.value) 'panNumber': panNumber.text.trim(),
          'selfieUrl': selfie.value,
          'bankAccountNumber': account.text.trim(),
          'bankIfsc': ifsc.text.trim(),
          'bankName': bankName.text.trim(),
          'accountHolderName': holderName.text.trim(),
          'accountHolderRelation': relation.value,
          if (passbook.value != null) 'passbookUrl': passbook.value,
          'addressLine1': line1.text.trim(),
          'addressLine2': line2.text.trim(),
          if (landmark.text.trim().isNotEmpty) 'landmark': landmark.text.trim(),
          'city': city.text.trim(),
          'state': stateName.text.trim(),
          'pincode': pincode.text.trim(),
          'latitude': pin.value?.latitude,
          'longitude': pin.value?.longitude,
          if (formatted.value != null) 'formattedAddress': formatted.value,
          if (uan.text.trim().isNotEmpty) 'uanNumber': uan.text.trim(),
          if (gst.text.trim().isNotEmpty) 'gstNumber': gst.text.trim(),
          if (eshram.text.trim().isNotEmpty) 'eshramNumber': eshram.text.trim(),
          'submit': true,
        });
        if (uid != null) await KycDraft.clear(uid);
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
      if (!step.value.isLast) {
        goingBack.value = false;
        step.value = step.value.next;
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
        case KycStep.personal:
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
        case KycStep.address:
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Intro(text: ref.t('kyc.intro.address')),
              AddressFields(
                line1: line1,
                line2: line2,
                landmark: landmark,
                pincode: pincode,
                city: city,
                state: stateName,
                pin: pin.value,
                onPinChanged: (next, line) {
                  pin.value = next;
                  if (line != null) formatted.value = line;
                },
                enabled: !busy.value,
              ),
            ],
          );
        case KycStep.aadhaar:
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
        case KycStep.pan:
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Intro(text: ref.t('kyc.intro.pan')),
              _NoPanCheckbox(
                checked: !hasPan.value,
                enabled: !busy.value,
                label: ref.t('kyc.pan.none'),
                onChanged: (noPan) {
                  hasPan.value = !noPan;
                  if (noPan) {
                    panFront.value = null;
                    panNumber.clear();
                    error.value = null;
                  }
                },
              ),
              if (hasPan.value) ...[
                const SizedBox(height: XpertSpacing.md),
                KycDocTile(
                  label: ref.t('kyc.doc.pan_front'),
                  hint: ref.t('kyc.doc.tap_to_upload'),
                  storageKey: panFront.value,
                  previewUrl: previews.value[panFront.value],
                  enabled: !busy.value,
                  onTap: () => pickAndUpload(panFront),
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
            ],
          );
        case KycStep.selfie:
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
        case KycStep.bank:
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
              const SizedBox(height: XpertSpacing.lg),
              SectionLabel(ref.t('kyc.field.relationship')),
              const SizedBox(height: XpertSpacing.sm),
              KycChoiceRow(
                options: [
                  for (final key in _relations)
                    KycChoice(
                      value: key,
                      label: ref.t('kyc.relationship.$key'),
                    ),
                ],
                selected: relation.value,
                enabled: !busy.value,
                onSelect: (picked) {
                  relation.value = picked;
                  // Their own account is nearly always in their own name, and
                  // it is the name we already asked for on the first step.
                  if (picked == 'self' && holderName.text.trim().isEmpty) {
                    holderName.text = fullName.text.trim();
                  }
                },
              ),
              const SizedBox(height: XpertSpacing.xl),
              SectionLabel(ref.t('kyc.section.optional')),
              const SizedBox(height: XpertSpacing.sm),
              KycDocTile(
                label: ref.t('kyc.doc.passbook'),
                hint: ref.t('kyc.doc.passbook_hint'),
                storageKey: passbook.value,
                previewUrl: previews.value[passbook.value],
                enabled: !busy.value,
                onTap: () => pickAndUpload(passbook),
              ),
              const SizedBox(height: XpertSpacing.md),
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
              const SizedBox(height: XpertSpacing.md),
              AuthTextField(
                label: ref.t('kyc.field.eshram'),
                controller: eshram,
                hint: ref.t('kyc.field.eshram_hint'),
                enabled: !busy.value,
                keyboardType: TextInputType.number,
                inputFormatters: KycInputs.eshram,
              ),
            ],
          );
        case KycStep.review:
          final docsOk =
              aadhaarFront.value != null &&
              aadhaarBack.value != null &&
              (!hasPan.value || panFront.value != null);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Intro(text: ref.t('kyc.intro.review')),
              XpertListGroup(
                children: [
                  KycReviewRow(
                    label: ref.t('kyc.field.full_name'),
                    value: _orDash(fullName.text.trim()),
                    onEdit: () => _jumpTo(step, goingBack, KycStep.personal),
                    ok: fullName.text.trim().length >= 2,
                  ),
                  KycReviewRow(
                    label: ref.t('kyc.field.dob'),
                    value: dob.value == null
                        ? '—'
                        : DateFormat('dd MMM yyyy').format(dob.value!),
                    onEdit: () => _jumpTo(step, goingBack, KycStep.personal),
                    ok: dob.value != null,
                  ),
                  KycReviewRow(
                    label: ref.t('kyc.field.aadhaar_number'),
                    value: _orDash(aadhaarNumber.text.trim()),
                    onEdit: () => _jumpTo(step, goingBack, KycStep.aadhaar),
                    ok: KycInputs.bare(aadhaarNumber.text).length == 12,
                  ),
                  KycReviewRow(
                    label: ref.t('kyc.field.pan_number'),
                    value: hasPan.value
                        ? _orDash(panNumber.text.trim())
                        : ref.t('kyc.pan.not_applicable'),
                    onEdit: () => _jumpTo(step, goingBack, KycStep.pan),
                    ok:
                        !hasPan.value ||
                        KycInputs.panPattern.hasMatch(panNumber.text.trim()),
                  ),
                  KycReviewRow(
                    label: ref.t('kyc.review.documents'),
                    value: docsOk && selfie.value != null
                        ? ref.t('kyc.status.uploaded')
                        : ref.t('kyc.status.missing'),
                    onEdit: () => _jumpTo(step, goingBack, KycStep.aadhaar),
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
                    onEdit: () => _jumpTo(step, goingBack, KycStep.bank),
                    ok: holderName.text.trim().isNotEmpty,
                  ),
                  KycReviewRow(
                    label: ref.t('kyc.field.account_number'),
                    value: _orDash(account.text.trim()),
                    onEdit: () => _jumpTo(step, goingBack, KycStep.bank),
                    ok: account.text.trim().length >= 8,
                  ),
                  KycReviewRow(
                    label: ref.t('kyc.field.ifsc'),
                    value: _orDash(ifsc.text.trim()),
                    onEdit: () => _jumpTo(step, goingBack, KycStep.bank),
                    ok: KycInputs.ifscPattern.hasMatch(ifsc.text.trim()),
                  ),
                  KycReviewRow(
                    label: ref.t('kyc.field.bank_name'),
                    value: _orDash(bankName.text.trim()),
                    onEdit: () => _jumpTo(step, goingBack, KycStep.bank),
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
                step: step.value.index,
                total: KycStep.values.length,
                label: stepName(step.value),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(
                  XpertSpacing.lg,
                  0,
                  XpertSpacing.lg,
                  XpertSpacing.lg,
                ),
                // Keyed by step so the switcher knows the content changed, and
                // travelling backwards slides the other way.
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previous, ?current],
                  ),
                  transitionBuilder: (child, animation) {
                    final incoming = child.key == ValueKey(step.value);
                    final from = goingBack.value ? -0.06 : 0.06;
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween(
                          begin: Offset(incoming ? from : -from, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(key: ValueKey(step.value), child: body()),
                ),
              ),
            ),
            _Footer(
              error: error.value,
              busy: busy.value,
              canGoBack: !step.value.isFirst,
              isLast: step.value.isLast,
              onBack: () {
                error.value = null;
                goingBack.value = true;
                step.value = step.value.previous;
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

/// Review's "edit" links travel backwards through the wizard, so the
/// transition should slide that way too.
void _jumpTo(
  ValueNotifier<KycStep> step,
  ValueNotifier<bool> goingBack,
  KycStep target,
) {
  goingBack.value = target.index < step.value.index;
  step.value = target;
}

/// One sentence at the top of a step saying why it is being asked for. The
/// wizard previously asked for photographs of government ID with no
/// explanation at all.
/// "I do not have a PAN card" — ticking it drops the PAN photo and number from
/// the step entirely rather than leaving disabled fields on screen.
class _NoPanCheckbox extends StatelessWidget {
  const _NoPanCheckbox({
    required this.checked,
    required this.enabled,
    required this.label,
    required this.onChanged,
  });

  final bool checked;
  final bool enabled;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(XpertRadius.md),
      onTap: enabled ? () => onChanged(!checked) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: XpertSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              value: checked,
              onChanged: enabled ? (v) => onChanged(v ?? false) : null,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: XpertSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: XpertTypography.body.copyWith(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
