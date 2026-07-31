import 'package:chess_app/engine/evaluation.dart';
import 'package:chess_app/game_logic/board.dart';
import 'package:chess_app/game_logic/move_validator.dart';
import 'package:chess_app/models/enums.dart';
import 'package:chess_app/models/game_state.dart';
import 'package:chess_app/models/move.dart';
import 'package:chess_app/models/position.dart';

/// How a played move compares to the best move available in that
/// position, from "barely any centipawns lost" to "a serious error".
enum MoveQuality {
  excellent,
  good,
  mistake,
  blunder,
}

/// Classifies a played move by comparing its resulting evaluation
/// against the best evaluation achievable from the same position.
///
/// This mirrors [SimpleEngine]'s own search (same minimax-with-
/// alpha-beta approach, same [Evaluation] scoring) but is a separate,
/// self-contained class rather than a reused piece of [SimpleEngine]:
/// classification needs the score for *every* legal move (to find the
/// best one) rather than just the single chosen move, and runs at a
/// shallower depth than the opponent engine so it stays fast enough to
/// run after every human move without noticeably delaying the UI.
///
/// v0.1 scope note: this produces the quality label only. The
/// follow-up "coaching" experience (an explanation bubble, a "see
/// why" refutation line, and a suggested better move the player can
/// accept) is intentionally deferred to a future version -- this
/// class is written so that work can build on top of it later: the
/// per-move scores it already computes internally are exactly what a
/// coaching feature would need to explain *why* a move was weak.
class MoveClassifier {
  /// Search depth used when scoring candidate moves. Kept shallower
  /// than [SimpleEngine]'s default opponent-search depth so
  /// classification stays responsive -- it runs once per human move,
  /// in addition to (not instead of) the opponent's own search.
  final int depth;

  const MoveClassifier({this.depth = 2});

  static const int _infinity = 1 << 30;

  /// Classifies [playedMove], which was legally played from
  /// [stateBeforeMove]. Returns null if classification can't be
  /// meaningfully computed (e.g. no legal moves existed, which
  /// shouldn't happen for a move that was actually played).
  MoveQuality? classify(GameState stateBeforeMove, Move playedMove) {
    final color = playedMove.piece.color;
    final legalMoves = MoveValidator.allLegalMoves(stateBeforeMove, color);
    if (legalMoves.isEmpty) return null;

    // A forced move (the only legal option) is never a mistake --
    // there was nothing else the player could have done.
    if (legalMoves.length == 1) return MoveQuality.excellent;

    final maximizing = color == PieceColor.white;
    int? bestScore;
    int? playedScore;

    for (final move in legalMoves) {
      final resultingState = _applyMoveToState(stateBeforeMove, move);
      final score =
          _minimax(resultingState, depth - 1, -_infinity, _infinity, !maximizing);

      if (bestScore == null ||
          (maximizing ? score > bestScore : score < bestScore)) {
        bestScore = score;
      }
      if (_sameMove(move, playedMove)) {
        playedScore = score;
      }
    }

    if (bestScore == null || playedScore == null) return null;

    // How many centipawns worse the played move was than the best
    // available move, always >= 0 by construction (the best move is,
    // by definition, at least as good as any other).
    final centipawnLoss =
        maximizing ? (bestScore - playedScore) : (playedScore - bestScore);

    if (centipawnLoss <= 15) return MoveQuality.excellent;
    if (centipawnLoss <= 50) return MoveQuality.good;
    if (centipawnLoss <= 150) return MoveQuality.mistake;
    return MoveQuality.blunder;
  }

  bool _sameMove(Move a, Move b) =>
      a.from == b.from &&
      a.to == b.to &&
      a.flag == b.flag &&
      a.promotesTo == b.promotesTo;

  int _minimax(
    GameState state,
    int remainingDepth,
    int alpha,
    int beta,
    bool maximizing,
  ) {
    final sideToMove = state.turnToMove;
    final legalMoves = MoveValidator.allLegalMoves(state, sideToMove);

    if (legalMoves.isEmpty) {
      final inCheck = MoveValidator.isInCheck(state, sideToMove);
      if (inCheck) {
        final mateScore = _infinity - (depth - remainingDepth);
        return maximizing ? -mateScore : mateScore;
      }
      return 0;
    }

    if (remainingDepth == 0) {
      return Evaluation.evaluate(state);
    }

    if (maximizing) {
      var value = -_infinity;
      for (final move in legalMoves) {
        final nextState = _applyMoveToState(state, move);
        final score =
            _minimax(nextState, remainingDepth - 1, alpha, beta, false);
        if (score > value) value = score;
        if (value > alpha) alpha = value;
        if (beta <= alpha) break;
      }
      return value;
    } else {
      var value = _infinity;
      for (final move in legalMoves) {
        final nextState = _applyMoveToState(state, move);
        final score =
            _minimax(nextState, remainingDepth - 1, alpha, beta, true);
        if (score < value) value = score;
        if (value < beta) beta = value;
        if (beta <= alpha) break;
      }
      return value;
    }
  }

  GameState _applyMoveToState(GameState state, Move move) {
    final newSquares = Board.applyMove(state, move);
    final movingColor = move.piece.color;

    Position? newEnPassantTarget;
    if (move.flag == MoveFlag.doublePawnPush) {
      final direction = movingColor == PieceColor.white ? -1 : 1;
      newEnPassantTarget = move.to.offset(0, direction);
    }

    return state.copyWith(
      newSquares: newSquares,
      turnToMove: movingColor.opposite,
      enPassantTarget: newEnPassantTarget,
      clearEnPassantTarget: newEnPassantTarget == null,
    );
  }
}
