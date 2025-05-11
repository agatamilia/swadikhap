import 'package:flutter/material.dart';

class SuggestionChips extends StatelessWidget {
  final Function(String) onSuggestionSelected;
  final TextStyle? chipTextStyle;  // Add this line
  
  const SuggestionChips({
    Key? key,
    required this.onSuggestionSelected,
    this.chipTextStyle,  // Add this line
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
    return suggestions.map((suggestion) {
      return Padding(
        padding: const EdgeInsets.only(right: 10),
        child: ActionChip(
          label: Text(
            suggestion,
            style: chipTextStyle,  // Apply the style here
          ),
          onPressed: () => onSuggestionSelected(suggestion),
          backgroundColor: Colors.green[50],
        ),
      );
    }).toList();
  }
}