import 'package:flutter/material.dart';
import 'package:chess_app/engine/chess_engine.dart';
import 'package:chess_app/engine/simple_engine.dart';
import 'package:chess_app/game_logic/game_controller.dart';
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

  /// v0.1 fixes the human as White and the computer as Black.
  static const PieceColor _humanColor = PieceColor.white;
  static const PieceColor _computerColor = PieceColor.black;

  /// True while the computer is "thinking".
  bool _computerIsThinking = false;

  /// True once the end-of-game dialog has been shown for the current
  /// game, so it doesn't reappear on every subsequent rebuild while
  /// the finished position is still on screen.
  bool _hasShownGameOverDialog = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onGameStateChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onGameStateChanged);
    super.dispose();
  }

  void _onGameStateChanged() {
    final state = _controller.state;

    if (state.isGameOver) {
      if (!_hasShownGameOverDialog) {
        _hasShownGameOverDialog = true;
        // Defer to after this frame so the final move's board update
        // (and check-highlight) is visible underneath the dialog
        // rather than the dialog racing ahead of the last repaint.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showGameOverDialog(state.status, state.turnToMove);
        });
      }
      return;
    }

    if (state.turnToMove == _computerColor && !_computerIsThinking) {
      _triggerComputerMove();
    }
  }

  /// Shows a modal summarizing how the game ended, with a prominent
  /// "New Game" action so the next step is always obvious — rather
  /// than relying on the player to notice the small status banner and
  /// find the Restart button themselves.
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
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Review Board'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _onRestart();
            },
            child: const Text('New Game'),
          ),
        ],
      ),
    );
  }

  /// Minimum time the computer's move is held before being applied to
  /// the board, regardless of how fast it was actually calculated.
  /// This is purely a pacing delay for the human player's benefit —
  /// it gives them a moment to register the board *before* their own
  /// move, and it means the opponent's reply never feels instantaneous
  /// even when [SimpleEngine] resolves in a few milliseconds. The
  /// human's own moves are never delayed by this — only the bot's.
  static const Duration _minimumBotMoveDelay = Duration(milliseconds: 400);

  Future<void> _triggerComputerMove() async {
    setState(() => _computerIsThinking = true);

    final state = _controller.state;

    // Run the actual engine search and the minimum-delay timer at the
    // same time, then wait for whichever finishes last. A fast engine
    // response still waits out the full 400ms; a slow engine response
    // is never held up any further than it already takes. Both
    // futures are explicitly typed as Future<Move?> (the delay future
    // just resolves to null) so they combine cleanly in one list.
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

  void _onUndo() {
    // Undo twice so it's always the human's turn again afterward.
    _controller.undo();
    if (_controller.state.turnToMove == _computerColor &&
        _controller.canUndo) {
      _controller.undo();
    }
  }

  void _onRestart() {
    setState(() {
      _computerIsThinking = false;
      _hasShownGameOverDialog = false;
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
            const SizedBox(height: 12),
            Expanded(
              child: MoveHistoryPanel(moves: _controller.moveHistory),
            ),
            const SizedBox(height: 12),
            GameControlsBar(
              onUndo: _onUndo,
              onRestart: _onRestart,
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
