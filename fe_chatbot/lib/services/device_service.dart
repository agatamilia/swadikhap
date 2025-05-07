import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

class DeviceService {
  static const String _deviceIdKey = 'device_id';
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  Future<String> getDeviceId() async {
    try {
      // First try to get from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString(_deviceIdKey);
      
      // If we already have a device ID, return it
      if (deviceId != null && deviceId.isNotEmpty) {
        print('Retrieved existing device ID: $deviceId');
        return deviceId;
      }
      
      // Otherwise, generate a new one
      deviceId = await _generateDeviceId();
      
      // Save it for future use
      await prefs.setString(_deviceIdKey, deviceId);
      print('Generated and saved new device ID: $deviceId');
      
      return deviceId;
    } catch (e) {
      print('Error getting device ID: $e');
      // Fallback to a random UUID if everything fails
      final fallbackId = const Uuid().v4();
      print('Using fallback device ID: $fallbackId');
      return fallbackId;
    }
  }
  
  Future<String> _generateDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        // Use a combination of Android ID and other identifiers
        return 'android_${androidInfo.id}_${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        // Use a combination of iOS identifiers
        return 'ios_${iosInfo.identifierForVendor ?? const Uuid().v4()}';
      } else {
        // For other platforms, generate a UUID
        return 'other_${const Uuid().v4()}';
      }
    } catch (e) {
      print('Error generating device ID: $e');
      return 'fallback_${const Uuid().v4()}';
    }
  }
  
  // Method to reset device ID (useful for testing)
  Future<void> resetDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_deviceIdKey);
      print('Device ID reset');
    } catch (e) {
      print('Error resetting device ID: $e');
    }
  }
}
