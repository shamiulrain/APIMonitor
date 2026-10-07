import 'package:flutter/material.dart';

/// Visual configuration for the inspector UI.
///
/// Use [ApiMonitorTheme.light] / [ApiMonitorTheme.dark] for ready made palettes
/// or construct your own with brand colours.
@immutable
class ApiMonitorTheme {
  const ApiMonitorTheme({
    this.brightness = Brightness.light,
    this.primary = const Color(0xFF1E88E5),
    this.background = const Color(0xFFF5F6F8),
    this.surface = Colors.white,
    this.surfaceVariant = const Color(0xFFEDEFF2),
    this.onSurface = const Color(0xFF1B1D21),
    this.onSurfaceVariant = const Color(0xFF6B7280),
    this.divider = const Color(0xFFE2E5E9),
    this.success = const Color(0xFF2E7D32),
    this.error = const Color(0xFFD32F2F),
    this.warning = const Color(0xFFED6C02),
    this.pending = const Color(0xFF9E9E9E),
    this.bubble = const Color(0xFF1E88E5),
    this.bubbleForeground = Colors.white,
    this.monoFontFamily = 'monospace',
  });

  const ApiMonitorTheme.light() : this();

  const ApiMonitorTheme.dark()
      : brightness = Brightness.dark,
        primary = const Color(0xFF4FA3F7),
        background = const Color(0xFF14161A),
        surface = const Color(0xFF1D2025),
        surfaceVariant = const Color(0xFF272B31),
        onSurface = const Color(0xFFECEDEF),
        onSurfaceVariant = const Color(0xFF9BA1A9),
        divider = const Color(0xFF30353C),
        success = const Color(0xFF4CAF50),
        error = const Color(0xFFEF5350),
        warning = const Color(0xFFFFA726),
        pending = const Color(0xFF9E9E9E),
        bubble = const Color(0xFF4FA3F7),
        bubbleForeground = const Color(0xFF0B0D10),
        monoFontFamily = 'monospace';

  final Brightness brightness;
  final Color primary;
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color divider;
  final Color success;
  final Color error;
  final Color warning;
  final Color pending;
  final Color bubble;
  final Color bubbleForeground;
  final String monoFontFamily;

  /// Brand-ish colour for an HTTP method.
  Color methodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return primary;
      case 'POST':
        return success;
      case 'PUT':
        return warning;
      case 'PATCH':
        return const Color(0xFF8E24AA);
      case 'DELETE':
        return error;
      default:
        return onSurfaceVariant;
    }
  }

  /// Colour for a status code / status pair, used to tint list rows.
  Color statusColor(int? statusCode, {required bool isError, required bool isPending}) {
    if (isPending) return pending;
    if (isError || statusCode == null || statusCode >= 400) return error;
    if (statusCode >= 300) return warning;
    return success;
  }

  ThemeData toThemeData() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    ).copyWith(
      surface: surface,
      primary: primary,
      error: error,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      dividerColor: divider,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: divider),
        ),
      ),
      textTheme: Typography.material2021().black.apply(
            bodyColor: onSurface,
            displayColor: onSurface,
          ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        hintStyle: TextStyle(color: onSurfaceVariant),
      ),
    );
  }
}
