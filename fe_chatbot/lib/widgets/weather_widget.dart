import 'package:flutter/material.dart';
import 'package:location/location.dart' as loc;
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../models/weather_data.dart';

class WeatherWidget extends StatefulWidget {
  final Color backgroundColor;
  final Color textColor;

  const WeatherWidget({
    Key? key,
    required this.backgroundColor,
    required this.textColor,
  }) : super(key: key);

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  WeatherData? _weatherData;
  String _locationName = 'Detecting location...';
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchWeatherData();
  }

  Future<void> _fetchWeatherData() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // Get current position using location package
      final locationData = await LocationService.getCurrentPosition();
      if (locationData == null || locationData.latitude == null || locationData.longitude == null) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Tidak dapat mengakses lokasi';
        });
        return;
      }

      // Get place name
      final placeName = await LocationService.getPlaceFromCoordinates(
        locationData.latitude!,
        locationData.longitude!,
      );
      
      setState(() {
        _locationName = placeName;
      });

      // Fetch weather data
      try {
        final weatherData = await _apiService.getWeather(
          locationData.latitude!,
          locationData.longitude!,
        );
        
        setState(() {
          _weatherData = weatherData;
          _isLoading = false;
        });
        
        print('Weather data loaded: ${weatherData.condition}');
      } catch (e) {
        print('Error fetching weather: $e');
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Gagal memuat data cuaca: $e';
        });
      }
    } catch (e) {
      print('General weather error: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Terjadi kesalahan: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: widget.backgroundColor,
      child: _isLoading
          ? _buildLoadingState()
          : _hasError
              ? _buildErrorState()
              : _buildWeatherInfo(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return GestureDetector(
      onTap: _fetchWeatherData,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: widget.textColor,
              size: 16,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Gagal memuat cuaca. Ketuk untuk mencoba lagi.',
                style: TextStyle(
                  color: widget.textColor,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherInfo() {
    if (_weatherData == null) {
      return _buildErrorState();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            _getWeatherIcon(_weatherData!.condition),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_weatherData!.temperature.toStringAsFixed(1)}°C',
                  style: TextStyle(
                    color: widget.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  _locationName,
                  style: TextStyle(
                    color: widget.textColor.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        Flexible(
          child: Text(
            _weatherData!.advice,
            style: TextStyle(
              color: widget.textColor,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget _getWeatherIcon(String condition) {
    // Convert condition to lowercase for case-insensitive comparison
    final lowerCondition = condition.toLowerCase();
    
    // Debug print to see what condition we're getting
    print('Weather condition: $lowerCondition');
    
    IconData iconData;
    
    if (lowerCondition.contains('clear') || lowerCondition.contains('sun')) {
      iconData = Icons.wb_sunny;
    } else if (lowerCondition.contains('cloud')) {
      iconData = Icons.cloud;
    } else if (lowerCondition.contains('rain') || lowerCondition.contains('drizzle')) {
      iconData = Icons.grain;
    } else if (lowerCondition.contains('thunder') || lowerCondition.contains('storm')) {
      iconData = Icons.flash_on;
    } else if (lowerCondition.contains('snow')) {
      iconData = Icons.ac_unit;
    } else if (lowerCondition.contains('mist') || lowerCondition.contains('fog') || lowerCondition.contains('haze')) {
      iconData = Icons.cloud_queue;
    } else {
      iconData = Icons.wb_cloudy;  // Default icon
    }
    
    return Icon(
      iconData,
      color: widget.textColor,
      size: 24,
    );
  }
}
