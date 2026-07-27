import 'package:chess_app/game_logic/board.dart';
import 'package:chess_app/game_logic/move_generator.dart';
import 'package:chess_app/models/enums.dart';
import 'package:chess_app/models/game_state.dart';
import 'package:chess_app/models/move.dart';
import 'package:chess_app/models/position.dart';

/// Filters [MoveGenerator]'s pseudo-legal moves down to fully legal
/// moves by simulating each one and rejecting any that leave the
/// mover's own king in check.
class MoveValidator {
  const MoveValidator._();

  /// Returns true if [color]'s king currently sits on an attacked square.
  static bool isInCheck(GameState state, PieceColor color) {
    final kingSquare = Board.findKing(state, color);
    final opponentAttacks =
        MoveGenerator.attackedSquares(state, color.opposite);
    return opponentAttacks.contains(kingSquare);
  }

  /// Returns true if playing [move] would leave the mover's own king in check.
  static bool leavesOwnKingInCheck(GameState state, Move move) {
    final simulatedSquares = Board.applyMove(state, move);
    final simulatedState = state.copyWith(newSquares: simulatedSquares);
    return isInCheck(simulatedState, move.piece.color);
  }

  /// Returns every fully legal move for the piece on [from].
  static List<Move> legalMovesFrom(GameState state, Position from) {
    final pseudoLegal = MoveGenerator.pseudoLegalMovesFrom(state, from);
    return pseudoLegal.where((move) => !leavesOwnKingInCheck(state, move)).toList();
  }

  /// Returns every fully legal move available to [color].
  static List<Move> allLegalMoves(GameState state, PieceColor color) {
    final pseudoLegal = MoveGenerator.allPseudoLegalMoves(state, color);
    return pseudoLegal.where((move) => !leavesOwnKingInCheck(state, move)).toList();
  }

  /// Returns true if [move] is a legal move in [state].
  static bool isLegalMove(GameState state, Move move) {
    final matches = MoveGenerator.pseudoLegalMovesFrom(state, move.from).any(
      (m) =>
          m.to == move.to &&
          m.flag == move.flag &&
          m.promotesTo == move.promotesTo,
    );
    if (!matches) return false;
    return !leavesOwnKingInCheck(state, move);
  }
}
