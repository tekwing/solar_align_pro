import 'package:flutter/material.dart';

class AppTheme {
  // --- BRIGHT MODE ---
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Modern Slate-50
    cardColor: Colors.white,
    dividerColor: Colors.grey.shade200,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF1D4ED8), // Modern Blue
      secondary: Color(0xFF0B131E), // Deep Navy
      surface: Colors.white,
      onSurface: Color(0xFF0B131E), // Dark text on light background
    ),
    iconTheme: const IconThemeData(color: Color(0xFF475569)),
  );

  // --- DARK MODE ---
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0B131E), // Deep SaaS Navy
    cardColor: const Color(0xFF152336), // Slightly lighter navy for cards
    dividerColor: const Color(0xFF1E293B), // Dark slate divider
    colorScheme: const ColorScheme.dark(
      primary: Color(
        0xFF3B82F6,
      ), // Slightly brighter blue for dark mode visibility
      secondary: Colors.amber,
      surface: Color(0xFF152336),
      onSurface: Color(0xFFF8FAFC), // Light text on dark background
    ),
    iconTheme: const IconThemeData(color: Color(0xFF94A3B8)),
  );
}
