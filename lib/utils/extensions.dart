import 'package:chess_app/models/enums.dart';
import 'package:chess_app/models/move.dart';
import 'package:chess_app/models/position.dart';

/// Small, focused extension methods used across the codebase.

/// Convenience helpers for [PieceColor] that are UI-flavored.
extension PieceColorDisplay on PieceColor {
  /// Human-readable label, e.g. for the move history header.
  String get displayName => this == PieceColor.white ? 'White' : 'Black';
}

/// Convenience helpers for [Position] that are useful for UI rendering.
extension PositionDisplay on Position {
  /// True if this square is a "light" square on a standard board,
  /// using the standard convention that a1 is a dark square.
  bool get isLightSquare => (file + rank).isOdd;
}

/// A single row of move history: White's move and (if played) Black's
/// reply, grouped under one full-move number.
class MoveHistoryRow {
  final int moveNumber;
  final Move whiteMove;
  final Move? blackMove;

  const MoveHistoryRow({
    required this.moveNumber,
    required this.whiteMove,
    this.blackMove,
  });
}

/// Groups a flat move list into [MoveHistoryRow]s for display.
extension MoveHistoryPairing on List<Move> {
  /// Converts this flat, chronological move list into paired rows.
  List<MoveHistoryRow> get paired {
    final rows = <MoveHistoryRow>[];
    for (var i = 0; i < length; i += 2) {
      rows.add(MoveHistoryRow(
        moveNumber: (i ~/ 2) + 1,
        whiteMove: this[i],
        blackMove: (i + 1 < length) ? this[i + 1] : null,
      ));
    }
    return rows;
  }
}
