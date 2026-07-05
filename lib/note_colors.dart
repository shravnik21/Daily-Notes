import 'package:flutter/material.dart';

/// Palette used for color-tagging notes. Index is stored in the `color` column.
const List<Color> noteColors = [
  Color(0xFFFFFFFF), // 0 default
  Color(0xFFFFCDD2), // 1 red
  Color(0xFFFFE0B2), // 2 orange
  Color(0xFFFFF9C4), // 3 yellow
  Color(0xFFC8E6C9), // 4 green
  Color(0xFFB2EBF2), // 5 teal
  Color(0xFFBBDEFB), // 6 blue
  Color(0xFFD1C4E9), // 7 purple
  Color(0xFFF8BBD0), // 8 pink
];

const List<Color> noteColorsDark = [
  Color(0xFF2A2A2E),
  Color(0xFF4A2A2E),
  Color(0xFF4A3A20),
  Color(0xFF4A4620),
  Color(0xFF224A2C),
  Color(0xFF1F4A4A),
  Color(0xFF223A4A),
  Color(0xFF33244A),
  Color(0xFF4A2440),
];

Color resolveNoteColor(BuildContext context, int? index) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final palette = isDark ? noteColorsDark : noteColors;
  final i = (index ?? 0).clamp(0, palette.length - 1);
  return palette[i];
}