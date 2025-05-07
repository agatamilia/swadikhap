import 'package:flutter/material.dart';
import 'package:location/location.dart' as loc;
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final loc.Location _location = loc.Location();
  
  // Location permissions using location package
  static Future<bool> hasLocationPermission() async {
    loc.PermissionStatus permission = await _location.hasPermission();
    return permission == loc.PermissionStatus.granted || 
           permission == loc.PermissionStatus.grantedLimited;
  }

  static Future<bool> requestLocationPermission() async {
    loc.PermissionStatus permission = await _location.requestPermission();
    return permission == loc.PermissionStatus.granted || 
           permission == loc.PermissionStatus.grantedLimited;
  }

  static Future<bool> isLocationServiceEnabled() async {
    return await _location.serviceEnabled();
  }

  // Microphone permissions
  static Future<bool> hasMicrophonePermission() async {
    return await Permission.microphone.isGranted;
  }

  static Future<bool> requestMicrophonePermission() async {
    PermissionStatus status = await Permission.microphone.request();
    return status.isGranted;
  }

  // Storage permissions
  static Future<bool> hasStoragePermission() async {
    if (await Permission.storage.isGranted) {
      return true;
    }
    
    // For Android 13+, we need to check for photos permission as well
    return await Permission.photos.isGranted;
  }

  static Future<bool> requestStoragePermission() async {
    // Request storage permission
    PermissionStatus storageStatus = await Permission.storage.request();
    
    // For Android 13+, also request photos permission
    PermissionStatus photosStatus = await Permission.photos.request();
    
    return storageStatus.isGranted || photosStatus.isGranted;
  }

  // Camera permissions
  static Future<bool> hasCameraPermission() async {
    return await Permission.camera.isGranted;
  }

  static Future<bool> requestCameraPermission() async {
    PermissionStatus status = await Permission.camera.request();
    return status.isGranted;
  }

  // Dialog to show when permission is denied
  static Future<void> showPermissionDialog(BuildContext context, String permissionName) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Izin $permissionName Diperlukan'),
          content: Text(
            'Aplikasi memerlukan izin $permissionName untuk berfungsi dengan baik. '
            'Silakan aktifkan izin di pengaturan perangkat Anda.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Buka Pengaturan'),
            ),
          ],
        );
      },
    );
  }
}
