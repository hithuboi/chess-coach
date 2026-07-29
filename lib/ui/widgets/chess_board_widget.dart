import 'package:flutter/material.dart';
import 'package:chess_app/game_logic/board.dart';
import 'package:chess_app/game_logic/game_controller.dart';
import 'package:chess_app/models/enums.dart';
import 'package:chess_app/models/move.dart';
import 'package:chess_app/models/position.dart';
import 'package:chess_app/ui/widgets/chess_piece_widget.dart';
import 'package:chess_app/ui/widgets/chess_square_widget.dart';

/// Renders the interactive 8x8 chess board and owns all tap-to-select,
/// tap-to-move interaction logic.
class ChessBoardWidget extends StatefulWidget {
  final GameController controller;

  /// Which color the human player controls.
  final PieceColor humanColor;

  const ChessBoardWidget({
    super.key,
    required this.controller,
    required this.humanColor,
  });

  @override
  State<ChessBoardWidget> createState() => _ChessBoardWidgetState();
}

class _ChessBoardWidgetState extends State<ChessBoardWidget> {
  /// The currently selected square, or null if no piece is selected.
  Position? _selectedSquare;

  /// Legal moves available from [_selectedSquare].
  List<Move> _legalMovesFromSelection = [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_clearStaleSelectionOnNewGame);
  }

  @override
  void didUpdateWidget(covariant ChessBoardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_clearStaleSelectionOnNewGame);
      widget.controller.addListener(_clearStaleSelectionOnNewGame);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_clearStaleSelectionOnNewGame);
    super.dispose();
  }

  /// [_selectedSquare] and [_legalMovesFromSelection] are local UI
  /// state, separate from [GameController] -- so calling `restart()`
  /// resets the board's pieces but does NOT automatically clear a
  /// square the player had selected right before restarting. Without
  /// this, "New Game" could leave a stale selection highlight (and a
  /// stale legal-move list) pointing at a square from the previous
  /// game. Listening for the move history becoming empty is a reliable
  /// signal that a fresh game just started, independent of *how* it
  /// started (Restart button, New Game button, or the end-of-game
  /// dialog's New Game action all funnel through the same reset).
  void _clearStaleSelectionOnNewGame() {
    if (widget.controller.state.moveHistory.isEmpty && _selectedSquare != null) {
      setState(() {
        _selectedSquare = null;
        _legalMovesFromSelection = [];
      });
    }
  }

  void _onSquareTapped(Position tapped) {
    final state = widget.controller.state;

    if (state.turnToMove != widget.humanColor || state.isGameOver) return;

    if (_selectedSquare != null) {
      final matchingMoves =
          _legalMovesFromSelection.where((m) => m.to == tapped).toList();

      if (matchingMoves.isNotEmpty) {
        _playMove(matchingMoves);
        return;
      }

      final tappedPiece = state.pieceAt(tapped);
      if (tappedPiece != null && tappedPiece.color == widget.humanColor) {
        _selectSquare(tapped);
        return;
      }

      setState(() {
        _selectedSquare = null;
        _legalMovesFromSelection = [];
      });
      return;
    }

    final piece = state.pieceAt(tapped);
    if (piece != null && piece.color == widget.humanColor) {
      _selectSquare(tapped);
    }
  }

  void _selectSquare(Position square) {
    setState(() {
      _selectedSquare = square;
      _legalMovesFromSelection = widget.controller.legalMovesFrom(square);
    });
  }

  /// Plays the chosen move. Prompts for a promotion piece if multiple
  /// candidate moves share the same destination square.
  Future<void> _playMove(List<Move> candidates) async {
    Move moveToPlay;

    if (candidates.length > 1) {
      final chosen = await _showPromotionDialog(candidates);
      if (chosen == null) return;
      moveToPlay = chosen;
    } else {
      moveToPlay = candidates.first;
    }

    widget.controller.makeMove(moveToPlay);
    setState(() {
      _selectedSquare = null;
      _legalMovesFromSelection = [];
    });
  }

  Future<Move?> _showPromotionDialog(List<Move> promotionMoves) {
    return showDialog<Move>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('Promote pawn to'),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: promotionMoves.map((move) {
            return IconButton(
              iconSize: 40,
              tooltip: move.promotesTo?.name,
              onPressed: () => Navigator.of(context).pop(move),
              icon: Text(
                _promotionGlyph(move),
                style: const TextStyle(fontSize: 32),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _promotionGlyph(Move move) {
    final color = move.piece.color;
    return switch ((move.promotesTo, color)) {
      (PieceType.queen, PieceColor.white) => '♕',
      (PieceType.rook, PieceColor.white) => '♖',
      (PieceType.bishop, PieceColor.white) => '♗',
      (PieceType.knight, PieceColor.white) => '♘',
      (PieceType.queen, PieceColor.black) => '♛',
      (PieceType.rook, PieceColor.black) => '♜',
      (PieceType.bishop, PieceColor.black) => '♝',
      (PieceType.knight, PieceColor.black) => '♞',
      _ => '?',
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;

        Position? checkedKingSquare;
        if (state.status == GameStatus.check ||
            state.status == GameStatus.checkmate) {
          checkedKingSquare = Board.findKing(state, state.turnToMove);
        }

        // The origin and destination of the most recently played move
        // (either side), highlighted so the player can see at a
        // glance what just changed -- null before any move is made.
        final lastMove =
            state.moveHistory.isNotEmpty ? state.moveHistory.last : null;

        return LayoutBuilder(
          builder: (context, constraints) {
            final boardSize = constraints.maxWidth < constraints.maxHeight
                ? constraints.maxWidth
                : constraints.maxHeight;
            final squareSize = boardSize / 8;

            return SizedBox(
              width: boardSize,
              height: boardSize,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(8, (displayRow) {
                  final rank = 7 - displayRow;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(8, (file) {
                      final position = Position(file, rank);
                      final piece = state.pieceAt(position);

                      return SizedBox(
                        width: squareSize,
                        height: squareSize,
                        child: ChessSquareWidget(
                          position: position,
                          isSelected: _selectedSquare == position,
                          isLegalMoveTarget: _legalMovesFromSelection
                              .any((m) => m.to == position),
                          isInCheck: checkedKingSquare == position,
                          isLastMove: lastMove != null &&
                              (lastMove.from == position ||
                                  lastMove.to == position),
                          onTap: () => _onSquareTapped(position),
                          child: piece != null
                              ? ChessPieceWidget(
                                  piece: piece,
                                  size: squareSize * 0.7,
                                )
                              : null,
                        ),
                      );
                    }),
                  );
                }),
              ),
            );
          },
        );
      },
    );
  }
}
