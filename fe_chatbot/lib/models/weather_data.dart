// class WeatherData {
//   final double temperature;
//   final String condition;
//   final String description;
//   final String location;
//   final String advice;
  
//   WeatherData({
//     required this.temperature,
//     required this.condition,
//     required this.description,
//     required this.location,
//     required this.advice,
//   });
  
//   factory WeatherData.fromJson(Map<String, dynamic> json) {
//     // Translate condition to standard English terms
//     final rawCondition = json['condition']?.toString().toLowerCase() ?? 'sunny';
//     final condition = _translateCondition(rawCondition);
    
//     // Translate description to English if needed
//     final rawDescription = json['description']?.toString() ?? 'Unknown';
//     final description = _translateDescription(rawDescription);
    
//     return WeatherData(
//       temperature: json['temperature']?.toDouble() ?? 0.0,
//       condition: condition,
//       description: description,
//       location: json['location'] ?? 'Unknown location',
//       advice: json['advice'] ?? 'No farming advice available',
//     );
//   }

//   // Helper method to standardize weather conditions
//   static String _translateCondition(String rawCondition) {
//     return switch (rawCondition.toLowerCase()) {
//       'cerah' => 'sunny',
//       'awan pecah' => 'partly_cloudy',
//       'berawan' => 'cloudy',
//       'hujan' => 'rainy',
//       'petir' => 'thunderstorm',
//       'kabut' => 'foggy',
//       'salju' => 'snowy',
//       _ => rawCondition, // return as-is if not Indonesian
//     };
//   }

//   // Helper method to translate descriptions
//   static String _translateDescription(String rawDescription) {
//     return switch (rawDescription.toLowerCase()) {
//       'cerah' => 'Sunny',
//       'awan pecah' => 'Partly cloudy',
//       'berawan' => 'Cloudy',
//       'hujan ringan' => 'Light rain',
//       'hujan lebat' => 'Heavy rain',
//       'gerimis' => 'Drizzle',
//       'petir' => 'Thunderstorm',
//       'kabut' => 'Foggy',
//       'salju' => 'Snowy',
//       _ => rawDescription, // return as-is if not Indonesian
//     };
//   }
// }

class WeatherData {
  final double temperature;
  final String condition;     // Sekarang langsung dalam Bahasa Indonesia
  final String description;   // Sudah dalam Bahasa Indonesia
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
    final rawCondition = json['condition']?.toString().toLowerCase() ?? 'cerah';
    final condition = _translateConditionIndo(rawCondition);

    final rawDescription = json['description']?.toString().toLowerCase() ?? 'cerah';
    final description = _translateDescriptionIndo(rawDescription);

    return WeatherData(
      temperature: json['temperature']?.toDouble() ?? 0.0,
      condition: condition,
      description: description,
      location: json['location'] ?? 'Lokasi tidak diketahui',
      advice: json['advice'] ?? 'Tidak ada saran pertanian',
    );
  }

  static String _translateConditionIndo(String value) {
  value = value.toLowerCase();
  if (value == 'clear' || value == 'sunny' || value == 'cerah') return 'Cerah';
  if (value == 'partly_cloudy' || value == 'awan pecah') return 'Sebagian berawan';
  if (value == 'cloudy' || value == 'berawan') return 'Berawan';
  if (value == 'rain' || value == 'rainy' || value == 'hujan') return 'Hujan';
  if (value == 'thunderstorm' || value == 'petir') return 'Petir';
  if (value == 'fog' || value == 'foggy' || value == 'kabut') return 'Kabut';
  if (value == 'snow' || value == 'salju') return 'Salju';
  return value;
}

static String _translateDescriptionIndo(String value) {
  value = value.toLowerCase();
  if (value == 'clear' || value == 'sunny' || value == 'cerah') return 'Cerah';
  if (value == 'partly cloudy' || value == 'awan pecah') return 'Sebagian berawan';
  if (value == 'cloudy' || value == 'berawan') return 'Berawan';
  if (value == 'light rain' || value == 'hujan ringan') return 'Hujan ringan';
  if (value == 'heavy rain' || value == 'hujan lebat') return 'Hujan lebat';
  if (value == 'drizzle' || value == 'gerimis') return 'Gerimis';
  if (value == 'thunderstorm' || value == 'petir') return 'Petir';
  if (value == 'fog' || value == 'kabut') return 'Kabut';
  if (value == 'snow' || value == 'salju') return 'Salju';
  return value;
}
String get conditionKey {
  switch (condition.toLowerCase()) {
    case 'cerah': return 'sunny';
    case 'sebagian berawan': return 'partly_cloudy';
    case 'berawan': return 'cloudy';
    case 'hujan': return 'rainy';
    case 'petir': return 'thunderstorm';
    case 'kabut': return 'foggy';
    case 'salju': return 'snowy';
    default: return 'unknown';
  }
}
}
