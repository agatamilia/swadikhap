class WeatherData {
  final double temperature;
  final String condition;
  final String description;
  final String location;
  final String advice;
  final String date;
  final String icon;
  final double humidity;
  final double windSpeed;
  final int timestamp;
  final bool mock;

  WeatherData({
    required this.temperature,
    required this.condition,
    required this.description,
    required this.location,
    required this.advice,
    this.date = '',
    this.icon = '',
    this.humidity = 0.0,
    this.windSpeed = 0.0,
    this.timestamp = 0,
    this.mock = false,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      temperature: json['temperature']?.toDouble() ?? 0.0,
      condition: json['condition'] ?? 'unknown',
      description: json['description'] ?? '',
      location: json['location'] ?? 'Unknown',
      advice: json['advice'] ?? '',
      date: json['date'] ?? '',
      icon: json['icon'] ?? '',
      humidity: json['humidity']?.toDouble() ?? 0.0,
      windSpeed: json['wind_speed']?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      mock: json['mock'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'condition': condition,
      'description': description,
      'location': location,
      'advice': advice,
      'date': date,
      'icon': icon,
      'humidity': humidity,
      'wind_speed': windSpeed,
      'timestamp': timestamp,
      'mock': mock,
    };
  }

  // Create a mock weather data for testing or when API fails
  static WeatherData mockData() {
    return WeatherData(
      temperature: 27.0,
      condition: 'Clouds',
      description: 'Berawan sebagian',
      location: 'Unknown Location',
      advice: 'Pantau kondisi tanaman secara berkala',
      date: DateTime.now().toString().substring(0, 10),
      icon: 'cloud',
      humidity: 75.0,
      windSpeed: 3.5,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      mock: true,
    );
  }

  // Check if weather data is too old (more than 1 hour)
  bool isOutdated() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final oneHour = 60 * 60 * 1000; // 1 hour in milliseconds
    return (now - timestamp) > oneHour;
  }
}
