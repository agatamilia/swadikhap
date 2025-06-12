import 'package:flutter/material.dart';
import './services/location_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/device_service.dart';
import 'services/api_service.dart'; // Add this import
import 'providers/session_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return const SizedBox.shrink();
  };

  // Initialize services
  final deviceService = DeviceService();
  await deviceService.initialize();
  final apiService = ApiService(); // Create ApiService instance
  final deviceId = await deviceService.getDeviceId();
  
  print('Device ID: $deviceId');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SessionProvider(
            apiService: apiService,
            deviceService: deviceService,
          ),
        ),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => LocationService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PeTaniku',
      theme: appTheme,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}