import 'package:flutter/material.dart';

class AppTheme {
  static final light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF087F5B)),
    scaffoldBackgroundColor: const Color(0xFFF8FAF9),
    appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Color(0xFFF8FAF9),
        surfaceTintColor: Colors.transparent),
    cardTheme: const CardThemeData(
        elevation: 0, margin: EdgeInsets.zero, color: Colors.white),
    inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)))),
  );
}
