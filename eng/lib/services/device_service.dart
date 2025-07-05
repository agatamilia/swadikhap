import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';

class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  String? _deviceId;
  
  factory DeviceService() {
    return _instance;
  }
  
  DeviceService._internal();
  
  Future<void> initialize() async {
    await getDeviceId();
  }

  Future<String> getDeviceId() async {
    if (_deviceId != null) {
      return _deviceId!;
    }
    
    final prefs = await SharedPreferences.getInstance();
    String? storedId = prefs.getString('device_id');
    
    if (storedId != null && storedId.isNotEmpty) {
      _deviceId = storedId;
      return storedId;
    }
    
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        _deviceId = 'android_${androidInfo.id}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        _deviceId = 'ios_${iosInfo.identifierForVendor}';
      } else {
        // Fallback for other platforms
        _deviceId = 'device_${const Uuid().v4()}';
      }
    } catch (e) {
      print('Error getting device info: $e');
      // Generate a random ID if device info fails
      _deviceId = 'device_${const Uuid().v4()}';
    }
    
    // Store the ID for future use
    await prefs.setString('device_id', _deviceId!);
    print('Generated device ID: $_deviceId');
    
    return _deviceId!;
  }
}