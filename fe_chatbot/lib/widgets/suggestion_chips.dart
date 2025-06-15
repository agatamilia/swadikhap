import 'package:flutter/material.dart';

class SuggestionChips extends StatelessWidget {
  final Function(String) onSuggestionSelected;
  final TextStyle? chipTextStyle;

  const SuggestionChips({
    Key? key,
    required this.onSuggestionSelected,
    this.chipTextStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: _buildSuggestions(),
      ),
    );
  }

  List<Widget> _buildSuggestions() {
    final suggestions = [
      'Teknik menanam padi',
      'Bagaimana mengatasi hama?',
      // 'Prediksi cuaca minggu ini',
      'Pupuk terbaik untuk jagung',
      'Musim tanam terbaik',
    ];
    return suggestions.map((suggestion) {
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ActionChip(
          label: Text(
            suggestion,
            style: chipTextStyle?.copyWith(
                    fontSize: 12, color: Colors.grey[700]) ??
                TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          onPressed: () => onSuggestionSelected(suggestion),
          backgroundColor: Colors.grey[100],
          elevation: 0,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          shape: const StadiumBorder(),
          side: BorderSide.none,
        ),
      );
    }).toList();
  }
}
