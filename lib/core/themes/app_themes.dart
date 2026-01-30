import 'package:flutter/material.dart';

class AppThemes {
  // Light Theme - Using your original deepOrange/orange color scheme
  static final ThemeData lightTheme = ThemeData(
    // Color Scheme (your original colors)
    primarySwatch: Colors.deepOrange,
    colorScheme: const ColorScheme.light(
      primary: Colors.deepOrange,       // Main app color
      secondary: Colors.orangeAccent,
      surface: Colors.white,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.black,
    ),

    // Typography (your original font)
    fontFamily: 'Sen',
    useMaterial3: true,

    // App Bar (your original styling)
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      iconTheme: IconThemeData(color: Colors.black),
      titleTextStyle: TextStyle(
        color: Colors.black,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        fontFamily: 'Sen',
      ),
    ),

    // Bottom Navigation Bar
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Colors.deepOrange,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
    ),

    // Elevated Buttons (your original styling)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepOrange, // Your original button color
        foregroundColor: Colors.white,      // Your original text color
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: const TextStyle(
          fontFamily: 'Sen',
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    // Text Buttons
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Colors.deepOrange,
        textStyle: const TextStyle(
          fontFamily: 'Sen',
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Input Fields
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.deepOrange),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.all(16),
      labelStyle: const TextStyle(
        color: Colors.grey,
        fontFamily: 'Sen',
      ),
      hintStyle: const TextStyle(
        color: Colors.grey,
        fontFamily: 'Sen',
      ),
    ),

    // Card Theme
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.all(8),
    ),

    // List Tile Theme
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
      titleTextStyle: TextStyle(
        fontFamily: 'Sen',
        fontWeight: FontWeight.w600,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: 'Sen',
      ),
    ),

    // Tab Bar Theme
    tabBarTheme: const TabBarThemeData(
      labelColor: Colors.deepOrange,
      unselectedLabelColor: Colors.grey,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: Colors.deepOrange, width: 2),
      ),
    ),

    // Divider Theme
    dividerTheme: const DividerThemeData(
      color: Colors.grey,
      thickness: 0.5,
      space: 1,
    ),
  );

  // Dark Theme - Adapted from your light theme
  static final ThemeData darkTheme = ThemeData.dark().copyWith(
    // Color Scheme for dark mode
    colorScheme: const ColorScheme.dark(
      primary: Colors.deepOrange,
      secondary: Colors.orangeAccent,
      surface: Color(0xFF1E1E1E),
    ),

    // App Bar for dark mode
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Color(0xFF1E1E1E),
      foregroundColor: Colors.white,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        fontFamily: 'Sen',
      ),
    ),

    // Bottom Navigation Bar for dark mode
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF1E1E1E),
      selectedItemColor: Colors.deepOrange,
      unselectedItemColor: Colors.grey,
    ),

    // Elevated Buttons for dark mode
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: const TextStyle(
          fontFamily: 'Sen',
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    // Input Fields for dark mode
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.deepOrange),
      ),
      filled: true,
      fillColor: Colors.grey[800],
      contentPadding: const EdgeInsets.all(16),
      labelStyle: const TextStyle(
        color: Colors.grey,
        fontFamily: 'Sen',
      ),
      hintStyle: const TextStyle(
        color: Colors.grey,
        fontFamily: 'Sen',
      ),
    ),

    // Card Theme for dark mode
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.all(8),
    ),
  );

  // Role-specific theme colors (for different app parts)
  static const Color customerPrimary = Colors.deepOrange;
  static const Color merchantPrimary = Colors.blue;
  static const Color adminPrimary = Colors.purple;

  // Custom text styles that match your app's personality
  static TextStyle get headlineLarge => const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        fontFamily: 'Sen',
        color: Colors.black,
      );

  static TextStyle get headlineMedium => const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        fontFamily: 'Sen',
        color: Colors.black,
      );

  static TextStyle get titleLarge => const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        fontFamily: 'Sen',
        color: Colors.black,
      );

  static TextStyle get bodyLarge => const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        fontFamily: 'Sen',
        color: Colors.black87,
      );

  static TextStyle get bodyMedium => const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        fontFamily: 'Sen',
        color: Colors.black87,
      );

  static TextStyle get caption => const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        fontFamily: 'Sen',
        color: Colors.grey,
      );

  // Custom widget styles
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );

  static BoxDecoration get featuredCardDecoration => BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.deepOrange, Colors.orangeAccent],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepOrange.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  // Custom button styles
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
        textStyle: const TextStyle(
          fontFamily: 'Sen',
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      );

  static ButtonStyle get secondaryButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.deepOrange,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
        textStyle: const TextStyle(
          fontFamily: 'Sen',
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.deepOrange),
        ),
      );

  // Custom chip styles
  static ChipThemeData get chipTheme => const ChipThemeData(
        backgroundColor: Color(0xFFF5F5F5),
        labelStyle: TextStyle(
          fontFamily: 'Sen',
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: 'Sen',
          fontWeight: FontWeight.w500,
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      );
}