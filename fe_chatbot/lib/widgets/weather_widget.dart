import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../models/weather_data.dart';

class WeatherWidget extends StatelessWidget {
  final WeatherData? weatherData;
  final String location;
  final bool isLoading;

  const WeatherWidget({
    Key? key,
    required this.weatherData,
    required this.location,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Format date in Indonesian
    final now = DateTime.now();
    final dateFormat = DateFormat('EEEE, d MMMM yyyy', 'id_ID');
    final formattedDate = dateFormat.format(now);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.green.shade100,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location and date
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: TextStyle(
                            fontSize: 16, // Increased font size
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 14, // Increased font size
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Weather info
                  if (weatherData != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Temperature and icon
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              Text(
                                '${weatherData!.temperature.round()}°C',
                                style: const TextStyle(
                                  fontSize: 28, // Increased font size
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _getWeatherIcon(weatherData!.condition),
                            ],
                          ),
                        ),
                        
                        // Weather advice
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.green.shade200,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getWeatherDescription(weatherData!.condition),
                                  style: TextStyle(
                                    fontSize: 16, // Increased font size
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  weatherData!.advice,
                                  style: TextStyle(
                                    fontSize: 14, // Increased font size
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
      ),
    );
  }

  Widget _getWeatherIcon(String condition) {
    IconData iconData;
    Color color;

    condition = condition.toLowerCase();

    if (condition.contains('clear') || condition.contains('sun')) {
      iconData = Icons.wb_sunny;
      color = Colors.orange;
    } else if (condition.contains('cloud')) {
      iconData = Icons.cloud;
      color = Colors.grey;
    } else if (condition.contains('rain') || condition.contains('drizzle')) {
      iconData = Icons.grain;
      color = Colors.blue;
    } else if (condition.contains('thunder') || condition.contains('storm')) {
      iconData = Icons.flash_on;
      color = Colors.amber;
    } else if (condition.contains('snow')) {
      iconData = Icons.ac_unit;
      color = Colors.lightBlue;
    } else if (condition.contains('mist') || condition.contains('fog') || condition.contains('haze')) {
      iconData = Icons.cloud_queue;
      color = Colors.blueGrey;
    } else {
      iconData = Icons.cloud;
      color = Colors.grey;
    }

    return Icon(
      iconData,
      color: color,
      size: 32, // Increased icon size
    );
  }
  
  String _getWeatherDescription(String condition) {
    condition = condition.toLowerCase();
    
    if (condition.contains('clear') || condition.contains('sun')) {
      return 'Cerah';
    } else if (condition.contains('cloud') && !condition.contains('broken')) {
      return 'Berawan';
    } else if (condition.contains('broken') || condition.contains('overcast')) {
      return 'Mendung';
    } else if (condition.contains('drizzle')) {
      return 'Hujan rintik-rintik';
    } else if (condition.contains('rain') && !condition.contains('heavy')) {
      return 'Hujan';
    } else if (condition.contains('heavy') && condition.contains('rain')) {
      return 'Hujan deras';
    } else if (condition.contains('thunder') || condition.contains('storm')) {
      return 'Badai petir';
    } else if (condition.contains('snow')) {
      return 'Bersalju';
    } else if (condition.contains('mist') || condition.contains('fog') || condition.contains('haze')) {
      return 'Berkabut';
    } else {
      return condition;
    }
  }
}
