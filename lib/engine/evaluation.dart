import 'package:chess_app/models/enums.dart';
import 'package:chess_app/models/game_state.dart';
import 'package:chess_app/models/piece.dart';

/// Static evaluation of a board position, used by [SimpleEngine]'s
/// minimax search to score positions at the search horizon.
class Evaluation {
  const Evaluation._();

  static const List<int> _pawnRankBonus = [0, 0, 5, 10, 15, 25, 40, 0];
  static const List<int> _centerFileBonus = [0, 5, 10, 15, 15, 10, 5, 0];

  /// Scores [state] from White's perspective: positive favors White,
  /// negative favors Black, zero is balanced.
  static int evaluate(GameState state) {
    var score = 0;

    for (var file = 0; file < 8; file++) {
      for (var rank = 0; rank < 8; rank++) {
        final piece = state.squares[file][rank];
        if (piece == null) continue;

        final materialScore = piece.materialValue * 100;
        final positionalScore = _positionalBonus(piece, file, rank);
        final signedScore = materialScore + positionalScore;

        score += piece.color == PieceColor.white ? signedScore : -signedScore;
      }
    }

    return score;
  }

  static int _positionalBonus(Piece piece, int file, int rank) {
    final effectiveRank = piece.color == PieceColor.white ? rank : 7 - rank;

    return switch (piece.type) {
      PieceType.pawn => _pawnRankBonus[effectiveRank],
      PieceType.knight =>
        _centerFileBonus[file] + _centerFileBonus[effectiveRank],
      PieceType.bishop => _centerFileBonus[file],
      PieceType.king => _kingSafetyBonus(effectiveRank),
      _ => 0,
    };
  }

  static int _kingSafetyBonus(int effectiveRank) =>
      effectiveRank == 0 ? 20 : 0;
}
