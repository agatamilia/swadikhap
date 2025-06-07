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
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _buildSuggestions(),
      ),
    );
  }

  List<Widget> _buildSuggestions() {
    final suggestions = [
      // 'Teknik menanam padi',
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
            style: chipTextStyle?.copyWith(color: Colors.grey[800]) ?? TextStyle(color: Colors.grey[800]),
          ),
          onPressed: () => onSuggestionSelected(suggestion),
          backgroundColor: Colors.grey[200], // Background abu-abu muda
          elevation: 0, // Menghilangkan bayangan
          // shadowColor: Colors.transparent, // Menghilangkan bayangan di bawah chip
          shape: StadiumBorder(), // Memastikan bentuk lonjong
          side: BorderSide.none, // Menghapus border atau garis hitam
        ),
      );
    }).toList();
  }
}
