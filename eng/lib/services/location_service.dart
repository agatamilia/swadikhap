import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart';
import 'package:flutter/material.dart';

class LocationService extends ChangeNotifier {
  static final loc.Location _location = loc.Location();
  loc.LocationData? _currentLocation;

  loc.LocationData? get currentLocation => _currentLocation;

  // Get current position with timeout handling
  static Future<loc.LocationData?> getCurrentPosition() async {
    try {
      // Check and request location service
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) return null;
      }

      // Check and request permissions
      loc.PermissionStatus permission = await _location.hasPermission();
      if (permission == loc.PermissionStatus.denied) {
        permission = await _location.requestPermission();
        if (permission != loc.PermissionStatus.granted) return null;
      }

      if (permission == loc.PermissionStatus.deniedForever) return null;

      // Get location with timeout
      return await _location.getLocation().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('Location request timed out');
          return getMockPosition();
        },
      );
    } catch (e) {
      print('Location error: $e');
      return getMockPosition();
    }
  }

  // Improved mock position
  static loc.LocationData getMockPosition() {
    return loc.LocationData.fromMap({
      'latitude': -6.1944,  // Bogor coordinates
      'longitude': 106.8249,
      'accuracy': 50.0,
      'altitude': 0.0,
      'speed': 0.0,
      'speed_accuracy': 0.0,
      'heading': 0.0,
      'time': DateTime.now().millisecondsSinceEpoch.toDouble(),
    });
  }

  static Future<String> getPlaceFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isEmpty) return 'Bogor';

      final place = placemarks.first;

      final locationName = [
        place.subLocality,
        place.locality,
      ].firstWhere(
        (name) => name != null && name.isNotEmpty,
        orElse: () => 'Bogor',
      );

      return locationName ?? 'Bogor'; // Ensure we always return a String
    } catch (e) {
      print('Geocoding error: $e');
      return 'Bogor';
    }
  }

  // New method to get complete location
  static Future<Map<String, dynamic>> getCompleteLocation() async {
    final position = await getCurrentPosition() ?? getMockPosition();
    final placeName = await getPlaceFromCoordinates(
      position.latitude ?? -6.243,
      position.longitude ?? 105.8593585
    );

    return {
      'coordinates': {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
      },
      'address': placeName,
      'isMocked': position == getMockPosition(), // Manual mock check
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // Method to update location and notify listeners
  Future<void> updateLocation() async {
    _currentLocation = await getCurrentPosition();
    notifyListeners(); // Notify listeners when location changes
  }
}
