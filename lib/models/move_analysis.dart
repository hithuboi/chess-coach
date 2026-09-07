import 'package:chess_app/engine/move_classifier.dart';

import 'package:chess_app/models/move.dart';

/// Describes the type of mistake made by the player.
///
/// This allows the coach to distinguish between different weaknesses
/// instead of treating every mistake or blunder the same way.
enum MistakeCategory {
  hangingPiece,
  missedCapture,
  missedCheck,
  poorDevelopment,
  kingSafety,
  badTrade,
  repeatedQueenMoves,
  unknown,
}

class MoveAnalysis {
  final Move move;

  final MoveQuality quality;

  final int bestScore;

  final int playedScore;

  final int centipawnLoss;

  final Move? bestMove;

  /// The category of the mistake identified by the coach.
  ///
  /// This is nullable because good moves do not necessarily have
  /// a mistake category.
  final MistakeCategory? mistakeCategory;

  const MoveAnalysis({
    required this.move,
    required this.quality,
    required this.bestScore,
    required this.playedScore,
    required this.centipawnLoss,
    this.bestMove,

    // Store the detected mistake category when one exists.
    this.mistakeCategory,
  });
}