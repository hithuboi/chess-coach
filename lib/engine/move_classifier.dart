import 'package:chess_app/engine/evaluation.dart';
import 'package:chess_app/game_logic/board.dart';
import 'package:chess_app/game_logic/move_generator.dart';
import 'package:chess_app/game_logic/move_validator.dart';
import 'package:chess_app/models/enums.dart';
import 'package:chess_app/models/game_state.dart';
import 'package:chess_app/models/move.dart';
import 'package:chess_app/models/move_analysis.dart';
import 'package:chess_app/models/position.dart';

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
/// coaching system can explain the type of error made.
class MoveClassifier {
  /// Search depth used when scoring candidate moves.
  final int depth;

  const MoveClassifier({this.depth = 2});

  static const int _infinity = 1 << 30;

  /// Classifies [playedMove] using the same analysis performed by
  /// [analyze].
  MoveQuality? classify(
    GameState stateBeforeMove,
    Move playedMove,
  ) {
    return analyze(stateBeforeMove, playedMove)?.quality;
  }

  /// Analyses a played move and determines its quality and,
  /// when possible, the type of mistake it represents.
  MoveAnalysis? analyze(
    GameState stateBeforeMove,
    Move playedMove,
  ) {
    final color = playedMove.piece.color;

    final legalMoves = MoveValidator.allLegalMoves(
      stateBeforeMove,
      color,
    );

    // There is nothing useful to classify if there are no legal
    // moves or only one legal move was available.
    if (legalMoves.isEmpty || legalMoves.length == 1) {
      return null;
    }

    final maximizing = color == PieceColor.white;

    int? bestScore;
    int? playedScore;
    Move? bestMove;

    // Evaluate every legal move to find the best available move.
    for (final move in legalMoves) {
      final resultingState = _applyMoveToState(
        stateBeforeMove,
        move,
      );

      final score = _minimax(
        resultingState,
        depth - 1,
        -_infinity,
        _infinity,
        !maximizing,
      );

      // Keep track of the best move available in the position.
      if (bestScore == null ||
          (maximizing
              ? score > bestScore
              : score < bestScore)) {
        bestScore = score;
        bestMove = move;
      }

      // Store the score of the move that was actually played.
      if (_sameMove(move, playedMove)) {
        playedScore = score;
      }
    }

    if (bestScore == null ||
        playedScore == null ||
        bestMove == null) {
      return null;
    }

    // Calculate how many centipawns were lost compared with the
    // best move.
    final centipawnLoss = maximizing
        ? bestScore - playedScore
        : playedScore - bestScore;

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
    // what the move allowed the opponent to do.
    final resultingState = _applyMoveToState(
      stateBeforeMove,
      playedMove,
    );

    // Determine the type of mistake after the move has been
    // classified as a mistake or blunder.
    final mistakeCategory = _categorizeMistake(
      stateBeforeMove,
      resultingState,
      playedMove,
      bestMove,
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
  /// The checks are ordered from concrete tactical evidence to
  /// broader behavioural patterns.
  MistakeCategory? _categorizeMistake(
    GameState stateBeforeMove,
    GameState stateAfterMove,
    Move playedMove,
    Move bestMove,
  ) {
    // Check whether the moved piece was genuinely left hanging.
    if (_isHangingPiece(stateAfterMove, playedMove)) {
      return MistakeCategory.hangingPiece;
    }

    // If the best alternative was a capture while the player did
    // not capture, classify the move as a missed capture.
    if (!playedMove.isCapture && bestMove.isCapture) {
      return MistakeCategory.missedCapture;
    }

    // If the best alternative gave check while the played move did
    // not, classify the move as a missed checking opportunity.
    if (!playedMove.isCheck && bestMove.isCheck) {
      return MistakeCategory.missedCheck;
    }

    // Detect repeated queen moves using the existing game history.
    if (_isRepeatedQueenMove(
      stateBeforeMove,
      playedMove,
    )) {
      return MistakeCategory.repeatedQueenMoves;
    }

    // More advanced positional categories will be implemented
    // in later coaching builds.
    return null;
  }

  /// Checks whether the piece just moved is genuinely hanging.
  ///
  /// A piece being capturable does not automatically mean it was
  /// hung because the player may have intentionally sacrificed it.
  /// Therefore, the opponent's capture must also be close to the
  /// opponent's best available response.
  bool _isHangingPiece(
    GameState stateAfterMove,
    Move playedMove,
  ) {
    final opponent = playedMove.piece.color.opposite;

    final opponentMoves = MoveValidator.allLegalMoves(
      stateAfterMove,
      opponent,
    );

    if (opponentMoves.isEmpty) {
      return false;
    }

    final opponentMaximizing = opponent == PieceColor.white;

    int? bestOpponentScore;
    int? captureScore;

    // Compare the capture of the moved piece against the
    // opponent's best available response.
    for (final move in opponentMoves) {
      final nextState = _applyMoveToState(
        stateAfterMove,
        move,
      );

      // Score the position from the opponent's perspective.
      final score = _minimax(
        nextState,
        depth - 1,
        -_infinity,
        _infinity,
        !opponentMaximizing,
      );

      // Find the opponent's best response.
      if (bestOpponentScore == null ||
          (opponentMaximizing
              ? score > bestOpponentScore
              : score < bestOpponentScore)) {
        bestOpponentScore = score;
      }

      // Remember the score of a move that captures the piece
      // that the player just moved.
      if (move.isCapture && move.to == playedMove.to) {
        captureScore = score;
      }
    }

    // The moved piece is not hanging if the opponent cannot capture
    // it or no best response could be determined.
    if (bestOpponentScore == null || captureScore == null) {
      return false;
    }

    // Allow a small evaluation difference because multiple
    // practically equivalent responses may exist.
    const acceptableDifference = 50;

    final difference = opponentMaximizing
        ? bestOpponentScore - captureScore
        : captureScore - bestOpponentScore;

    return difference <= acceptableDifference;
  }

  /// Checks whether the player has moved the queen repeatedly in
  /// the recent move history.
  ///
  /// This first version checks only the immediately preceding move.
  /// More advanced repetition tracking will be added later.
  bool _isRepeatedQueenMove(
    GameState stateBeforeMove,
    Move playedMove,
  ) {
    // The current move must be a queen move.
    if (playedMove.piece.type != PieceType.queen) {
      return false;
    }

    final history = stateBeforeMove.moveHistory;

    // There is no previous move to compare against.
    if (history.isEmpty) {
      return false;
    }

    final previousMove = history.last;

    return previousMove.piece.color == playedMove.piece.color &&
        previousMove.piece.type == PieceType.queen;
  }

  /// Checks whether two moves represent the same move.
  bool _sameMove(
    Move a,
    Move b,
  ) {
    return a.from == b.from &&
        a.to == b.to &&
        a.flag == b.flag &&
        a.promotesTo == b.promotesTo;
  }

  /// Performs a shallow minimax search with alpha-beta pruning.
  int _minimax(
    GameState state,
    int remainingDepth,
    int alpha,
    int beta,
    bool maximizing,
  ) {
    final sideToMove = state.turnToMove;

    // At the search horizon, checkmate and stalemate still need to
    // be handled correctly before using the static evaluation.
    if (remainingDepth == 0) {
      if (!_hasAnyLegalMove(state, sideToMove)) {
        final inCheck = MoveValidator.isInCheck(
          state,
          sideToMove,
        );

        if (inCheck) {
          final mateScore = _infinity - depth;
          return maximizing ? -mateScore : mateScore;
        }

        return 0;
      }

      return Evaluation.evaluate(state);
    }

    final legalMoves = MoveValidator.allLegalMoves(
      state,
      sideToMove,
    );

    // Handle checkmate and stalemate when there are no legal moves.
    if (legalMoves.isEmpty) {
      final inCheck = MoveValidator.isInCheck(
        state,
        sideToMove,
      );

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
        final nextState = _applyMoveToState(
          state,
          move,
        );

        final score = _minimax(
          nextState,
          remainingDepth - 1,
          alpha,
          beta,
          false,
        );

        if (score > value) {
          value = score;
        }

        if (value > alpha) {
          alpha = value;
        }

        // Alpha-beta pruning.
        if (beta <= alpha) {
          break;
        }
      }

      return value;
    } else {
      var value = _infinity;

      for (final move in legalMoves) {
        final nextState = _applyMoveToState(
          state,
          move,
        );

        final score = _minimax(
          nextState,
          remainingDepth - 1,
          alpha,
          beta,
          true,
        );

        if (score < value) {
          value = score;
        }

        if (value < beta) {
          beta = value;
        }

        // Alpha-beta pruning.
        if (beta <= alpha) {
          break;
        }
      }

      return value;
    }
  }

  /// Checks whether [color] has at least one legal move.
  bool _hasAnyLegalMove(
    GameState state,
    PieceColor color,
  ) {
    final pseudoLegalMoves =
        MoveGenerator.allPseudoLegalMoves(
      state,
      color,
    );

    for (final move in pseudoLegalMoves) {
      if (!MoveValidator.leavesOwnKingInCheck(
        state,
        move,
      )) {
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
    final newSquares = Board.applyMove(
      state,
      move,
    );

    final movingColor = move.piece.color;

    Position? newEnPassantTarget;

    // A double pawn push creates a new en-passant target square.
    if (move.flag == MoveFlag.doublePawnPush) {
      final direction =
          movingColor == PieceColor.white ? -1 : 1;

      newEnPassantTarget = move.to.offset(
        0,
        direction,
      );
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