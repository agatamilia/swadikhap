// // class WeatherData {
// //   final double temperature;
// //   final String condition;
// //   final String description;
// //   final String location;
// //   final String advice;

// //   WeatherData({
// //     required this.temperature,
// //     required this.condition,
// //     required this.description,
// //     required this.location,
// //     required this.advice,
// //   });

// //   factory WeatherData.fromJson(Map<String, dynamic> json) {
// //     return WeatherData(
// //       temperature: json['temperature']?.toDouble() ?? 0.0,
// //       condition: json['condition'] ?? 'sunny',
// //       description: json['description'] ?? 'Unknown',
// //       location: json['location'] ?? 'Unknown',
// //       advice: json['advice'] ?? 'No farming advice available',
// //     );
// //   }
// // }
class WeatherData {
  final double temperature;
  final String condition; // Should use standardized English terms
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
    // Translate condition to standard English terms
    final rawCondition = json['condition']?.toString().toLowerCase() ?? 'sunny';
    final condition = _translateCondition(rawCondition);

    // Translate description to English if needed
    final rawDescription = json['description']?.toString() ?? 'Unknown';
    final description = _translateDescription(rawDescription);

    return WeatherData(
      temperature: json['temperature']?.toDouble() ?? 0.0,
      condition: condition,
      description: description,
      location: json['location'] ?? 'Unknown location',
      advice: json['advice'] ?? 'No farming advice available',
    );
  }

  // Helper method to standardize weather conditions
  static String _translateCondition(String rawCondition) {
    return switch (rawCondition.toLowerCase()) {
      'cerah' => 'sunny',
      'awan pecah' => 'partly_cloudy',
      'berawan' => 'cloudy',
      'hujan' => 'rainy',
      'petir' => 'thunderstorm',
      'kabut' => 'foggy',
      'salju' => 'snowy',
      _ => rawCondition, // return as-is if not Indonesian
    };
  }

  // Helper method to translate descriptions
  static String _translateDescription(String rawDescription) {
    return switch (rawDescription.toLowerCase()) {
      'clear sky' => 'Langit cerah',
      'few clouds' => 'Sedikit awan',
      'scattered clouds' => 'Awan tersebar',
      'broken clouds' => 'Awan pecah',
      'shower rain' => 'Hujan deras',
      'rain' => 'Hujan',
      'thunderstorm' => 'Badai petir',
      'snow' => 'Salju',
      'mist' => 'Berkabut',
      _ => rawDescription,
    };
  }
}
  