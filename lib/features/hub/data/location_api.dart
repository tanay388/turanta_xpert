import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../../../core/network/dio_client.dart';

class HubArea {
  const HubArea({required this.id, required this.name});

  final int id;
  final String name;

  factory HubArea.fromJson(Map<String, dynamic> json) {
    return HubArea(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
    );
  }
}

class HubCity {
  const HubCity({
    required this.id,
    required this.name,
    required this.areas,
    this.state,
    this.distanceKm,
  });

  final int id;
  final String name;
  final String? state;

  /// How far the partner is from the city centre; null without a fix.
  final double? distanceKm;
  final List<HubArea> areas;

  factory HubCity.fromJson(Map<String, dynamic> json) {
    final areas = json['areas'] as List<dynamic>? ?? const [];
    return HubCity(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      state: json['state'] as String?,
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      areas: areas
          .map((e) => HubArea.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class HubOption {
  const HubOption({required this.id, required this.name, this.address});

  final int id;
  final String name;
  final String? address;

  factory HubOption.fromJson(Map<String, dynamic> json) {
    return HubOption(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      address: json['address'] as String?,
    );
  }
}

/// Cities, their areas, and the hubs inside an area — the three choices a
/// partner makes when they join.
class LocationApi {
  LocationApi(this._dio);

  final Dio _dio;

  /// With a position, the server puts the closest city first.
  Future<List<HubCity>> cities({double? lat, double? lng}) async {
    final res = await _dio.get<List<dynamic>>(
      '/city',
      queryParameters: {
        if (lat != null && lng != null) 'lat': lat,
        if (lat != null && lng != null) 'lng': lng,
      },
    );
    return (res.data ?? const [])
        .map((e) => HubCity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<HubOption>> hubsInArea(int areaId) async {
    final res = await _dio.get<List<dynamic>>('/area/$areaId/hubs');
    return (res.data ?? const [])
        .map((e) => HubOption.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> chooseHub(int warehouseId) async {
    await _dio.patch<Map<String, dynamic>>(
      '/partner/hub',
      data: {'warehouseId': warehouseId},
    );
  }
}

final locationApiProvider = Provider<LocationApi>(
  (ref) => LocationApi(ref.watch(dioProvider)),
);

/// A best-effort fix, used only to order the city list. Onboarding must not
/// stall behind a GPS lock, so it gives up quickly and the list still loads.
final _onboardingFixProvider = FutureProvider<Position?>((ref) async {
  try {
    return await ref
        .watch(locationServiceProvider)
        .current(
          timeLimit: const Duration(seconds: 6),
          accuracy: LocationAccuracy.low,
        );
  } catch (_) {
    return null;
  }
});

final hubCitiesProvider = FutureProvider<List<HubCity>>((ref) async {
  final fix = await ref.watch(_onboardingFixProvider.future);
  return ref
      .watch(locationApiProvider)
      .cities(lat: fix?.latitude, lng: fix?.longitude);
});

final hubsInAreaProvider = FutureProvider.family<List<HubOption>, int>(
  (ref, areaId) => ref.watch(locationApiProvider).hubsInArea(areaId),
);
