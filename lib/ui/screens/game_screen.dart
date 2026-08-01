import 'package:flutter/material.dart';
import 'package:chess_app/engine/chess_engine.dart';
import 'package:chess_app/engine/move_classifier.dart';
import 'package:chess_app/engine/simple_engine.dart';
import 'package:chess_app/game_logic/game_controller.dart';
import 'package:chess_app/game_logic/game_save_service.dart';
import 'package:chess_app/models/enums.dart';
import 'package:chess_app/models/move.dart';
import 'package:chess_app/ui/widgets/chess_board_widget.dart';
import 'package:chess_app/ui/widgets/game_controls_bar.dart';
import 'package:chess_app/ui/widgets/move_history_panel.dart';
import 'package:chess_app/utils/constants.dart';
import 'package:chess_app/utils/extensions.dart';

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

  /// Quality classification for the human player's own moves, keyed by
  /// that move's index in the controller's move history. Computed
  /// asynchronously right after each human move so it never delays
  /// that move's own board update.
  final Map<int, MoveQuality> _moveQualities = {};

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onGameStateChanged);
    // Ask which color to play as before the very first game, same as
    // every subsequent "New Game" -- deferred to after the first frame
    // so the dialog's context is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startNewGameFlow());
  }

  @override
  void dispose() {
    _controller.removeListener(_onGameStateChanged);
    super.dispose();
  }

  void _onGameStateChanged() {
    final state = _controller.state;

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
                    textColor: Colors.black,
                    onTap: () =>
                        Navigator.of(dialogContext).pop(PieceColor.white),
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
  /// or start a new game immediately.
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
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child:
                          const Text('Review', style: TextStyle(fontSize: 13)),
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

    if (!mounted) return;
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
            child: ChessBoardWidget(
              controller: _controller,
              humanColor: _humanColor,
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
            child: ChessBoardWidget(
              controller: _controller,
              humanColor: _humanColor,
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

  Widget _buildSidePanel(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final state = _controller.state;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusBanner(context, state.status, state.turnToMove),
            if (state.isGameOver) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _startNewGameFlow,
                icon: const Icon(Icons.add),
                label: const Text('New Game'),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: MoveHistoryPanel(
                moves: _controller.moveHistory,
                moveQualities: _moveQualities,
              ),
            ),
            const SizedBox(height: 12),
            GameControlsBar(
              onUndo: _onUndo,
              onRestart: _startNewGameFlow,
              canUndo: _controller.canUndo && !_computerIsThinking,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusBanner(
    BuildContext context,
    GameStatus status,
    PieceColor turnToMove,
  ) {
    final theme = Theme.of(context);
    final (message, isProminent) = switch (status) {
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
      GameStatus.check => ('${turnToMove.displayName} is in check', false),
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
