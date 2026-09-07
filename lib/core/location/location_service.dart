import 'package:geolocator/geolocator.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// One place to ask for a fix.
///
/// Check-in and job start each grew their own copy of this with different
/// timeouts; SOS would have been a third. The timeout is a parameter because
/// the callers genuinely differ — a check-in can wait, an emergency cannot.
class LocationService {
  const LocationService();

  /// Null when permission is refused or location services are switched off.
  Future<Position?> current({
    Duration timeLimit = const Duration(seconds: 15),
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    if (!await _permitted()) return null;
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeLimit,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// A fix for an emergency: try briefly for a fresh one, then fall back to
  /// whatever the OS already had. A stale position beats no position when
  /// someone has pressed SOS.
  Future<Position?> currentOrLastKnown({
    Duration timeLimit = const Duration(seconds: 5),
  }) async {
    final fresh = await current(timeLimit: timeLimit);
    if (fresh != null) return fresh;
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _permitted() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }
    return Geolocator.isLocationServiceEnabled();
  }
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => const LocationService(),
);
