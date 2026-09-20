import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turanta_xpert/app/shell/xpert_sections.dart';

import '../../../../core/i18n/context_t.dart';
import '../../../../core/theme/xpert_tokens.dart';
import '../../../auth/presentation/widgets/auth_text_field.dart';
import '../../../kyc/presentation/widgets/kyc_inputs.dart';
import '../address_map_screen.dart';

/// The six address fields and the map pin, in one place.
///
/// They are asked for twice — inside the KYC wizard, and on the standalone
/// screen shown to partners who were approved before the address existed. The
/// two used to be copies of each other, down to duplicated validators against
/// the same translation keys, which is how they drift.
class AddressFields extends ConsumerWidget {
  const AddressFields({
    super.key,
    required this.line1,
    required this.line2,
    required this.landmark,
    required this.pincode,
    required this.city,
    required this.state,
    required this.pin,
    required this.onPinChanged,
    this.enabled = true,
  });

  final TextEditingController line1;
  final TextEditingController line2;
  final TextEditingController landmark;
  final TextEditingController pincode;
  final TextEditingController city;
  final TextEditingController state;

  final LatLng? pin;

  /// Reports the pin and, when the lookup succeeded, the line Google wrote for
  /// it — kept alongside the typed address as a second reading of the place.
  final void Function(LatLng pin, String? formatted) onPinChanged;
  final bool enabled;

  Future<void> _openMap(BuildContext context) async {
    final picked = await Navigator.of(context).push<PickedPin>(
      MaterialPageRoute(builder: (_) => AddressMapScreen(initial: pin)),
    );
    if (picked == null) return;
    final resolved = picked.address;
    onPinChanged(picked.position, resolved?.formatted);
    // Whatever the pin resolved to wins: it is more precise than a guess from
    // the hub, and the partner can still type over any of it.
    if (resolved == null) return;
    if (resolved.city?.isNotEmpty ?? false) city.text = resolved.city!;
    if (resolved.state?.isNotEmpty ?? false) state.text = resolved.state!;
    if (resolved.pincode?.isNotEmpty ?? false) pincode.text = resolved.pincode!;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PinTile(pin: pin, enabled: enabled, onTap: () => _openMap(context)),
        const SizedBox(height: XpertSpacing.lg),
        AuthTextField(
          label: ref.t('kyc.field.line1'),
          controller: line1,
          hint: ref.t('kyc.field.line1_hint'),
          enabled: enabled,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: XpertSpacing.md),
        AuthTextField(
          label: ref.t('kyc.field.line2'),
          controller: line2,
          hint: ref.t('kyc.field.line2_hint'),
          enabled: enabled,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: XpertSpacing.md),
        AuthTextField(
          label: ref.t('kyc.field.landmark'),
          controller: landmark,
          hint: ref.t('kyc.field.landmark_hint'),
          enabled: enabled,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: XpertSpacing.xl),
        SectionLabel(ref.t('kyc.section.where')),
        const SizedBox(height: XpertSpacing.sm),
        AuthTextField(
          label: ref.t('kyc.field.pincode'),
          controller: pincode,
          hint: ref.t('kyc.field.pincode_hint'),
          enabled: enabled,
          keyboardType: TextInputType.number,
          inputFormatters: KycInputs.pincode,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: XpertSpacing.md),
        // Short, and usually already answered by the pin, so these sit side by
        // side rather than eating two more rows.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AuthTextField(
                label: ref.t('kyc.field.city'),
                controller: city,
                hint: ref.t('kyc.field.city_hint'),
                enabled: enabled,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: XpertSpacing.md),
            Expanded(
              child: AuthTextField(
                label: ref.t('kyc.field.state'),
                controller: state,
                hint: ref.t('kyc.field.state_hint'),
                enabled: enabled,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PinTile extends ConsumerWidget {
  const _PinTile({
    required this.pin,
    required this.enabled,
    required this.onTap,
  });

  final LatLng? pin;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dropped = pin != null;
    return Material(
      color: dropped
          ? XpertColors.heroAccent.withValues(alpha: 0.10)
          : const Color(0xFFF6F9FB),
      borderRadius: BorderRadius.circular(XpertRadius.lg),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(XpertSpacing.md),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(XpertRadius.lg),
            border: Border.all(
              color: dropped ? XpertColors.heroAccent : const Color(0xFFDCE4EA),
              width: dropped ? 1.8 : 1.2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                dropped ? Icons.where_to_vote : Icons.add_location_alt_outlined,
                color: dropped ? XpertColors.heroAccent : XpertColors.muted,
              ),
              const SizedBox(width: XpertSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ref.t(
                        dropped ? 'address.pin.set' : 'address.pin.not_set',
                      ),
                      style: XpertTypography.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dropped
                          ? '${pin!.latitude.toStringAsFixed(5)}, ${pin!.longitude.toStringAsFixed(5)}'
                          : ref.t('address.pin.hint'),
                      style: XpertTypography.caption.copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Text(
                ref.t(dropped ? 'address.pin.change' : 'address.pin.open'),
                style: XpertTypography.caption.copyWith(
                  color: XpertColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
