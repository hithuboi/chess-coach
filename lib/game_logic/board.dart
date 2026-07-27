import 'package:chess_app/models/enums.dart';
import 'package:chess_app/models/game_state.dart';
import 'package:chess_app/models/move.dart';
import 'package:chess_app/models/piece.dart';
import 'package:chess_app/models/position.dart';

/// Stateless helper functions for querying and manipulating a board.
class Board {
  const Board._();

  /// Returns all squares currently occupied by pieces of [color].
  static List<Position> squaresOccupiedBy(GameState state, PieceColor color) {
    final result = <Position>[];
    for (var file = 0; file < 8; file++) {
      for (var rank = 0; rank < 8; rank++) {
        final piece = state.squares[file][rank];
        if (piece != null && piece.color == color) {
          result.add(Position(file, rank));
        }
      }
    }
    return result;
  }

  /// Finds the square the king of [color] currently occupies.
  static Position findKing(GameState state, PieceColor color) {
    for (var file = 0; file < 8; file++) {
      for (var rank = 0; rank < 8; rank++) {
        final piece = state.squares[file][rank];
        if (piece != null &&
            piece.type == PieceType.king &&
            piece.color == color) {
          return Position(file, rank);
        }
      }
    }
    throw StateError('No $color king found on the board.');
  }

  /// Returns true if [position] is empty.
  static bool isEmpty(GameState state, Position position) =>
      state.pieceAt(position) == null;

  /// Returns true if [position] holds a piece of [color].
  static bool isOccupiedByColor(
    GameState state,
    Position position,
    PieceColor color,
  ) {
    final piece = state.pieceAt(position);
    return piece != null && piece.color == color;
  }

  /// Returns true if [position] holds a piece of the opposite color.
  static bool isOccupiedByOpponent(
    GameState state,
    Position position,
    PieceColor color,
  ) {
    final piece = state.pieceAt(position);
    return piece != null && piece.color != color;
  }

  /// Counts total pieces remaining on the board, by type.
  static Map<PieceType, int> pieceCounts(GameState state) {
    final counts = <PieceType, int>{};
    for (var file = 0; file < 8; file++) {
      for (var rank = 0; rank < 8; rank++) {
        final piece = state.squares[file][rank];
        if (piece != null) {
          counts[piece.type] = (counts[piece.type] ?? 0) + 1;
        }
      }
    }
    return counts;
  }

  /// Applies [move] to [state] and returns the resulting squares grid.
  ///
  /// Handles piece placement only (moving, capturing, castling rook
  /// jump, en passant removal, promotion substitution) — does NOT
  /// update turn, move history, clocks, or status.
  static List<List<Piece?>> applyMove(GameState state, Move move) {
    final squares =
        List.generate(8, (file) => List<Piece?>.from(state.squares[file]));

    squares[move.from.file][move.from.rank] = null;

    if (move.flag == MoveFlag.enPassant &&
        move.enPassantCapturedSquare != null) {
      final captured = move.enPassantCapturedSquare!;
      squares[captured.file][captured.rank] = null;
    }

    final movedPiece = move.promotesTo != null
        ? Piece(type: move.promotesTo!, color: move.piece.color, hasMoved: true)
        : move.piece.copyWith(hasMoved: true);

    squares[move.to.file][move.to.rank] = movedPiece;

    if (move.isCastling) {
      final rank = move.from.rank;
      if (move.flag == MoveFlag.castleKingside) {
        final rook = squares[7][rank];
        squares[7][rank] = null;
        squares[5][rank] = rook?.copyWith(hasMoved: true);
      } else {
        final rook = squares[0][rank];
        squares[0][rank] = null;
        squares[3][rank] = rook?.copyWith(hasMoved: true);
      }
    }

    return squares;
  }

  /// Produces a compact, human-readable text rendering of the board,
  /// useful for debugging (not used by the UI).
  static String debugPrint(GameState state) {
    final buffer = StringBuffer();
    for (var rank = 7; rank >= 0; rank--) {
      for (var file = 0; file < 8; file++) {
        final piece = state.squares[file][rank];
        buffer.write(piece?.symbol ?? '.');
        buffer.write(' ');
      }
      buffer.writeln();
    }
    return buffer.toString();
  }
}
