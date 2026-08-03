import 'package:flutter/material.dart';

/// Centralized Material 3 theme definition for the app.
class AppTheme {
  const AppTheme._();


////make this user selectable.
  static const Color _seedColor = Color(0xFF2E5339);

  /// Light board square color.
  static const Color lightSquareColor = Color(0xFFE0E0E0);

  /// Dark board square color.
  static const Color darkSquareColor = Color(0xFF424242);

  /// Highlight color for the currently selected square.
  static const Color selectedSquareColor = Color(0xFFF6C453);

  /// Highlight color for squares a selected piece can legally move to.
  static const Color legalMoveHighlightColor = Color(0x552E5339);

  /// Highlight color for a king currently in check.
  static const Color checkHighlightColor = Color(0x88D32F2F);

  /// Highlight color for the origin and destination squares of the
  /// most recently played move (either side), so the player can see
  /// at a glance what just changed on the board.
  static const Color lastMoveHighlightColor = Color(0x55F6C453);

  /// Highlight color for the Hint feature's suggested move -- the
  /// piece's current square and its suggested destination, both
  /// tinted the same translucent neon yellow so the suggestion reads
  /// as a single connected "do this" instruction rather than two
  /// unrelated highlights.
  static const Color hintHighlightColor = Color(0x99FFFF00);

  /// The app's light theme.
  static ThemeData get light => _buildTheme(Brightness.light);

  /// The app's dark theme.
  static ThemeData get dark => _buildTheme(Brightness.dark);
 
  static ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.onSurface,
        foregroundColor:  colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      visualDensity: VisualDensity.standard,
      textTheme: _buildTextTheme(colorScheme),
    );
  }

  static TextTheme _buildTextTheme(ColorScheme colorScheme) {
    return TextTheme(
      titleLarge: TextStyle(
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      bodyMedium: TextStyle(
        color: colorScheme.onSurfaceVariant,
      ),
      labelLarge: TextStyle(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: colorScheme.onSurface,
      ),
    );
  }
}
