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
//     return WeatherData(
//       temperature: json['temperature'].toDouble(),
//       condition: json['condition'],
//       description: json['description'],
//       location: json['location'],
//       advice: json['advice'],
//     );
//   }
// }
class WeatherData {
  final double temperature;
  final String condition;
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
      condition: json['condition'] ?? 'sunny',
      description: json['description'] ?? 'Unknown',
      location: json['location'] ?? 'Unknown',
      advice: json['advice'] ?? 'No farming advice available',
    );
  }
}


