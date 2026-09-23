import 'package:geolocator/geolocator.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Why a fix could not be taken.
///
/// The difference decides what the partner is told to do, and getting it
/// wrong costs them a shift: "grant permission" is useless advice to someone
/// whose permission is already granted and whose GPS is switched off.
enum LocationDenial {
  /// Refused this time. Asking again will prompt again.
  denied,

  /// Refused for good. iOS shows its dialog once per install, so nothing the
  /// app does will bring it back — only [LocationService.openSettings] will.
  blocked,

  /// Permitted, but the device's location services are off.
  servicesOff,

  /// Permitted and switched on, but no fix arrived in time.
  unavailable,
}

/// The i18n key that explains a denial to the partner. Kept beside the enum
/// so a new cause cannot be added without a sentence for it.
String denialMessageKey(LocationDenial denial) => switch (denial) {
  LocationDenial.denied => 'location.denied',
  LocationDenial.blocked => 'location.blocked',
  LocationDenial.servicesOff => 'location.services_off',
  LocationDenial.unavailable => 'location.unavailable',
};

class LocationFix {
  const LocationFix.found(Position this.position) : denial = null;
  const LocationFix.denied(LocationDenial this.denial) : position = null;

  final Position? position;
  final LocationDenial? denial;
}

/// One place to ask for a fix.
///
/// Check-in and job start each grew their own copy of this with different
/// timeouts; SOS would have been a third. The timeout is a parameter because
/// the callers genuinely differ — a check-in can wait, an emergency cannot.
class LocationService {
  const LocationService();

  /// Null when a fix could not be taken, whatever the cause. Callers that
  /// have something useful to say about the cause use [locate] instead.
  Future<Position?> current({
    Duration timeLimit = const Duration(seconds: 15),
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    final fix = await locate(timeLimit: timeLimit, accuracy: accuracy);
    return fix.position;
  }

  Future<LocationFix> locate({
    Duration timeLimit = const Duration(seconds: 15),
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationFix.denied(LocationDenial.blocked);
    }
    if (permission == LocationPermission.denied) {
      return const LocationFix.denied(LocationDenial.denied);
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationFix.denied(LocationDenial.servicesOff);
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeLimit,
        ),
      );
      return LocationFix.found(position);
    } catch (_) {
      // getCurrentPosition throws on timeout, which is a denial like any
      // other here — callers that let it escape showed the partner a raw
      // `TimeoutException after 0:00:15.000000`.
      return const LocationFix.denied(LocationDenial.unavailable);
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

  /// The only way out of [LocationDenial.blocked].
  Future<bool> openSettings() => Geolocator.openAppSettings();

  /// Location services themselves, for [LocationDenial.servicesOff] — the app
  /// permission screen has no switch for those.
  Future<bool> openDeviceLocationSettings() =>
      Geolocator.openLocationSettings();
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => const LocationService(),
);
