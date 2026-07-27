import 'package:flutter/material.dart';
import 'package:chess_app/ui/screens/game_screen.dart';
import 'package:chess_app/ui/theme/app_theme.dart';

/// Application entry point.
void main() {
  runApp(const ChessApp());
}

/// Root widget of the application.
class ChessApp extends StatelessWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const GameScreen(),
    );
  }
}
