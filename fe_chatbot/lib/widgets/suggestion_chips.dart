import 'package:flutter/material.dart';

class SuggestionChips extends StatelessWidget {
  final Function(String) onSuggestionSelected;
  
  const SuggestionChips({
    Key? key,
    required this.onSuggestionSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _buildSuggestions(),
      ),
    );
  }
  
  List<Widget> _buildSuggestions() {
    final suggestions = [
      'Teknik menanam padi',
      'Bagaimana mengatasi hama?',
      'Prediksi cuaca minggu ini',
      'Pupuk terbaik untuk jagung',
      'Musim tanam terbaik',
    ];
    // final suggestions = [
    //   'Rice planting techniques',
    //   'How to deal with pests?',
    //   'Weather forecast for this week',
    //   'Best fertilizer for corn',
    //   'Best planting season',
    // ];
    
    return suggestions.map((suggestion) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ActionChip(
          label: Text(suggestion),
          onPressed: () => onSuggestionSelected(suggestion),
          backgroundColor: Colors.green[50],
        ),
      );
    }).toList();
  }
}

