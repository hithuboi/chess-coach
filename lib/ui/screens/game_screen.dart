import 'package:flutter/material.dart';
import 'package:chess_app/engine/chess_engine.dart';
import 'package:chess_app/engine/move_classifier.dart';
import 'package:chess_app/engine/simple_engine.dart';
import 'package:chess_app/game_logic/board.dart';
import 'package:chess_app/game_logic/game_controller.dart';
import 'package:chess_app/game_logic/game_save_service.dart';
import 'package:chess_app/models/enums.dart';
import 'package:chess_app/models/game_state.dart';
import 'package:chess_app/models/move.dart';
import 'package:chess_app/models/position.dart';
import 'package:chess_app/ui/widgets/chess_board_widget.dart';
import 'package:chess_app/ui/widgets/move_history_panel.dart';
import 'package:chess_app/utils/constants.dart';
import 'package:chess_app/utils/extensions.dart';
import 'package:chess_app/models/move_analysis.dart';
import 'package:chess_app/coaching/coaching_state.dart';

/// The main (and, in v0.1, only) screen: assembles the board, move
/// history, and controls, and drives the computer opponent's turns.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameController _controller = GameController();
  final ChessEngine _engine =
      SimpleEngine(searchDepth: defaultEngineSearchDepth);
  final GameSaveService _saveService = const GameSaveService();
  final MoveClassifier _moveClassifier = const MoveClassifier();

  /// Which color the human player is currently controlling. Chosen via
  /// [_promptForColorChoice] at launch and again every time a new game
  /// starts -- defaults to White only as a placeholder until that
  /// first choice is made.
  PieceColor _humanColor = PieceColor.white;
  PieceColor get _computerColor => _humanColor.opposite;

  /// True while the computer is "thinking".
  bool _computerIsThinking = false;

  /// True once the end-of-game dialog has been shown for the current
  /// game, so it doesn't reappear on every subsequent rebuild while
  /// the finished position is still on screen.
  bool _hasShownGameOverDialog = false;

  /// True while [_onUndo] is actively popping one or more moves off
  /// the controller. [GameController.undo] fires the same state-change
  /// notification a real move does, which would otherwise re-enter
  /// [_onGameStateChanged] mid-undo and let it auto-trigger the
  /// computer's move (or reclassify a move) before the intended
  /// two-step undo has finished. This flag suppresses both of those
  /// side effects for the duration of an undo; [_onUndo] performs its
  /// own single, explicit check for whether the bot needs to move
  /// afterward, once the full undo is complete.
  bool _isUndoing = false;

  /// True once the human player has resigned the current game.
  /// Resignation isn't a concept [GameController]/[GameStatus] models
  /// (it isn't a rules-derived outcome), so it's tracked purely at the
  /// screen level -- the board is locked out via [AbsorbPointer] on
  /// the [ChessBoardWidget] rather than through the controller's own
  /// `isGameOver` flag.
  bool _hasResigned = false;

  /// Which color resigned, so the status banner and end-of-game dialog
  /// can correctly declare the other side the winner. Only meaningful
  /// when [_hasResigned] is true.
  PieceColor? _resignedColor;

  /// True once the game has ended by any means -- a real rules-based
  /// outcome (checkmate, stalemate, a draw) or a resignation. Used
  /// throughout the UI (locking the board, swapping Resign for New
  /// Game, the status banner) so every place that needs "is the game
  /// over" checks both sources the same way.
  bool get _isGameEffectivelyOver => _controller.state.isGameOver || _hasResigned;

  /// Quality classification for the human player's own moves, keyed by
  /// that move's index in the controller's move history. Computed
  /// asynchronously right after each human move so it never delays
  /// that move's own board update.
  final Map<int, MoveQuality> _moveQualities = {};

  /// The currently active hint's suggested move, or null if no hint
  /// has been requested (or it's since been cleared). Computed by
  /// asking [_engine] -- the same engine that plays the opponent's
  /// side -- for its best move on the human's behalf, so the hint is
  /// exactly as strong as the opponent currently being played.
  Move? _hintMove;

  /// True while a hint is being computed, so the button can't be
  /// pressed again (and start a second overlapping search) before the
  /// first one resolves.
  bool _isComputingHint = false;

  /// The move history of the game being reviewed, snapshotted the
  /// moment "Review Game" is chosen. Kept separate from the live
  /// [GameController] so starting a new game afterward never affects
  /// what's currently being reviewed. Null whenever not in review
  /// mode.
  List<Move>? _reviewMoveHistory;

  /// How many moves into [_reviewMoveHistory] the review board is
  /// currently showing -- 0 is the starting position (before move 1),
  /// and [_reviewMoveHistory]'s length is the game's final position.
  /// Null whenever not in review mode.
  int? _reviewIndex;

  bool get _isReviewingGame => _reviewMoveHistory != null;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onGameStateChanged);
    // Listen for coaching-state changes so the UI rebuilds when the
    // coach detects a mistake, blunder, or other coaching event.
    _controller.coachingEngine.addListener(_onCoachingStateChanged);
    // Ask which color to play as before the very first game, same as
    // every subsequent "New Game" -- deferred to after the first frame
    // so the dialog's context is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startNewGameFlow());
  }
  /// Responds to changes from the coaching engine.
  ///
  /// The coaching engine has its own ChangeNotifier because coaching
  /// state is separate from the normal chess game state. For now we
  /// simply rebuild the UI when a new coaching event is received.
  /// The actual coaching message will be added in the next step.
  void _onCoachingStateChanged() {
    if (!mounted) return;
  
    setState(() {});
  }


  @override

  void dispose() {
    _controller.removeListener(_onGameStateChanged);

    // Stop listening to the coaching engine when this screen is
    // destroyed so the controller cannot trigger updates on a
    // screen that no longer exists.
    _controller.coachingEngine.removeListener(_onCoachingStateChanged);

    super.dispose();
  }

  void _onGameStateChanged() {
    final state = _controller.state;

    // A hint is only valid for the exact position it was computed
    // for -- the instant that position changes, for any reason (a
    // move played, an undo, a new game), the suggestion is stale and
    // must be cleared rather than pointing at squares that no longer
    // mean what they used to.
    if (_hintMove != null) {
      setState(() => _hintMove = null);
    }

    // Drop classification entries for any moves that no longer exist
    // (e.g. after an undo) -- cheap, and keeps the map from ever
    // referring to a move index that's since been replaced.
    _moveQualities.removeWhere((index, _) => index >= state.moveHistory.length);

    // If the move that was just played belongs to the human, classify
    // it in the background (after this frame paints) so the move
    // itself still reflects on the board instantly. Checked before the
    // isGameOver branch below so a game-ending move (e.g. delivering
    // checkmate) still gets classified rather than being skipped.
    // Skipped entirely during an undo -- there's no new move to
    // classify, only an old one being removed.
    final lastMove = state.moveHistory.isNotEmpty ? state.moveHistory.last : null;
    final previous = _controller.previousState;
    if (!_isUndoing &&
        lastMove != null &&
        previous != null &&
        lastMove.piece.color == _humanColor) {
      final moveIndex = state.moveHistory.length - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final quality = _moveClassifier.classify(previous, lastMove);
        if (quality != null) {
          setState(() => _moveQualities[moveIndex] = quality);
        }
      });
    }

    if (state.isGameOver) {
      if (!_hasShownGameOverDialog) {
        _hasShownGameOverDialog = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showGameOverDialog(state.status, state.turnToMove);
        });
      }
      return;
    }

    if (!_isUndoing &&
        state.turnToMove == _computerColor &&
        !_computerIsThinking) {
      _triggerComputerMove();
    }
  }

  /// Asks which color the player wants to play as. Non-dismissible --
  /// a choice is always required before a game can begin.
  Future<PieceColor> _promptForColorChoice() async {
    final choice = await showDialog<PieceColor>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Play as:', textAlign: TextAlign.center),
        content: SizedBox(
          width: 2600,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _ColorChoiceButton(
                    label: 'White',
                    backgroundColor: const Color(0xFFF8F4EC),
                    textColor: Colors.black,
                    onTap: () =>
                        Navigator.of(dialogContext).pop(PieceColor.white),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _ColorChoiceButton(
                    label: 'Black',
                    backgroundColor: const Color(0xFF2B2A27),
                    textColor: Colors.white,
                    onTap: () =>
                        Navigator.of(dialogContext).pop(PieceColor.black),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // barrierDismissible is false, so this should always resolve to a
    // real choice -- default to White only as an unreachable fallback.
    return choice ?? PieceColor.white;
  }

  /// Shows a modal summarizing how the game ended, with three clear
  /// next steps: save the finished game, dismiss to review the board,
  /// or start a new game immediately. Derives the title/message from
  /// the rules-based [status] -- for a resignation (which isn't a
  /// [GameStatus]), see [_onResign], which calls [_showEndOfGameDialog]
  /// directly with its own title/message instead.
  Future<void> _showGameOverDialog(GameStatus status, PieceColor turnToMove) {
    final (title, message) = switch (status) {
      GameStatus.checkmate => (
          'Checkmate',
          '${turnToMove.opposite.displayName} wins the game.',
        ),
      GameStatus.stalemate => ('Stalemate', 'The game is a draw.'),
      GameStatus.insufficientMaterial => (
          'Draw',
          'Neither side has enough material to checkmate.',
        ),
      GameStatus.fiftyMoveRule => (
          'Draw',
          'Fifty moves have passed with no pawn move or capture.',
        ),
      GameStatus.threefoldRepetition => (
          'Draw',
          'The same position has occurred three times.',
        ),
      _ => ('Game Over', 'The game has ended.'),
    };

    return _showEndOfGameDialog(title: title, message: message);
  }

  /// The actual end-of-game dialog UI, shared by every way a game can
  /// end (checkmate, stalemate, a draw, or resignation) -- each caller
  /// just supplies its own title and message.
  Future<void> _showEndOfGameDialog({
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        // Building the buttons here, inside `content`, rather than via
        // AlertDialog's `actions` -- three buttons with labels this
        // long ("Save Game", "Review Board", "New Game") often don't
        // fit the dialog's default width, and Flutter's actions layout
        // (OverflowBar) silently stacks them into a tall vertical
        // column instead of shrinking them. Laying them out ourselves
        // in a fixed-width Row guarantees they stay small and
        // horizontal regardless of available space.
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(message),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () => _onSaveGame(),
                      child: const Text('Save', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _startReviewingGame();
                      },
                      child: const Text('Review Game',
                          style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _startNewGameFlow();
                      },
                      child: const Text('New Game',
                          style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Confirms with the player, then ends the game as a resignation.
  /// Shows the same end-of-game dialog as a real rules-based outcome,
  /// just with its own title/message -- everything downstream (Save,
  /// Review, New Game) behaves identically either way.
  Future<void> _onResign() async {
    if (_isGameEffectivelyOver) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text('Resigning will end the game immediately.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final resigningColor = _humanColor;
    setState(() {
      _hasResigned = true;
      _resignedColor = resigningColor;
      // A hint requested right before resigning would otherwise still
      // be highlighted on the board after the game has ended.
      _hintMove = null;
    });

    await _showEndOfGameDialog(
      title: 'Resignation',
      message: '${resigningColor.displayName} resigned — '
          '${resigningColor.opposite.displayName} wins.',
    );
  }

  /// Saves the current game's move history to disk. Does NOT close the
  /// game-over dialog -- the player may still want to review the board
  /// or start a new game afterward, so saving is a side action rather
  /// than something that advances the flow on its own.
  Future<void> _onSaveGame() async {
    try {
      final path = await _saveService.saveGame(
        moveHistory: _controller.moveHistory,
        finalStatus: _controller.state.status,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Game saved to $path')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the game.')),
      );
    }
  }

  /// Minimum time the computer's move is held before being applied to
  /// the board, regardless of how fast it was actually calculated --
  /// purely a pacing delay so the opponent's reply never feels
  /// instantaneous. The human's own moves are never delayed by this.
  static const Duration _minimumBotMoveDelay = Duration(milliseconds: 900);

  Future<void> _triggerComputerMove() async {
    setState(() => _computerIsThinking = true);

    final state = _controller.state;

    final results = await Future.wait<Move?>([
      _engine.chooseMove(state, _computerColor),
      Future<Move?>.delayed(_minimumBotMoveDelay, () => null),
    ]);
    final move = results[0];

    if (!mounted || _hasResigned) return;
    setState(() => _computerIsThinking = false);

    if (move != null) {
      _controller.makeMove(move);
    }
  }

  /// Undoes the human's last move together with the computer's reply
  /// to it, so the human always lands back on their own turn with a
  /// chance to play something different.
  ///
  /// The exact number of moves to pop is computed once, upfront, from
  /// the move history as it stands right now -- not re-checked after
  /// each individual undo -- because [GameController.undo] fires the
  /// same notification a real move does, and re-checking mid-sequence
  /// previously let that notification's listener react before this
  /// method finished, causing the bot to immediately replay a move
  /// that had just been undone (or, in a human-plays-Black game,
  /// leaving the bot permanently stuck never moving again). See
  /// [_isUndoing].
  void _onUndo() {
    final history = _controller.moveHistory;
    if (history.isEmpty || _computerIsThinking) return;

    final lastMove = history.last;
    // Normally the most recent move is the computer's reply, and the
    // human move right before it should go too. The one exception is
    // a human-plays-Black game where the computer has only played its
    // forced opening move and the human hasn't moved at all yet --
    // there, only that single move exists to undo.
    final undoCount = (lastMove.piece.color == _computerColor &&
            history.length >= 2)
        ? 2
        : 1;

    _isUndoing = true;
    for (var i = 0; i < undoCount; i++) {
      _controller.undo();
    }
    _isUndoing = false;

    // After undoing, it's almost always the human's turn again. The
    // one case where it isn't (the human-plays-Black edge case above,
    // where undoing removed the only move in the game) needs the
    // computer's opening move re-triggered explicitly, since the
    // automatic listener was deliberately suppressed during the undo
    // itself.
    if (_controller.state.turnToMove == _computerColor && !_computerIsThinking) {
      _triggerComputerMove();
    }
  }

  /// Asks [_engine] -- the same engine that plays the opponent's side
  /// -- for its best move on the human's behalf, then highlights that
  /// move's origin and destination squares on the board. Only
  /// available on the human's own turn, mid-game, and not while
  /// another hint is already being computed.
  Future<void> _onHint() async {
    final requestState = _controller.state;
    if (_isGameEffectivelyOver ||
        _computerIsThinking ||
        _isComputingHint ||
        requestState.turnToMove != _humanColor) {
      return;
    }

    setState(() => _isComputingHint = true);
    final move = await _engine.chooseMove(requestState, _humanColor);

    // If the position has since moved on (the player made a move,
    // undid one, or started a new game while this was computing),
    // the result no longer applies to anything on screen -- discard
    // it rather than highlighting squares from a stale position.
    if (!mounted || !identical(_controller.state, requestState)) return;

    setState(() {
      _isComputingHint = false;
      _hintMove = move;
    });
  }

  /// Enters review mode for the game that just ended: snapshots its
  /// move history and jumps the board back to the starting position,
  /// ready for the player to step forward through it move by move.
  void _startReviewingGame() {
    setState(() {
      _reviewMoveHistory = List.of(_controller.moveHistory);
      _reviewIndex = 0;
      // A hint from right before the game ended (e.g. requested just
      // before resigning) would otherwise still be sitting on the
      // board -- irrelevant, and potentially confusing, once review
      // mode starts showing historical positions instead.
      _hintMove = null;
    });
  }

  void _reviewStepBack() {
    if (_reviewIndex == null || _reviewIndex! <= 0) return;
    setState(() => _reviewIndex = _reviewIndex! - 1);
  }

  void _reviewStepForward() {
    final history = _reviewMoveHistory;
    if (history == null || _reviewIndex == null) return;
    if (_reviewIndex! >= history.length) return;
    setState(() => _reviewIndex = _reviewIndex! + 1);
  }

  /// Reconstructs the board exactly as it stood after the first
  /// [moveCount] moves of [history], by replaying them from the
  /// standard starting position. Mirrors the same replay approach
  /// [SimpleEngine] and [MoveClassifier] already use internally for
  /// their own search -- one self-contained, read-only reconstruction
  /// rather than a second copy of [GameController]'s live state.
  GameState _computeReviewState(List<Move> history, int moveCount) {
    var state = GameState.initial();

    for (var i = 0; i < moveCount; i++) {
      final move = history[i];
      final newSquares = Board.applyMove(state, move);
      final movingColor = move.piece.color;

      Position? newEnPassantTarget;
      if (move.flag == MoveFlag.doublePawnPush) {
        final direction = movingColor == PieceColor.white ? -1 : 1;
        newEnPassantTarget = move.to.offset(0, direction);
      }

      state = state.copyWith(
        newSquares: newSquares,
        turnToMove: movingColor.opposite,
        moveHistory: history.sublist(0, i + 1),
        enPassantTarget: newEnPassantTarget,
        clearEnPassantTarget: newEnPassantTarget == null,
      );
    }

    // The replayed moves already recorded whether they gave check or
    // checkmate at the time they were actually played -- reusing that
    // here (rather than re-running check detection) is enough to
    // correctly show the check highlight at the right point in the
    // replay.
    if (moveCount > 0) {
      final lastMove = history[moveCount - 1];
      final status = lastMove.isCheckmate
          ? GameStatus.checkmate
          : lastMove.isCheck
              ? GameStatus.check
              : GameStatus.active;
      state = state.copyWith(status: status);
    }

    return state;
  }

  /// Starts a brand-new game: asks which color to play as, resets all
  /// screen-level state, then resets the controller. If the computer
  /// ends up playing White, [_onGameStateChanged] picks that up
  /// automatically the moment `restart()` fires its notification (by
  /// then [_humanColor] is already updated) and kicks off its opening
  /// move on its own -- no separate trigger needed here, which avoids
  /// ever starting two concurrent engine searches for the same turn.
  Future<void> _startNewGameFlow() async {
    final chosenColor = await _promptForColorChoice();
    if (!mounted) return;

    setState(() {
      _humanColor = chosenColor;
      _computerIsThinking = false;
      _hasShownGameOverDialog = false;
      _hasResigned = false;
      _resignedColor = null;
      _reviewMoveHistory = null;
      _reviewIndex = null;
      _hintMove = null;
      _moveQualities.clear();
    });
    _controller.restart();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chess'),
        actions: [
          if (_computerIsThinking)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: standardPagePadding,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWideLayout = constraints.maxWidth >= wideLayoutBreakpoint;
              return isWideLayout
                  ? _buildWideLayout(context)
                  : _buildNarrowLayout(context);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: AbsorbPointer(
              absorbing: _isGameEffectivelyOver,
              child: ChessBoardWidget(
                controller: _controller,
                humanColor: _humanColor,
                hintMove: _hintMove,
                reviewState: _isReviewingGame
                    ? _computeReviewState(
                        _reviewMoveHistory!, _reviewIndex ?? 0)
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 280,
          child: _buildSidePanel(context),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Center(
            child: AbsorbPointer(
              absorbing: _isGameEffectivelyOver,
              child: ChessBoardWidget(
                controller: _controller,
                humanColor: _humanColor,
                hintMove: _hintMove,
                reviewState: _isReviewingGame
                    ? _computeReviewState(
                        _reviewMoveHistory!, _reviewIndex ?? 0)
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          flex: 2,
          child: _buildSidePanel(context),
        ),
      ],
    );
  }
  Widget _buildCoachCard(BuildContext context) {
    final coachingEngine = _controller.coachingEngine;
    final analysis = coachingEngine.currentAnalysis;
    final coachingState = coachingEngine.state;

    // Nothing to show until the coach has received an analysis.
    if (analysis == null) {
      return const SizedBox.shrink();
    }

    // The coach only needs to intervene for mistakes and blunders.
    if (coachingState != CoachingState.mistakeDetected) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    final isBlunder = analysis.quality == MoveQuality.blunder;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isBlunder
                    ? Icons.warning_rounded
                    : Icons.warning_amber_rounded,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Text(
                isBlunder ? 'Blunder' : 'Mistake',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Move: ${analysis.move}',
            style: TextStyle(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Centipawn loss: ${analysis.centipawnLoss}',
            style: TextStyle(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
          if (analysis.bestMove != null) ...[
            const SizedBox(height: 4),
            Text(
              'Best move: ${analysis.bestMove}',
              style: TextStyle(
                color: theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
  Widget _buildSidePanel(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final state = _controller.state;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusBanner(context, state.status, state.turnToMove),
            const SizedBox(height: 12),
            Expanded(
              child: MoveHistoryPanel(
                moves: _controller.moveHistory,
                moveQualities: _moveQualities,
              ),
            ),
            const SizedBox(height: 12),
            _isReviewingGame ? _buildReviewControlsRow() : _buildControlsRow(),
          ],
        );
      },
    );
  }

  /// Undo, plus Resign while the game is still active. Once the game
  /// has ended, Hint and Resign both stop being meaningful actions and
  /// are hidden rather than shown disabled -- the end-of-game dialog's
  /// own Save/Review Game/New Game buttons are the actual next steps
  /// at that point, so this row has nothing left to add.
  Widget _buildControlsRow() {
    final gameEnded = _isGameEffectivelyOver;
    final canUndo = _controller.canUndo && !_computerIsThinking && !gameEnded;
    final canHint = !gameEnded &&
        !_computerIsThinking &&
        !_isComputingHint &&
        _controller.state.turnToMove == _humanColor;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FilledButton.tonalIcon(
          onPressed: canUndo ? _onUndo : null,
          icon: const Icon(Icons.undo),
          label: const Text('Undo'),
        ),
        if (!gameEnded) ...[
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: canHint ? _onHint : null,
            tooltip: 'Hint',
            icon: _isComputingHint
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lightbulb_outline),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _onResign,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
            ),
            icon: const Icon(Icons.flag, color: Colors.red),
            label: const Text(
              'Resign',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }

  /// Shown instead of [_buildControlsRow] while reviewing a finished
  /// game -- just the two step controls, since Hint and Resign don't
  /// apply once the game is over and being replayed move by move.
  Widget _buildReviewControlsRow() {
  final history = _reviewMoveHistory;
  final index = _reviewIndex ?? 0;
  final canGoBack = index > 0;
  final canGoForward = history != null && index < history.length;

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton.filledTonal(
            onPressed: canGoBack ? _reviewStepBack : null,
            tooltip: 'Previous move',
            icon: const Icon(Icons.undo),
          ),
          const SizedBox(width: 16),
          IconButton.filledTonal(
            onPressed: canGoForward ? _reviewStepForward : null,
            tooltip: 'Next move',
            icon: const Icon(Icons.redo),
          ),
        ],
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _startNewGameFlow,
        icon: const Icon(Icons.add),
        label: const Text('New Game'),
      ),
    ],
  );
}

  Widget _buildStatusBanner(
    BuildContext context,
    GameStatus status,
    PieceColor turnToMove,
  ) {
    final theme = Theme.of(context);
    final (message, isProminent) = _hasResigned
        ? (
            '${_resignedColor!.displayName} resigned — '
                '${_resignedColor!.opposite.displayName} wins',
            true,
          )
        : switch (status) {
            GameStatus.checkmate => (
                'Checkmate — ${turnToMove.opposite.displayName} wins',
                true
              ),
            GameStatus.stalemate => ('Stalemate — Draw', true),
            GameStatus.insufficientMaterial => (
                'Draw — Insufficient material',
                true
              ),
            GameStatus.fiftyMoveRule => ('Draw — Fifty-move rule', true),
            GameStatus.threefoldRepetition => (
                'Draw — Threefold repetition',
                true
              ),
            GameStatus.check => (
                '${turnToMove.displayName} is in check',
                false
              ),
            GameStatus.active => ('${turnToMove.displayName} to move', false),
          };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isProminent
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: theme.textTheme.titleMedium?.copyWith(
          color: isProminent ? theme.colorScheme.onPrimaryContainer : null,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// One of the two side-by-side color choice buttons shown by
/// [_GameScreenState._promptForColorChoice] -- a solid-colored box
/// with its label rendered in a contrasting color, so "White" reads in
/// white text and "Black" reads in black text as specified.
class _ColorChoiceButton extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onTap;

  const _ColorChoiceButton({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
