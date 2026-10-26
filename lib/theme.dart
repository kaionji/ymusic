import 'package:flutter/material.dart';

/// Вся стилистика здесь. Поменяйте цвета - поменяется все приложение.
/// Сейчас: чистый черный и оттенки серого.
class Pal {
  static const bg = Color(0xFF000000);
  static const surface = Color(0xFF0D0D0D);
  static const surface2 = Color(0xFF1A1A1A);
  static const line = Color(0xFF2A2A2A);
  static const accent = Color(0xFFEDEDED); // светло-серый вместо цветного акцента
  static const text = Color(0xFFF5F5F5);
  static const muted = Color(0xFF8C8C8C);
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: Pal.bg,
    canvasColor: Pal.bg,
    dividerColor: Pal.line,
    colorScheme: const ColorScheme.dark(
      primary: Pal.accent,
      onPrimary: Colors.black,
      secondary: Pal.accent,
      surface: Pal.surface,
      onSurface: Pal.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Pal.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: Pal.text,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Pal.surface,
      indicatorColor: Pal.surface2,
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Pal.surface,
      indicatorColor: Pal.surface2,
    ),
    sliderTheme: const SliderThemeData(
      trackHeight: 4,
      activeTrackColor: Pal.accent,
      inactiveTrackColor: Color(0xFF2E2E2E),
      thumbColor: Pal.accent,
      overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Pal.surface2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      hintStyle: const TextStyle(color: Pal.muted),
    ),
    listTileTheme: const ListTileThemeData(
      selectedColor: Pal.accent,
      iconColor: Pal.text,
    ),
  );
}
