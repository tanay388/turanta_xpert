import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../app/shell/xpert_sections.dart';
import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../data/hub_api.dart';

/// The partner's service area.
///
/// The map used to sit mid-list at a fixed 280pt, which meant it fought the
/// scroll: a drag started on the map panned the map instead of moving the
/// page, and there was no comfortable way past it. It is now the top of the
/// screen and outside the scroll view, so panning it and scrolling the page
/// are two different gestures in two different places.
class HubScreen extends ConsumerWidget {
  const HubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(partnerHubProvider);

    return Scaffold(
      backgroundColor: XpertColors.background,
      appBar: AppBar(title: Text(ref.t('hub.title'))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        // The raw exception used to be printed onto the screen.
        error: (_, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            EmptyState(
              icon: Icons.map_outlined,
              title: ref.t('hub.error.title'),
              body: ref.t('hub.error.body'),
              action: FilledButton(
                onPressed: () => ref.invalidate(partnerHubProvider),
                child: Text(ref.t('hub.retry')),
              ),
            ),
          ],
        ),
        data: (hub) => _HubBody(hub: hub),
      ),
    );
  }
}

class _HubBody extends ConsumerWidget {
  const _HubBody({required this.hub});

  final PartnerHub hub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _HubMap(hub: hub),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              XpertSpacing.lg,
              XpertSpacing.lg,
              XpertSpacing.lg,
              XpertSpacing.xxl,
            ),
            children: [
              _HubIdentity(hub: hub),
              const SizedBox(height: XpertSpacing.xl),
              SectionLabel(ref.t('hub.about')),
              const SizedBox(height: XpertSpacing.sm),
              const _Explainer(
                icon: Icons.info_outline_rounded,
                titleKey: 'hub.what_is.title',
                bodyKey: 'hub.what_is.body',
              ),
              const SizedBox(height: XpertSpacing.sm),
              const _Explainer(
                icon: Icons.near_me_outlined,
                titleKey: 'hub.outside.title',
                bodyKey: 'hub.outside.body',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The hub's name and address, with the shaded area on the map above it
/// named as what it is.
class _HubIdentity extends ConsumerWidget {
  const _HubIdentity({required this.hub});

  final PartnerHub hub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = hub.address?.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: XpertColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(XpertRadius.md),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.location_city_rounded,
            size: 19,
            color: XpertColors.primary,
          ),
        ),
        const SizedBox(width: XpertSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hub.name,
                style: XpertTypography.title.copyWith(fontSize: 19),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (address != null && address.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  address,
                  style: XpertTypography.caption.copyWith(fontSize: 12.5),
                  maxLines: 3,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HubMap extends ConsumerWidget {
  const _HubMap({required this.hub});

  final PartnerHub hub;

  static const _fallback = LatLng(19.076, 72.8777);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final center = hub.center != null
        ? LatLng(hub.center!.lat, hub.center!.lng)
        : _fallback;

    final points = hub.polygonRing
        .map((p) => LatLng(p[1], p[0])) // GeoJSON is [lng, lat]
        .toList();

    final polygons = <Polygon>{};
    if (points.length >= 3) {
      polygons.add(
        Polygon(
          polygonId: const PolygonId('hub'),
          points: points,
          strokeWidth: 2,
          strokeColor: XpertColors.primary,
          fillColor: XpertColors.primary.withValues(alpha: 0.18),
        ),
      );
    }

    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: center, zoom: 13),
              polygons: polygons,
              markers: {
                Marker(
                  markerId: const MarkerId('hub-center'),
                  position: center,
                  infoWindow: InfoWindow(title: hub.name),
                ),
              },
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
            ),
          ),
          // A legend, because a shaded blob on a map is not self-explanatory —
          // the polygon is the area jobs come from, and nothing said so.
          Positioned(
            left: XpertSpacing.md,
            bottom: XpertSpacing.md,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: XpertColors.surface,
                borderRadius: BorderRadius.circular(XpertRadius.pill),
                boxShadow: [
                  BoxShadow(
                    color: XpertColors.canvas.withValues(alpha: 0.16),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: XpertSpacing.sm + 2,
                  vertical: 7,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: XpertColors.primary.withValues(alpha: 0.25),
                        border: Border.all(color: XpertColors.primary),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      ref.t('hub.legend'),
                      style: XpertTypography.caption.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: XpertColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Explainer extends ConsumerWidget {
  const _Explainer({
    required this.icon,
    required this.titleKey,
    required this.bodyKey,
  });

  final IconData icon;
  final String titleKey;
  final String bodyKey;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: XpertColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(XpertRadius.sm),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 17, color: XpertColors.primary),
          ),
          const SizedBox(width: XpertSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ref.t(titleKey),
                  style: XpertTypography.label.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  ref.t(bodyKey),
                  style: XpertTypography.caption.copyWith(
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
