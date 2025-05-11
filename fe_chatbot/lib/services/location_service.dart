import 'package:flutter/material.dart';
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart';
import '../models/weather_data.dart';
import '../services/api_service.dart';

class LocationService extends ChangeNotifier {
  static final LocationService _instance = LocationService._internal();
  final loc.Location _location = loc.Location();
  final ApiService _apiService = ApiService();
  
  loc.LocationData? _currentLocation;
  Placemark? _placemark;
  WeatherData? _weatherData;
  bool _isLoading = true;
  
  // Getters
  loc.LocationData? get currentLocation => _currentLocation;
  Placemark? get placemark => _placemark;
  WeatherData? get weatherData => _weatherData;
  bool get isLoading => _isLoading;
  
  factory LocationService() {
    return _instance;
  }
  
  LocationService._internal();
  
  Future<void> getCurrentLocation() async {
    if (_currentLocation != null && !_isLoading) {
      return; // Already have location data
    }
    
    _isLoading = true;
    notifyListeners();
    
    try {
      // Check if location service is enabled
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      // Check location permission
      loc.PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == loc.PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != loc.PermissionStatus.granted) {
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      // Get current location
      _currentLocation = await _location.getLocation();
      
      // Get place name from coordinates
      if (_currentLocation != null && 
          _currentLocation!.latitude != null && 
          _currentLocation!.longitude != null) {
        
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(
            _currentLocation!.latitude!,
            _currentLocation!.longitude!,
          );
          
          if (placemarks.isNotEmpty) {
            _placemark = placemarks.first;
          }
        } catch (e) {
          print('Error getting placemark: $e');
        }
        
        // Get weather data
        try {
          _weatherData = await _apiService.getWeather(
            _currentLocation!.latitude!,
            _currentLocation!.longitude!,
          );
        } catch (e) {
          print('Error getting weather data: $e');
        }
      }
    } catch (e) {
      print('Error getting location: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Refresh weather data
  Future<void> refreshWeather() async {
    if (_currentLocation == null || 
        _currentLocation!.latitude == null || 
        _currentLocation!.longitude == null) {
      return;
    }
    
    try {
      _weatherData = await _apiService.getWeather(
        _currentLocation!.latitude!,
        _currentLocation!.longitude!,
      );
      notifyListeners();
    } catch (e) {
      print('Error refreshing weather data: $e');
    }
  }
}
