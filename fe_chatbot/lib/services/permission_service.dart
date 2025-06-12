import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  // Meminta izin lokasi
  static Future<bool> requestLocationPermission() async {
    print('Meminta izin lokasi');

    // Cek terlebih dahulu apakah layanan lokasi aktif
    bool serviceEnabled = await Permission.locationWhenInUse.serviceStatus.isEnabled;
    if (!serviceEnabled) {
      print('Layanan lokasi tidak aktif');
      return false;
    }

    var status = await Permission.locationWhenInUse.status;
    print('Status izin lokasi saat ini: $status');

    if (status.isDenied) {
      status = await Permission.locationWhenInUse.request();
      print('Status izin lokasi setelah diminta: $status');
    }

    if (status.isPermanentlyDenied) {
      print('Izin lokasi ditolak secara permanen');
      return false;
    }

    return status.isGranted;
  }

  // Meminta izin mikrofon
  static Future<bool> requestMicrophonePermission() async {
    print('Meminta izin mikrofon');
    var status = await Permission.microphone.status;
    print('Status izin mikrofon saat ini: $status');

    if (status.isDenied) {
      status = await Permission.microphone.request();
      print('Status izin mikrofon setelah diminta: $status');
    }

    if (status.isPermanentlyDenied) {
      print('Izin mikrofon ditolak secara permanen');
      return false;
    }

    return status.isGranted;
  }

  // Meminta izin penyimpanan
  static Future<bool> requestStoragePermission() async {
    print('Meminta izin penyimpanan');

    // Untuk Android 13+ (API 33+), perlu minta izin terpisah
    bool hasPhotoPermission = false;
    bool hasVideoPermission = false;
    bool hasAudioPermission = false;

    // Cek izin foto
    if (await Permission.photos.status.isDenied) {
      final photoStatus = await Permission.photos.request();
      hasPhotoPermission = photoStatus.isGranted;
    } else {
      hasPhotoPermission = await Permission.photos.isGranted;
    }

    // Cek izin video
    if (await Permission.videos.status.isDenied) {
      final videoStatus = await Permission.videos.request();
      hasVideoPermission = videoStatus.isGranted;
    } else {
      hasVideoPermission = await Permission.videos.isGranted;
    }

    // Cek izin audio
    if (await Permission.audio.status.isDenied) {
      final audioStatus = await Permission.audio.request();
      hasAudioPermission = audioStatus.isGranted;
    } else {
      hasAudioPermission = await Permission.audio.isGranted;
    }

    // Untuk Android versi lama, gunakan izin penyimpanan umum
    var storageStatus = await Permission.storage.status;
    print('Status izin penyimpanan saat ini: $storageStatus');

    if (storageStatus.isDenied) {
      storageStatus = await Permission.storage.request();
      print('Status izin penyimpanan setelah diminta: $storageStatus');
    }

    if (storageStatus.isPermanentlyDenied &&
        !hasPhotoPermission &&
        !hasVideoPermission &&
        !hasAudioPermission) {
      print('Semua izin penyimpanan ditolak secara permanen');
      return false;
    }

    return storageStatus.isGranted ||
           hasPhotoPermission ||
           hasVideoPermission ||
           hasAudioPermission;
  }

  // Cek apakah izin lokasi sudah diberikan
  static Future<bool> hasLocationPermission() async {
    return await Permission.locationWhenInUse.isGranted;
  }

  // Cek apakah izin mikrofon sudah diberikan
  static Future<bool> hasMicrophonePermission() async {
    return await Permission.microphone.isGranted;
  }

  // Cek apakah izin penyimpanan sudah diberikan
  static Future<bool> hasStoragePermission() async {
    return await Permission.storage.isGranted ||
           await Permission.photos.isGranted ||
           await Permission.videos.isGranted ||
           await Permission.audio.isGranted;
  }

  // Meminta semua izin yang dibutuhkan aplikasi
  static Future<Map<String, bool>> requestAllPermissions() async {
    Map<String, bool> permissions = {
      'location': false,
      'microphone': false,
      'storage': false,
    };

    // Beri jeda antar permintaan izin agar tidak membanjiri pengguna
    permissions['location'] = await requestLocationPermission();
    print('Hasil izin lokasi: ${permissions['location']}');
    await Future.delayed(const Duration(milliseconds: 500));

    permissions['microphone'] = await requestMicrophonePermission();
    print('Hasil izin mikrofon: ${permissions['microphone']}');
    await Future.delayed(const Duration(milliseconds: 500));

    permissions['storage'] = await requestStoragePermission();
    print('Hasil izin penyimpanan: ${permissions['storage']}');

    return permissions;
  }

  // Tampilkan dialog izin jika izin ditolak
  static Future<void> showPermissionDialog(BuildContext context, String permissionName) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$permissionName Diperlukan'),
          content: Text('Aplikasi memerlukan izin $permissionName untuk berfungsi dengan baik. Silakan aktifkan di pengaturan aplikasi.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
              child: const Text('Buka Pengaturan'),
            ),
          ],
        );
      },
    );
  }
}
