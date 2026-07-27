import 'package:chess_app/models/enums.dart';
import 'package:chess_app/models/game_state.dart';
import 'package:chess_app/models/move.dart';

/// Abstract interface for a computer chess opponent.
///
/// The UI and [GameController] depend only on this interface — future
/// engines (Coach AI, Adaptive Difficulty) implement this same contract
/// without requiring changes elsewhere.
abstract class ChessEngine {
  /// A short, human-readable name for this engine.
  String get name;

  /// Chooses a move for [color] to play in the current [state].
  /// Returns null only if [color] has no legal moves available.
  Future<Move?> chooseMove(GameState state, PieceColor color);
}
