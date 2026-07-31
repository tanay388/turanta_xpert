import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/dio_client.dart';

/// Hub map center (polygon centroid from PostGIS).
class HubCenter {
  const HubCenter({required this.lat, required this.lng});
  final double lat;
  final double lng;

  factory HubCenter.fromJson(Map<String, dynamic> json) {
    return HubCenter(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}

/// Partner hub payload from `GET /partner/hub`.
class PartnerHub {
  const PartnerHub({
    required this.id,
    required this.name,
    this.address,
    this.center,
    this.serviceAreaGeoJson,
  });

  final int id;
  final String name;
  final String? address;
  final HubCenter? center;
  final Map<String, dynamic>? serviceAreaGeoJson;

  /// Outer ring of the service-area polygon as [lng, lat] pairs.
  List<List<double>> get polygonRing {
    final geo = serviceAreaGeoJson;
    if (geo == null) return const [];
    final coords = geo['coordinates'];
    if (coords is! List || coords.isEmpty) return const [];
    final ring = coords.first;
    if (ring is! List) return const [];
    return ring
        .whereType<List>()
        .where((p) => p.length >= 2)
        .map((p) => [(p[0] as num).toDouble(), (p[1] as num).toDouble()])
        .toList();
  }

  factory PartnerHub.fromJson(Map<String, dynamic> json) {
    final center = json['center'];
    final geo = json['serviceAreaGeoJson'];
    return PartnerHub(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? '',
      address: json['address'] as String?,
      center: center is Map<String, dynamic> ? HubCenter.fromJson(center) : null,
      serviceAreaGeoJson: geo is Map<String, dynamic> ? geo : null,
    );
  }
}

class HubApi {
  HubApi(this._dio);
  final Dio _dio;

  Future<PartnerHub> get() async {
    final res = await _dio.get<Map<String, dynamic>>('/partner/hub');
    return PartnerHub.fromJson(res.data ?? const {});
  }
}

final hubApiProvider = Provider<HubApi>((ref) {
  return HubApi(ref.watch(dioProvider));
});

final partnerHubProvider = FutureProvider<PartnerHub>((ref) async {
  return ref.watch(hubApiProvider).get();
});
