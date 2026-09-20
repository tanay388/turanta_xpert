import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../app/router.dart';
import '../../../core/i18n/context_t.dart';
import '../../../core/models/partner_user.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../../auth/data/partner_auth_api.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../kyc/presentation/widgets/kyc_inputs.dart';
import 'widgets/address_fields.dart';

/// Asks a partner for their home address, once.
///
/// Its own gate rather than a step in the KYC wizard, because the partners who
/// most need to answer it are already past that wizard — approved and working,
/// or waiting on a review their locked KYC cannot be edited to satisfy. One
/// screen, one Save; it must not read as their KYC being reopened.
class AddressScreen extends ConsumerStatefulWidget {
  const AddressScreen({super.key});

  @override
  ConsumerState<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends ConsumerState<AddressScreen> {
  final _line1 = TextEditingController();
  final _line2 = TextEditingController();
  final _landmark = TextEditingController();
  final _pincode = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();

  LatLng? _pin;
  String? _formatted;
  bool _busy = false;
  String? _error;
  bool _prefilled = false;

  @override
  void dispose() {
    _line1.dispose();
    _line2.dispose();
    _landmark.dispose();
    _pincode.dispose();
    _city.dispose();
    _state.dispose();
    super.dispose();
  }

  /// The two fields we can answer for them, from the hub they already picked.
  void _prefillFromHub() {
    if (_prefilled) return;
    final profile = ref.read(authProvider).valueOrNull?.profile;
    if (profile == null) return;
    _prefilled = true;
    if (_city.text.isEmpty) _city.text = profile.hubCity ?? '';
    if (_state.text.isEmpty) _state.text = profile.hubState ?? '';
  }

  String? _validate() {
    if (_line1.text.trim().length < 2) return ref.t('kyc.error.line1_required');
    if (_line2.text.trim().length < 2) return ref.t('kyc.error.line2_required');
    if (!KycInputs.pincodePattern.hasMatch(_pincode.text.trim())) {
      return ref.t('kyc.error.pincode_invalid');
    }
    if (_city.text.trim().length < 2) return ref.t('kyc.error.city_required');
    if (_state.text.trim().length < 2) return ref.t('kyc.error.state_required');
    if (_pin == null) return ref.t('kyc.error.pin_required');
    return null;
  }

  Future<void> _save() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(partnerAuthApiProvider).updateAddress({
        'addressLine1': _line1.text.trim(),
        'addressLine2': _line2.text.trim(),
        if (_landmark.text.trim().isNotEmpty) 'landmark': _landmark.text.trim(),
        'pincode': _pincode.text.trim(),
        'city': _city.text.trim(),
        'state': _state.text.trim(),
        'latitude': _pin!.latitude,
        'longitude': _pin!.longitude,
        if (_formatted != null) 'formattedAddress': _formatted,
      });
      await ref.read(authProvider.notifier).refreshProfile();
      if (!mounted) return;
      // Hand back to the gate chain rather than naming a screen: where they go
      // next depends on whether they are approved, and only the gates know.
      final session = ref.read(authProvider).valueOrNull;
      if (session == null) {
        context.go('/login');
        return;
      }
      context.go(partnerDestination(PartnerGates.of(session)));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _prefillFromHub();

    return Scaffold(
      backgroundColor: XpertColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(ref.t('address.title')),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(XpertSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      ref.t('address.intro'),
                      style: XpertTypography.body.copyWith(
                        color: XpertColors.muted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: XpertSpacing.lg),
                    AddressFields(
                      line1: _line1,
                      line2: _line2,
                      landmark: _landmark,
                      pincode: _pincode,
                      city: _city,
                      state: _state,
                      pin: _pin,
                      onPinChanged: (next, formatted) => setState(() {
                        _pin = next;
                        _formatted = formatted ?? _formatted;
                      }),
                      enabled: !_busy,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(XpertSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: XpertTypography.body.copyWith(
                        color: XpertColors.danger,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: XpertSpacing.sm),
                  ],
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(ref.t('address.cta.save')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
