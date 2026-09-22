import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/i18n/context_t.dart';
import '../../../core/location/location_service.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../data/address_geocode_api.dart';

/// What the picker hands back.
class PickedPin {
  const PickedPin({required this.position, this.address});

  final LatLng position;
  final PinAddress? address;
}

/// Mumbai, used only when there is no pin and no fix to centre on.
const _fallbackCentre = LatLng(19.076, 72.8777);

/// A full-screen map for dropping a home pin.
///
/// A page of its own rather than a map inside the KYC step, for two reasons:
/// the wizard swaps steps through an `AnimatedSwitcher` keyed on the step, so
/// an inline map would be torn down and rebuilt — a fresh platform view — on
/// every visit; and a map inside the wizard's scroll view fights it for
/// vertical drags.
///
/// The pin is fixed at the centre and the map moves under it, which is both
/// the convention people know from food delivery apps and far less fiddly than
/// dragging a marker with a thumb.
class AddressMapScreen extends ConsumerStatefulWidget {
  const AddressMapScreen({super.key, this.initial});

  /// A pin already saved, if the partner is coming back to adjust it.
  final LatLng? initial;

  @override
  ConsumerState<AddressMapScreen> createState() => _AddressMapScreenState();
}

class _AddressMapScreenState extends ConsumerState<AddressMapScreen> {
  GoogleMapController? _map;

  /// Where the pin is. Seeded at construction rather than waiting for
  /// `onMapCreated`, because the pin is at the starting centre from the first
  /// frame — and a map that never loads should not leave this null.
  late LatLng _centre = widget.initial ?? _fallbackCentre;
  PinAddress? _address;
  bool _looking = false;
  Timer? _debounce;
  bool _centredOnFix = false;

  final _search = TextEditingController();
  Timer? _searchDebounce;
  List<PlaceSuggestion> _suggestions = const [];
  bool _locating = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchDebounce?.cancel();
    _search.dispose();
    _map?.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _suggestions = const []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      final found = await ref
          .read(addressGeocodeApiProvider)
          .suggest(
            value,
            nearLat: _centre.latitude,
            nearLng: _centre.longitude,
          );
      if (!mounted) return;
      setState(() => _suggestions = found);
    });
  }

  Future<void> _choose(PlaceSuggestion suggestion) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _suggestions = const [];
      _search.text = suggestion.mainText;
    });
    final place = await ref
        .read(addressGeocodeApiProvider)
        .place(suggestion.placeId);
    if (!mounted || place == null) return;
    final target = LatLng(place.latitude, place.longitude);
    _centre = target;
    // The address came back with the place, so skip the lookup the camera
    // move would otherwise trigger.
    _debounce?.cancel();
    setState(() => _address = place.address);
    await _map?.animateCamera(CameraUpdate.newLatLngZoom(target, 17));
  }

  /// Centres on where the partner actually is.
  Future<void> _goToMyLocation() async {
    setState(() => _locating = true);
    final fix = await ref.read(locationServiceProvider).current();
    if (!mounted) return;
    setState(() => _locating = false);
    if (fix == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(ref.t('address.map.no_location'))),
        );
      return;
    }
    _centre = LatLng(fix.latitude, fix.longitude);
    await _map?.animateCamera(CameraUpdate.newLatLngZoom(_centre, 17));
  }

  /// Only when the map settles — looking up on every frame of a pan is both
  /// useless and a lot of requests.
  void _onIdle() {
    final centre = _centre;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) return;
      setState(() => _looking = true);
      final resolved = await ref
          .read(addressGeocodeApiProvider)
          .reverse(centre.latitude, centre.longitude);
      if (!mounted) return;
      setState(() {
        _address = resolved;
        _looking = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // A fix that lands after the map is built still moves the camera once,
    // because `initialCameraPosition` is read only on creation.
    final fix = ref.watch(addressFixProvider).valueOrNull;
    if (widget.initial == null && fix != null && !_centredOnFix) {
      _centredOnFix = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _map?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(fix.latitude, fix.longitude), 17),
        );
      });
    }

    final start = widget.initial ?? _fallbackCentre;

    return Scaffold(
      backgroundColor: XpertColors.background,
      appBar: AppBar(title: Text(ref.t('address.map.title'))),
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: start,
                zoom: widget.initial != null ? 17 : 12,
              ),
              onMapCreated: (c) {
                _map = c;
                _onIdle();
              },
              onCameraMove: (position) => _centre = position.target,
              onCameraIdle: _onIdle,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
            ),
          ),
          // The pin sits dead centre and never moves; the map slides beneath.
          IgnorePointer(
            child: Center(
              child: Padding(
                // Lifts the point of the pin onto the centre of the map,
                // rather than the middle of the icon.
                padding: const EdgeInsets.only(bottom: 36),
                child: Icon(
                  Icons.location_on,
                  size: 44,
                  color: XpertColors.primary,
                ),
              ),
            ),
          ),
          // Sits above the map so a tap on a suggestion is not a tap on the
          // map underneath it.
          Positioned(
            left: XpertSpacing.md,
            right: XpertSpacing.md,
            top: XpertSpacing.md,
            child: _SearchBar(
              controller: _search,
              suggestions: _suggestions,
              onChanged: _onSearchChanged,
              onPick: _choose,
            ),
          ),
          Positioned(
            right: XpertSpacing.md,
            bottom: 190,
            child: _MyLocationButton(
              busy: _locating,
              onTap: () => _goToMyLocation(),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ConfirmPanel(
              address: _address,
              looking: _looking,
              onConfirm: () => Navigator.of(
                context,
              ).pop(PickedPin(position: _centre, address: _address)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmPanel extends ConsumerWidget {
  const _ConfirmPanel({
    required this.address,
    required this.looking,
    required this.onConfirm,
  });

  final PinAddress? address;
  final bool looking;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final line = address?.formatted;
    return Container(
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(XpertRadius.lg),
        ),
        boxShadow: [
          BoxShadow(
            color: XpertColors.canvas.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(XpertSpacing.lg),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              ref.t('address.map.hint'),
              style: XpertTypography.caption.copyWith(fontSize: 12.5),
            ),
            const SizedBox(height: XpertSpacing.xs),
            Text(
              looking
                  ? ref.t('address.map.looking')
                  : (line ?? ref.t('address.map.no_address')),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: XpertTypography.body.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: XpertSpacing.md),
            FilledButton(
              onPressed: onConfirm,
              child: Text(ref.t('address.map.confirm')),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends ConsumerWidget {
  const _SearchBar({
    required this.controller,
    required this.suggestions,
    required this.onChanged,
    required this.onPick,
  });

  final TextEditingController controller;
  final List<PlaceSuggestion> suggestions;
  final ValueChanged<String> onChanged;
  final ValueChanged<PlaceSuggestion> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: XpertColors.surface,
          elevation: 3,
          borderRadius: BorderRadius.circular(XpertRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: XpertSpacing.md),
            child: Row(
              children: [
                Icon(Icons.search, size: 20, color: XpertColors.muted),
                const SizedBox(width: XpertSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: ref.t('address.map.search_hint'),
                    ),
                  ),
                ),
                if (controller.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
              ],
            ),
          ),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: XpertSpacing.xs),
          Material(
            color: XpertColors.surface,
            elevation: 3,
            borderRadius: BorderRadius.circular(XpertRadius.md),
            clipBehavior: Clip.antiAlias,
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: suggestions.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: XpertColors.border),
              itemBuilder: (_, i) {
                final s = suggestions[i];
                return ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.location_on_outlined,
                    size: 20,
                    color: XpertColors.muted,
                  ),
                  title: Text(
                    s.mainText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: XpertTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: s.secondaryText.isEmpty
                      ? null
                      : Text(
                          s.secondaryText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: XpertTypography.caption.copyWith(fontSize: 12),
                        ),
                  onTap: () => onPick(s),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _MyLocationButton extends StatelessWidget {
  const _MyLocationButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: XpertColors.surface,
      elevation: 4,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: busy
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Icon(
                  Icons.my_location_rounded,
                  size: 22,
                  color: XpertColors.primary,
                ),
        ),
      ),
    );
  }
}
