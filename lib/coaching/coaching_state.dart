// idle
//   ↓
// Nothing for the coach to do.

// observing
//   ↓
// Game is being played; coach is watching moves.

// mistakeDetected
//   ↓
// A move has been classified as a mistake/blunder/etc.

// askingWhy
//   ↓
// Coach asks the player why they made the move.

// showingExplanation
//   ↓
// Coach demonstrates the better move/line and explains the mistake.
import 'package:chess_app/coaching/coaching_engine.dart';

enum CoachingState {
  idle,
  observing,
  mistakeDetected,
  askingWhy,
  showingExplanation,
}