import 'package:chess_app/engine/evaluation.dart';
import 'package:chess_app/game_logic/board.dart';
import 'package:chess_app/game_logic/move_generator.dart';
import 'package:chess_app/game_logic/move_validator.dart';
import 'package:chess_app/models/enums.dart';
import 'package:chess_app/models/game_state.dart';
import 'package:chess_app/models/move.dart';
import 'package:chess_app/models/position.dart';
import 'package:chess_app/models/move_analysis.dart';
import 'package:flutter/foundation.dart';

/// How a played move compares to the best move available in that
/// position.
enum MoveQuality {
  excellent,
  good,
  mistake,
  blunder,
}

/// Classifies a played move by comparing its resulting evaluation
/// against the best evaluation achievable from the same position.
///
/// The classifier also performs basic mistake categorisation so the
/// coaching system can eventually explain the type of error made.
class MoveClassifier {
  /// Search depth used when scoring candidate moves.
  final int depth;

  const MoveClassifier({this.depth = 2});

  static const int _infinity = 1 << 30;

  /// Classifies [playedMove] using the same analysis performed by
  /// [analyze].
  MoveQuality? classify(GameState stateBeforeMove, Move playedMove) {
    return analyze(stateBeforeMove, playedMove)?.quality;
  }

  /// Analyses a played move and determines its quality and,
  /// when possible, the type of mistake it represents.
  MoveAnalysis? analyze(
    GameState stateBeforeMove,
    Move playedMove,
  ) {
    final color = playedMove.piece.color;

    final legalMoves =
        MoveValidator.allLegalMoves(stateBeforeMove, color);

    if (legalMoves.isEmpty) return null;

    if (legalMoves.length == 1) return null;

    final maximizing = color == PieceColor.white;

    int? bestScore;
    int? playedScore;
    Move? bestMove;

    for (final move in legalMoves) {
      final resultingState =
          _applyMoveToState(stateBeforeMove, move);

      final score = _minimax(
        resultingState,
        depth - 1,
        -_infinity,
        _infinity,
        !maximizing,
      );

      if (bestScore == null ||
          (maximizing
              ? score > bestScore
              : score < bestScore)) {
        bestScore = score;
        bestMove = move;
      }

      if (_sameMove(move, playedMove)) {
        playedScore = score;
      }
    }

    if (bestScore == null ||
        playedScore == null ||
        bestMove == null) {
      return null;
    }

    final centipawnLoss = maximizing
        ? (bestScore - playedScore)
        : (playedScore - bestScore);

    final MoveQuality quality;

    if (centipawnLoss <= 10) {
      quality = MoveQuality.excellent;
    } else if (centipawnLoss <= 30) {
      quality = MoveQuality.good;
    } else if (centipawnLoss <= 120) {
      // Keep the existing intentionally-unclassified middle ground.
      return null;
    } else if (centipawnLoss <= 300) {
      quality = MoveQuality.mistake;
    } else {
      quality = MoveQuality.blunder;
    }

    // Build the position after the player's move so we can inspect
    // what the move actually allowed the opponent to do.
    final resultingState =
        _applyMoveToState(stateBeforeMove, playedMove);

    // Determine the type of mistake after the move has been
    // classified as a genuine mistake or blunder.
    final mistakeCategory = _categorizeMistake(
      stateBeforeMove,
      resultingState,
      playedMove,
      bestMove,
    );
    // Temporary verification: print the category detected for this move.
    debugPrint(
      'Mistake category: $mistakeCategory',
    );

    return MoveAnalysis(
      move: playedMove,
      quality: quality,
      bestScore: bestScore,
      playedScore: playedScore,
      centipawnLoss: centipawnLoss,
      bestMove: bestMove,

      // Store the detected mistake category in MoveAnalysis.
      mistakeCategory: mistakeCategory,
    );
  }

  /// Determines the most useful category for a mistake.
  ///
  /// The checks are deliberately ordered from concrete tactical
  /// evidence to broader behavioural patterns. If none of the
  /// currently reliable patterns match, the category remains null
  /// rather than assigning an inaccurate explanation.
  MistakeCategory? _categorizeMistake(
    GameState stateBeforeMove,
    GameState stateAfterMove,
    Move playedMove,
    Move bestMove,
  ) {
    // First check whether the move immediately left the moved piece
    // capturable by the opponent.
    if (_isHangingPiece(stateAfterMove, playedMove)) {
      return MistakeCategory.hangingPiece;
    }

    // If the engine's best alternative was a capture while the
    // player did not capture, treat the move as a missed capture.
    if (!playedMove.isCapture && bestMove.isCapture) {
      return MistakeCategory.missedCapture;
    }

    // If the best alternative gave check while the played move did
    // not, classify it as a missed checking opportunity.
    if (!playedMove.isCheck && bestMove.isCheck) {
      return MistakeCategory.missedCheck;
    }

    // Detect repeated queen moves using the existing game history.
    if (_isRepeatedQueenMove(stateBeforeMove, playedMove)) {
      return MistakeCategory.repeatedQueenMoves;
    }

    // These categories require deeper positional understanding.
    // They will be implemented in later coaching builds instead
    // of being guessed from insufficient information.
    return null;
  }

  /// Checks whether the piece just moved can immediately be captured
  /// by the opponent.
  ///
  /// This is a deliberately simple first version of "hanging piece":
  /// the opponent must have a legal capture onto the moved piece's
  /// destination square.
  bool _isHangingPiece(
    GameState stateAfterMove,
    Move playedMove,
  ) {
    final opponent = playedMove.piece.color.opposite;

    final opponentMoves =
        MoveValidator.allLegalMoves(stateAfterMove, opponent);

    for (final move in opponentMoves) {
      if (move.isCapture && move.to == playedMove.to) {
        return true;
      }
    }

    return false;
  }

  /// Checks whether the player has moved the queen repeatedly in the
  /// recent move history.
  ///
  /// This first version looks at the immediately preceding player
  /// move. More advanced repetition tracking will be added later.
  bool _isRepeatedQueenMove(
    GameState stateBeforeMove,
    Move playedMove,
  ) {
    if (playedMove.piece.type != PieceType.queen) {
      return false;
    }

    final history = stateBeforeMove.moveHistory;

    if (history.isEmpty) {
      return false;
    }

    final previousMove = history.last;

    return previousMove.piece.color == playedMove.piece.color &&
        previousMove.piece.type == PieceType.queen;
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

    // At the search horizon, only "does any legal move exist" matters
    // so checkmate and stalemate are scored correctly.
    if (remainingDepth == 0) {
      if (!_hasAnyLegalMove(state, sideToMove)) {
        final inCheck =
            MoveValidator.isInCheck(state, sideToMove);

        if (inCheck) {
          final mateScore = _infinity - depth;
          return maximizing ? -mateScore : mateScore;
        }

        return 0;
      }

      return Evaluation.evaluate(state);
    }

    final legalMoves =
        MoveValidator.allLegalMoves(state, sideToMove);

    if (legalMoves.isEmpty) {
      final inCheck =
          MoveValidator.isInCheck(state, sideToMove);

      if (inCheck) {
        final mateScore =
            _infinity - (depth - remainingDepth);

        return maximizing ? -mateScore : mateScore;
      }

      return 0;
    }

    if (maximizing) {
      var value = -_infinity;

      for (final move in legalMoves) {
        final nextState =
            _applyMoveToState(state, move);

        final score = _minimax(
          nextState,
          remainingDepth - 1,
          alpha,
          beta,
          false,
        );

        if (score > value) value = score;
        if (value > alpha) alpha = value;

        if (beta <= alpha) break;
      }

      return value;
    } else {
      var value = _infinity;

      for (final move in legalMoves) {
        final nextState =
            _applyMoveToState(state, move);

        final score = _minimax(
          nextState,
          remainingDepth - 1,
          alpha,
          beta,
          true,
        );

        if (score < value) value = score;
        if (value < beta) beta = value;

        if (beta <= alpha) break;
      }

      return value;
    }
  }

  /// Checks whether [color] has at least one legal move.
  bool _hasAnyLegalMove(
    GameState state,
    PieceColor color,
  ) {
    for (final move
        in MoveGenerator.allPseudoLegalMoves(state, color)) {
      if (!MoveValidator.leavesOwnKingInCheck(state, move)) {
        return true;
      }
    }

    return false;
  }

  /// Creates the game state resulting from applying [move].
  GameState _applyMoveToState(
    GameState state,
    Move move,
  ) {
    final newSquares =
        Board.applyMove(state, move);

    final movingColor = move.piece.color;

    Position? newEnPassantTarget;

    if (move.flag == MoveFlag.doublePawnPush) {
      final direction =
          movingColor == PieceColor.white ? -1 : 1;

      newEnPassantTarget =
          move.to.offset(0, direction);
    }

    return state.copyWith(
      newSquares: newSquares,
      turnToMove: movingColor.opposite,
      enPassantTarget: newEnPassantTarget,
      clearEnPassantTarget:
          newEnPassantTarget == null,
    );
  }
}