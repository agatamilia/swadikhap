import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../models/weather_data.dart';

class WeatherWidget extends StatefulWidget {
  const WeatherWidget({Key? key}) : super(key: key);

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  final ApiService _apiService = ApiService();
  WeatherState _state = WeatherState.loading;
  WeatherData? _weatherData;
  String _locationName = 'Mencari lokasi saat ini...';
  String _errorMessage = '';
  bool _expanded = false;


  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    try {
      setState(() {
        _state = WeatherState.loading;
        _errorMessage = '';
      });

      // Step 1: Get device location
      final location = await LocationService.getCurrentPosition();
      
      if (location == null) {
        throw Exception('Gagal mendeteksi lokasi');
      }

      // Step 2: Get place name
      final placeName = await LocationService.getPlaceFromCoordinates(
        location.latitude!,
        location.longitude!,
      );
      
      // Step 3: Get weather data
      final weather = await _apiService.getWeather(
        location.latitude!,
        location.longitude!,
      );

      setState(() {
        _locationName = placeName ?? 'Lokasi tidak diketahui';
        _weatherData = weather;
        _state = WeatherState.loaded;
      });
      
    } catch (e) {
      print('Error fetching weather: $e');
      setState(() {
        _errorMessage = 'Gagal memuat data cuaca';
        _state = WeatherState.error;
        
        // Set mock data as fallback
        _locationName = 'Jakarta';
        _weatherData = WeatherData(
          temperature: 30.0,
          condition: 'sunny',
          description: 'Cerah',
          location: 'Jakarta',
          advice: 'Cuaca bagus untuk panen',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _expanded = !_expanded;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: _expanded ? 16 : 8,
        ),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _expanded ? _buildExpandedContent() : _buildCompactContent(),
      ),
    );
  }

  Widget _buildCompactContent() {
  return Row(
    children: [
      _buildWeatherStatusIndicator(),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _locationName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            Text(
              '${_weatherData?.temperature.round() ?? '--'}°C • ${_weatherData?.description ?? ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey[800]),
            ),
          ],
        ),
      ),
    ],
  );
}


  Widget _buildExpandedContent() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          _buildWeatherStatusIndicator(),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _locationName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now()),
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Text(
            '${_weatherData?.temperature.round() ?? '--'}°C',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '${_weatherData?.description ?? ''} - ${_weatherData?.advice ?? ''}',
              style: TextStyle(color: Colors.green[700], fontSize: 16),
            ),
          ),
        ],
      ),
    ],
  );
}


  Widget _buildWeatherStatusIndicator() {
    switch (_state) {
      case WeatherState.loading:
        return const CircularProgressIndicator(strokeWidth: 3);
      case WeatherState.error:
        return Icon(Icons.error_outline, color: Colors.red[400], size: 32);
      case WeatherState.loaded:
        return _buildWeatherIcon(_weatherData!.condition);
    }
  }

  Widget _buildWeatherContent() {
    if (_state == WeatherState.error) {
      return Row(
        children: [
          Expanded(
            child: Text(
              _errorMessage,
              style: TextStyle(
                color: Colors.red[400],
                fontSize: 16,
              ),
            ),
          ),
          TextButton(
            onPressed: _fetchWeather,
            child: const Text(
              'Coba Lagi',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      );
    }

    if (_state == WeatherState.loading) {
      return const LinearProgressIndicator();
    }

    return Row(
      children: [
        Text(
          '${_weatherData?.temperature.round() ?? '--'}°C',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            '${_weatherData?.description ?? ''} - ${_weatherData?.advice ?? ''}',
            style: TextStyle(
              color: Colors.green[700],
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherIcon(String condition) {
    final iconData = switch (condition) {
      'sunny' => Icons.wb_sunny,
      'partly_cloudy' => Icons.cloud,
      'cloudy' => Icons.cloud_queue,
      'rainy' => Icons.umbrella,
      _ => Icons.device_unknown,
    };

    final color = switch (condition) {
      'sunny' => Colors.amber,
      'partly_cloudy' => Colors.blueGrey[300]!,
      'cloudy' => Colors.blueGrey,
      'rainy' => Colors.blue,
      _ => Colors.grey,
    };

    return Icon(iconData, color: color, size: 40);
  }
}

enum WeatherState { loading, loaded, error }