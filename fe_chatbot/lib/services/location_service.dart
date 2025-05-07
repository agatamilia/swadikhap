import 'package:flutter/material.dart';
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart';

class LocationService {
  static final loc.Location _location = loc.Location();
  
  // Get current position with location package
  static Future<loc.LocationData?> getCurrentPosition() async {
    bool serviceEnabled;
    loc.PermissionStatus permissionGranted;

    try {
      // Check if location service is enabled
      serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          print('Location services are disabled');
          return null;
        }
      }

      // Check location permission
      permissionGranted = await _location.hasPermission();
      if (permissionGranted == loc.PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != loc.PermissionStatus.granted) {
          print('Location permissions are denied');
          return null;
        }
      }

      // Get current location
      final locationData = await _location.getLocation().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('Location request timed out');
          return loc.LocationData.fromMap({
            'latitude': -6.2088, // Default to Jakarta
            'longitude': 106.8456,
            'accuracy': 0,
            'altitude': 0,
            'speed': 0,
            'speed_accuracy': 0,
            'heading': 0,
            'time': DateTime.now().millisecondsSinceEpoch,
            'isMock': true,
          });
        },
      );
      
      print('Location obtained: ${locationData.latitude}, ${locationData.longitude}');
      return locationData;
    } catch (e) {
      print('Error getting location: $e');
      // Return mock location data for Jakarta as fallback
      return loc.LocationData.fromMap({
        'latitude': -6.2088,
        'longitude': 106.8456,
        'accuracy': 0,
        'altitude': 0,
        'speed': 0,
        'speed_accuracy': 0,
        'heading': 0,
        'time': DateTime.now().millisecondsSinceEpoch,
        'isMock': true,
      });
    }
  }

  // Get place name from coordinates using geocoding package
  static Future<String> getPlaceFromCoordinates(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final locality = place.locality ?? '';
        final subAdministrativeArea = place.subAdministrativeArea ?? '';
        
        if (locality.isNotEmpty) {
          return locality;
        } else if (subAdministrativeArea.isNotEmpty) {
          return subAdministrativeArea;
        } else {
          return place.administrativeArea ?? 'Unknown location';
        }
      }
      
      return 'Unknown location';
    } catch (e) {
      print('Error getting place from coordinates: $e');
      return 'Unknown location';
    }
  }
}
