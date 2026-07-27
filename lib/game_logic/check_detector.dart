import 'package:chess_app/game_logic/board.dart';
import 'package:chess_app/game_logic/move_validator.dart';
import 'package:chess_app/models/enums.dart';
import 'package:chess_app/models/game_state.dart';

/// Determines the overall [GameStatus] of a position — check, checkmate,
/// stalemate, or one of the draw conditions.
class CheckDetector {
  const CheckDetector._();

  /// Computes the full [GameStatus] for [state], from the perspective
  /// of the side whose turn it is to move.
  static GameStatus statusFor(GameState state) {
    final sideToMove = state.turnToMove;
    final inCheck = MoveValidator.isInCheck(state, sideToMove);
    final hasLegalMoves =
        MoveValidator.allLegalMoves(state, sideToMove).isNotEmpty;

    if (inCheck && !hasLegalMoves) return GameStatus.checkmate;
    if (!inCheck && !hasLegalMoves) return GameStatus.stalemate;

    if (isInsufficientMaterial(state)) return GameStatus.insufficientMaterial;
    if (state.halfMoveClock >= 100) return GameStatus.fiftyMoveRule;
    if (isThreefoldRepetition(state)) return GameStatus.threefoldRepetition;

    return inCheck ? GameStatus.check : GameStatus.active;
  }

  /// Returns true if neither side has enough material to possibly
  /// deliver checkmate.
  ///
  /// v0.1 covers the common, unambiguous cases (K vs K, K+minor vs K,
  /// K+B vs K+B same-colored bishops) and intentionally under-detects
  /// rarer theoretical draws rather than risk ending a winnable game.
  static bool isInsufficientMaterial(GameState state) {
    final counts = Board.pieceCounts(state);

    final hasHeavyOrPawn = (counts[PieceType.pawn] ?? 0) > 0 ||
        (counts[PieceType.rook] ?? 0) > 0 ||
        (counts[PieceType.queen] ?? 0) > 0;
    if (hasHeavyOrPawn) return false;

    final minorPieceCount =
        (counts[PieceType.bishop] ?? 0) + (counts[PieceType.knight] ?? 0);

    if (minorPieceCount <= 1) return true;

    if (minorPieceCount == 2 &&
        (counts[PieceType.bishop] ?? 0) == 2 &&
        (counts[PieceType.knight] ?? 0) == 0) {
      return _bishopsShareSquareColor(state);
    }

    return false;
  }

  static bool _bishopsShareSquareColor(GameState state) {
    final bishopSquareColors = <bool>[];
    for (var file = 0; file < 8; file++) {
      for (var rank = 0; rank < 8; rank++) {
        final piece = state.squares[file][rank];
        if (piece != null && piece.type == PieceType.bishop) {
          bishopSquareColors.add((file + rank).isEven);
        }
      }
    }
    if (bishopSquareColors.length != 2) return false;
    return bishopSquareColors[0] == bishopSquareColors[1];
  }

  /// Threefold repetition detection.
  ///
  /// v0.1 note: left as a documented stub (always false). Proper
  /// detection needs a running position-history map maintained by
  /// [GameController] — a self-contained addition for a future version.
  static bool isThreefoldRepetition(GameState state) {
    return false;
  }
}
