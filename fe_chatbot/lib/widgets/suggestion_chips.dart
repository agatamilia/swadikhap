import 'package:flutter/material.dart';

class SuggestionChips extends StatelessWidget {
  final Function(String) onSuggestionSelected;
  final Color chipColor;
  final Color textColor;

  const SuggestionChips({
    Key? key, 
    required this.onSuggestionSelected,
    this.chipColor = const Color(0xFFE8F5E9),
    this.textColor = const Color(0xFF2E7D32),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final suggestions = [
      'Bagaimana cara menanam padi?',
      'Apa tanda-tanda hama pada tanaman?',
      'Berapa suhu ideal untuk tanaman tomat?',
      'Kapan waktu terbaik untuk memanen jagung?',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: suggestions.map((suggestion) {
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              backgroundColor: chipColor,
              label: Text(
                suggestion,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                ),
              ),
              onPressed: () => onSuggestionSelected(suggestion),
            ),
          );
        }).toList(),
      ),
    );
  }
}
