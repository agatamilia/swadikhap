import 'package:flutter/material.dart';

class SuggestionChips extends StatelessWidget {
  final Function(String)? onSuggestionSelected;
  final Color chipColor;
  final Color textColor;

  const SuggestionChips({
    Key? key, 
    this.onSuggestionSelected,
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

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              backgroundColor: chipColor,
              label: Text(
                suggestions[index],
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                ),
              ),
              onPressed: onSuggestionSelected != null 
                  ? () => onSuggestionSelected!(suggestions[index])
                  : null,
            ),
          );
        },
      ),
    );
  }
}
