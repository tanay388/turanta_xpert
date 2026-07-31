import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../data/hub_api.dart';

/// Partner hub / service-area map with explainer cards.
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
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(XpertSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.toString(), textAlign: TextAlign.center),
                const SizedBox(height: XpertSpacing.md),
                TextButton(
                  onPressed: () => ref.invalidate(partnerHubProvider),
                  child: Text(ref.t('hub.retry')),
                ),
              ],
            ),
          ),
        ),
        data: (hub) => _HubBody(hub: hub),
      ),
    );
  }
}

class _HubBody extends StatelessWidget {
  const _HubBody({required this.hub});
  final PartnerHub hub;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(XpertSpacing.lg),
      children: [
        Text(hub.name, style: XpertTypography.title.copyWith(fontSize: 22)),
        if (hub.address != null && hub.address!.trim().isNotEmpty) ...[
          const SizedBox(height: XpertSpacing.xs),
          Text(hub.address!, style: XpertTypography.caption),
        ],
        const SizedBox(height: XpertSpacing.md),
        _HubMap(hub: hub),
        const SizedBox(height: XpertSpacing.lg),
        const _ExplainerCard(
          icon: Icons.info_outline_rounded,
          titleKey: 'hub.what_is.title',
          bodyKey: 'hub.what_is.body',
        ),
        const SizedBox(height: XpertSpacing.sm),
        const _ExplainerCard(
          icon: Icons.near_me_outlined,
          titleKey: 'hub.outside.title',
          bodyKey: 'hub.outside.body',
        ),
      ],
    );
  }
}

class _HubMap extends StatelessWidget {
  const _HubMap({required this.hub});
  final PartnerHub hub;

  static const _fallback = LatLng(19.076, 72.8777);

  @override
  Widget build(BuildContext context) {
    final center = hub.center != null
        ? LatLng(hub.center!.lat, hub.center!.lng)
        : _fallback;

    final ring = hub.polygonRing;
    final points = ring
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

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('hub-center'),
        position: center,
        infoWindow: InfoWindow(title: hub.name),
      ),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(XpertRadius.md),
      child: SizedBox(
        height: 280,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: center, zoom: 13),
          polygons: polygons,
          markers: markers,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
        ),
      ),
    );
  }
}

class _ExplainerCard extends ConsumerWidget {
  const _ExplainerCard({
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
        borderRadius: BorderRadius.circular(XpertRadius.md),
        border: Border.all(color: XpertColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: XpertColors.muted),
          const SizedBox(width: XpertSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ref.t(titleKey), style: XpertTypography.label),
                const SizedBox(height: 4),
                Text(ref.t(bodyKey), style: XpertTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
