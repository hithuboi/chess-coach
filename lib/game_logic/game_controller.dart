import 'package:flutter/foundation.dart';
import 'package:chess_app/game_logic/board.dart';
import 'package:chess_app/game_logic/check_detector.dart';
import 'package:chess_app/game_logic/move_validator.dart';
import 'package:chess_app/models/enums.dart';
import 'package:chess_app/models/game_state.dart';
import 'package:chess_app/models/move.dart';
import 'package:chess_app/models/position.dart';
import 'package:chess_app/engine/move_classifier.dart';
import 'package:chess_app/models/move_analysis.dart';
import 'package:chess_app/coaching/coaching_engine.dart';
/// Orchestrates a single game of chess: applying moves, undo, restart,
/// and exposing the current state to the UI.
///
/// Extends [ChangeNotifier] so widgets can listen for updates via
/// `ListenableBuilder` without a third-party state-management package.
class GameController extends ChangeNotifier {
  GameState _state = GameState.initial();
  
  final MoveClassifier _moveClassifier = const MoveClassifier();

  MoveAnalysis? _lastMoveAnalysis;

  MoveAnalysis? get lastMoveAnalysis => _lastMoveAnalysis;

  final CoachingEngine coachingEngine = CoachingEngine();   //Added this after creating lib/coach, connects coach to game controller, since controller already controls game flow.

  /// Stack of previous states, used to support [undo].
  final List<GameState> _undoStack = [];

  /// The current game state. Read-only from outside this controller.
  GameState get state => _state;

  /// Whether at least one move can currently be undone.
  bool get canUndo => _undoStack.isNotEmpty;

  /// The state exactly as it was immediately before the most recent
  /// move was played, or null if no move has been played yet (or the
  /// game was just restarted). This is the same snapshot [undo] would
  /// restore -- exposed read-only here so callers (like move-quality
  /// classification) can compare "before" and "after" a move without
  /// the controller needing to know anything about why they want it.
  GameState? get previousState => _undoStack.isEmpty ? null : _undoStack.last;

  /// Full move history for the UI's move-history panel.
  List<Move> get moveHistory => _state.moveHistory;

  /// Returns every fully legal move for the piece on [from].
  List<Move> legalMovesFrom(Position from) =>
      MoveValidator.legalMovesFrom(_state, from);

  /// Returns every fully legal move for [color] in the current position.
  List<Move> allLegalMoves(PieceColor color) =>
      MoveValidator.allLegalMoves(_state, color);

  /// Attempts to play [move]. Returns true and updates [state] if the
  /// move is legal; returns false (with no state change) otherwise.
  bool makeMove(Move move) {
    if (_state.isGameOver) return false;
    if (!MoveValidator.isLegalMove(_state, move)) return false;

    _lastMoveAnalysis = _moveClassifier.analyze(_state, move);
    

    // Send the analysis to the coach only when a valid analysis was produced:
    
    // Send the analysis to the coach only when a valid analysis was produced:
    if (_lastMoveAnalysis != null) {
      // Send the completed move analysis to the coaching engine.
      coachingEngine.observeMove(_lastMoveAnalysis!);
    }
    _undoStack.add(_state);

    final newSquares = Board.applyMove(_state, move);
    final movingColor = move.piece.color;
    final opponentColor = movingColor.opposite;

    final isReset = move.piece.type == PieceType.pawn || move.isCapture;
    final newHalfMoveClock = isReset ? 0 : _state.halfMoveClock + 1;

    final newFullMoveNumber = movingColor == PieceColor.black
        ? _state.fullMoveNumber + 1
        : _state.fullMoveNumber;

    Position? newEnPassantTarget;
    if (move.flag == MoveFlag.doublePawnPush) {
      final direction = movingColor == PieceColor.white ? -1 : 1;
      newEnPassantTarget = move.to.offset(0, direction);
    }

    var intermediateState = _state.copyWith(
      newSquares: newSquares,
      turnToMove: opponentColor,
      halfMoveClock: newHalfMoveClock,
      fullMoveNumber: newFullMoveNumber,
      enPassantTarget: newEnPassantTarget,
      clearEnPassantTarget: newEnPassantTarget == null,
    );

    final opponentInCheck =
        MoveValidator.isInCheck(intermediateState, opponentColor);
    final opponentHasLegalMoves =
        MoveValidator.allLegalMoves(intermediateState, opponentColor)
            .isNotEmpty;
    final isCheckmate = opponentInCheck && !opponentHasLegalMoves;

    final recordedMove = move.copyWith(
      isCheck: opponentInCheck,
      isCheckmate: isCheckmate,
    );

    final status = CheckDetector.statusFor(intermediateState);

    _state = intermediateState.copyWith(
      moveHistory: [..._state.moveHistory, recordedMove],
      status: status,
    );

    notifyListeners();
    return true;
  }

  /// Reverts the most recent move, restoring the exact prior state.
  void undo() {
    if (_undoStack.isEmpty) return;
    _state = _undoStack.removeLast();
    notifyListeners();
  }

  /// Resets the game to the standard starting position.
  void restart() {
    _state = GameState.initial();
    _undoStack.clear();
    notifyListeners();
  }
}
