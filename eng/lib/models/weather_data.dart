class WeatherData {
  final double temperature;
  final String condition; // e.g., 'sunny', 'cloudy', 'rainy'
  final String description;
  final String location;
  final String advice;

  WeatherData({
    required this.temperature,
    required this.condition,
    required this.description,
    required this.location,
    required this.advice,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      temperature: json['temperature']?.toDouble() ?? 0.0,
      condition: json['condition']?.toString().toLowerCase() ?? 'unknown',
      description: json['description']?.toString() ?? 'Unknown',
      location: json['location'] ?? 'Unknown location',
      advice: json['advice'] ?? 'No farming advice available',
    );
  }
}