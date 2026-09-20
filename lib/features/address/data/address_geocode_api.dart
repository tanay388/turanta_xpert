import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/config/keys.dart';
import '../../../core/location/location_service.dart';

/// What a dropped pin resolves to.
class PinAddress {
  const PinAddress({this.city, this.state, this.pincode, this.formatted});

  final String? city;
  final String? state;
  final String? pincode;

  /// The whole line as Google writes it, kept alongside the typed address.
  final String? formatted;
}

/// One row in the search suggestions.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
  });

  final String placeId;
  final String mainText;
  final String secondaryText;
}

/// A place the partner picked out of the search results.
class PickedPlace {
  const PickedPlace({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  final double latitude;
  final double longitude;
  final PinAddress? address;
}

/// Google Geocoding + Places, called straight from the app.
///
/// The same arrangement as the consumer app, down to the key. Going through
/// our own backend put the whole map behind our uptime, and a 504 there left a
/// partner staring at a pin that would not resolve.
class AddressGeocodeApi {
  const AddressGeocodeApi(this._dio);

  /// A bare Dio on purpose — the app's usual one attaches a Firebase token,
  /// which `maps.googleapis.com` rejects.
  final Dio _dio;

  static const _geocodeUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';
  static const _autocompleteUrl =
      'https://maps.googleapis.com/maps/api/place/autocomplete/json';
  static const _detailsUrl =
      'https://maps.googleapis.com/maps/api/place/details/json';

  /// Roughly a city around the map's centre, so "MG Road" offers the near one.
  static const _biasRadiusMetres = 50000;

  Future<PinAddress?> reverse(double lat, double lng) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        _geocodeUrl,
        queryParameters: {
          'latlng': '$lat,$lng',
          'key': AppKeys.googleGeocodingKey,
        },
      );
      final results = (res.data?['results'] as List?) ?? const [];
      if (results.isEmpty) return null;
      return _parse(results.first as Map<String, dynamic>);
    } catch (_) {
      // The partner still types the address; a failed lookup only means the
      // three fields stay as they are.
      return null;
    }
  }

  Future<List<PlaceSuggestion>> suggest(
    String query, {
    double? nearLat,
    double? nearLng,
  }) async {
    if (query.trim().length < 2) return const [];
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        _autocompleteUrl,
        queryParameters: {
          'input': query.trim(),
          'key': AppKeys.googlePlacesKey,
          'components': 'country:in',
          'language': 'en',
          if (nearLat != null && nearLng != null) ...{
            'location': '$nearLat,$nearLng',
            'radius': _biasRadiusMetres,
          },
        },
      );
      final predictions = (res.data?['predictions'] as List?) ?? const [];
      return predictions
          .whereType<Map<String, dynamic>>()
          .map((p) {
            final structured =
                p['structured_formatting'] as Map<String, dynamic>? ??
                const <String, dynamic>{};
            return PlaceSuggestion(
              placeId: p['place_id'] as String? ?? '',
              mainText:
                  structured['main_text'] as String? ??
                  p['description'] as String? ??
                  '',
              secondaryText: structured['secondary_text'] as String? ?? '',
            );
          })
          .where((s) => s.placeId.isNotEmpty)
          .toList();
    } catch (_) {
      // No suggestions is survivable: the map still pans.
      return const [];
    }
  }

  Future<PickedPlace?> place(String placeId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        _detailsUrl,
        queryParameters: {
          'place_id': placeId,
          'fields': 'geometry,address_components,formatted_address',
          'key': AppKeys.googlePlacesKey,
        },
      );
      final result = res.data?['result'] as Map<String, dynamic>?;
      final location =
          (result?['geometry'] as Map<String, dynamic>?)?['location']
              as Map<String, dynamic>?;
      final lat = (location?['lat'] as num?)?.toDouble();
      final lng = (location?['lng'] as num?)?.toDouble();
      if (result == null || lat == null || lng == null) return null;
      return PickedPlace(
        latitude: lat,
        longitude: lng,
        address: _parse(result),
      );
    } catch (_) {
      return null;
    }
  }

  /// Reads Google's `address_components` into the three fields the form fills.
  ///
  /// The fallback chain for the city is the load-bearing part. Indian results
  /// very often carry no `locality` at all: a pin in a Mumbai suburb comes
  /// back with `sublocality_level_1` and nothing else, and one on the edge of
  /// a district has only `administrative_area_level_2`. Taking `locality`
  /// alone leaves the field blank for a large share of real addresses.
  PinAddress _parse(Map<String, dynamic> result) {
    final components = (result['address_components'] as List?) ?? const [];

    String? find(List<String> types) {
      for (final type in types) {
        for (final raw in components) {
          final c = raw as Map<String, dynamic>;
          final cTypes = ((c['types'] as List?) ?? const []).cast<String>();
          if (cTypes.contains(type)) {
            final value = c['long_name'] as String?;
            if (value != null && value.isNotEmpty) return value;
          }
        }
      }
      return null;
    }

    return PinAddress(
      city: find([
        'locality',
        'sublocality_level_1',
        'administrative_area_level_3',
        'administrative_area_level_2',
      ]),
      state: find(['administrative_area_level_1']),
      pincode: find(['postal_code']),
      formatted: result['formatted_address'] as String?,
    );
  }
}

/// Unauthenticated, because these calls go to Google and not to us.
final _mapsDioProvider = Provider<Dio>(
  (ref) => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  ),
);

final addressGeocodeApiProvider = Provider<AddressGeocodeApi>(
  (ref) => AddressGeocodeApi(ref.watch(_mapsDioProvider)),
);

/// A quick, best-effort fix used only to centre the map.
///
/// Gives up fast and returns null rather than stalling the screen behind a GPS
/// lock — indoors, which is where people fill forms, a high-accuracy fix can
/// take far longer than anyone will wait.
final addressFixProvider = FutureProvider<Position?>((ref) async {
  try {
    return await ref
        .watch(locationServiceProvider)
        .current(
          timeLimit: const Duration(seconds: 6),
          accuracy: LocationAccuracy.medium,
        );
  } catch (_) {
    return null;
  }
});
