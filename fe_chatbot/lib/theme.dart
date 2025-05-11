import 'package:flutter/material.dart';

// App color scheme
const ColorScheme colorScheme = ColorScheme(
  primary: Color(0xFF2E7D32),         // Dark Green
  primaryContainer: Color(0xFFAED581), // Light Green
  secondary: Color(0xFFFFA000),        // Amber
  secondaryContainer: Color(0xFFFFE082), // Light Amber
  surface: Colors.white,      // Off-White with Green Tint
  error: Color(0xFFB71C1C),
  onPrimary: Colors.white,
  onSecondary: Colors.black,
  onSurface: Color(0xFF212121),
  onError: Colors.white,
  brightness: Brightness.light,
);

// App theme
final ThemeData appTheme = ThemeData(
  colorScheme: colorScheme,
  useMaterial3: true,
  scaffoldBackgroundColor: colorScheme.surface,
  appBarTheme: AppBarTheme(
    backgroundColor: colorScheme.primary,
    foregroundColor: colorScheme.onPrimary,
    elevation: 0,
  ),
  cardTheme: CardTheme(
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  ),
  textTheme: TextTheme(
    headlineMedium: TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 24,  // Perbesar ukuran font untuk headline
    ),
    bodyLarge: TextStyle(
      fontSize: 20,  // Perbesar ukuran font untuk teks tubuh utama
    ),
    bodyMedium: TextStyle(
      fontSize: 18,  // Perbesar ukuran font untuk teks tubuh dengan ukuran lebih kecil
    ),
    labelLarge: TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 18,  // Perbesar ukuran font untuk label
    ),
  ),
);
