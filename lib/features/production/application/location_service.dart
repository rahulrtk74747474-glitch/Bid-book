import 'package:geolocator/geolocator.dart';

class BidBookLocation {
  const BidBookLocation({required this.latitude, required this.longitude});
  final double latitude;
  final double longitude;
}

class LocationService {
  const LocationService();

  Future<BidBookLocation> currentLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw StateError('Turn on location services to find nearby providers.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw StateError('Location permission was denied. You can still search by area.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw StateError(
        'Location permission is disabled for Bid&Book. Enable it in system settings to use nearby search.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return BidBookLocation(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}
