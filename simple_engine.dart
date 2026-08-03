import 'dart:math';

import 'package:chess_app/engine/chess_engine.dart';
import 'package:chess_app/engine/evaluation.dart';
import 'package:chess_app/game_logic/board.dart';
import 'package:chess_app/game_logic/move_generator.dart';
import 'package:chess_app/game_logic/move_validator.dart';
import 'package:chess_app/models/enums.dart';
import 'package:chess_app/models/game_state.dart';
import 'package:chess_app/models/move.dart';
import 'package:chess_app/models/position.dart';

/// A straightforward computer opponent using minimax search with
/// alpha-beta pruning to a fixed depth.
class SimpleEngine implements ChessEngine {
  /// How many plies (half-moves) ahead the engine searches.
  final int searchDepth;

  /// Random source used only to break ties between equally-scored moves.
  final Random _random;

  SimpleEngine({this.searchDepth = 3, int? randomSeed})
      : _random = randomSeed != null ? Random(randomSeed) : Random();

  @override
  String get name => 'Simple Engine (depth $searchDepth)';

  @override
  Future<Move?> chooseMove(GameState state, PieceColor color) async {
    final legalMoves = MoveValidator.allLegalMoves(state, color);
    if (legalMoves.isEmpty) return null;

    final maximizing = color == PieceColor.white;
    var bestScore = maximizing ? -_infinity : _infinity;
    final bestMoves = <Move>[];

    for (final move in legalMoves) {
      final resultingState = _applyMoveToState(state, move);
      final score = _minimax(
        resultingState,
        searchDepth - 1,
        -_infinity,
        _infinity,
        !maximizing,
      );

      final isBetter = maximizing ? score > bestScore : score < bestScore;
      final isEqual = score == bestScore;

      if (isBetter) {
        bestScore = score;
        bestMoves
          ..clear()
          ..add(move);
      } else if (isEqual) {
        bestMoves.add(move);
      }
    }

    return bestMoves[_random.nextInt(bestMoves.length)];
  }

  static const int _infinity = 1 << 30;

  int _minimax(
    GameState state,
    int depth,
    int alpha,
    int beta,
    bool maximizing,
  ) {
    final sideToMove = state.turnToMove;

    // At the search horizon, the full legal-move list was only ever
    // being used to answer one yes/no question -- "does the side to
    // move have any legal move at all" (needed to correctly score
    // checkmate/stalemate rather than just returning a plain material
    // count for an already-decided position). Leaf nodes are by far
    // the most numerous nodes in the tree, so answering that with an
    // early-exit check (stop at the first legal move found) instead
    // of enumerating every legal move is the single biggest cost
    // saving available here.
    if (depth == 0) {
      if (!_hasAnyLegalMove(state, sideToMove)) {
        final inCheck = MoveValidator.isInCheck(state, sideToMove);
        if (inCheck) {
          final mateScore = _infinity - searchDepth;
          return maximizing ? -mateScore : mateScore;
        }
        return 0;
      }
      return Evaluation.evaluate(state);
    }

    final legalMoves = MoveValidator.allLegalMoves(state, sideToMove);

    if (legalMoves.isEmpty) {
      final inCheck = MoveValidator.isInCheck(state, sideToMove);
      if (inCheck) {
        final mateScore = _infinity - (searchDepth - depth);
        return maximizing ? -mateScore : mateScore;
      }
      return 0;
    }

    if (maximizing) {
      var value = -_infinity;
      for (final move in legalMoves) {
        final nextState = _applyMoveToState(state, move);
        value = max(value, _minimax(nextState, depth - 1, alpha, beta, false));
        alpha = max(alpha, value);
        if (beta <= alpha) break;
      }
      return value;
    } else {
      var value = _infinity;
      for (final move in legalMoves) {
        final nextState = _applyMoveToState(state, move);
        value = min(value, _minimax(nextState, depth - 1, alpha, beta, true));
        beta = min(beta, value);
        if (beta <= alpha) break;
      }
      return value;
    }
  }

  /// True if [color] has at least one legal move in [state]. Stops at
  /// the first legal move it finds, rather than generating and
  /// validating every pseudo-legal move the way [MoveValidator.
  /// allLegalMoves] does -- which matters a lot here, since this runs
  /// once per leaf node (the most numerous node type in the tree) and
  /// almost every position has plenty of legal moves, so the early
  /// exit typically fires within the first few candidates checked.
  bool _hasAnyLegalMove(GameState state, PieceColor color) {
    for (final move in MoveGenerator.allPseudoLegalMoves(state, color)) {
      if (!MoveValidator.leavesOwnKingInCheck(state, move)) return true;
    }
    return false;
  }

  /// Produces the resulting [GameState] after [move], for search
  /// purposes only — skips move history/notation bookkeeping to keep
  /// each explored node as cheap as possible.
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
