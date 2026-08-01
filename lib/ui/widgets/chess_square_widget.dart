import 'package:flutter/material.dart';
import 'package:chess_app/models/position.dart';
import 'package:chess_app/ui/theme/app_theme.dart';
import 'package:chess_app/utils/extensions.dart';

/// A single square on the chess board: background color, optional
/// highlight state, coordinate labels, and a tap handler.
class ChessSquareWidget extends StatelessWidget {
  /// This square's board coordinate, used for checkerboard coloring.
  final Position position;

  /// Widget to render on top of the square background.
  final Widget? child;

  /// Whether this square is the currently selected piece's square.
  final bool isSelected;

  /// Whether this square is a legal destination for the selected piece.
  final bool isLegalMoveTarget;

  /// Whether this square holds a king that is currently in check.
  final bool isInCheck;

  /// Whether this square was the origin or destination of the most
  /// recently played move (either side).
  final bool isLastMove;

  /// Rank label (e.g. "1".."8") to draw in this square's top-left
  /// corner, shown only for squares along the board's left screen
  /// edge. Null for every other square.
  final String? rankLabel;

  /// File label (e.g. "a".."h") to draw in this square's bottom-right
  /// corner, shown only for squares along the board's bottom screen
  /// edge. Null for every other square.
  final String? fileLabel;

  /// Called when the user taps this square.
  final VoidCallback? onTap;

  const ChessSquareWidget({
    super.key,
    required this.position,
    this.child,
    this.isSelected = false,
    this.isLegalMoveTarget = false,
    this.isInCheck = false,
    this.isLastMove = false,
    this.rankLabel,
    this.fileLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = position.isLightSquare
        ? AppTheme.lightSquareColor
        : AppTheme.darkSquareColor;

    // Label ink follows the same convention real boards use: it's a
    // subtle tint of the square's *own* base color (darker text on a
    // light square, lighter text on a dark square) rather than a
    // separate accent color, so the coordinates read as printed on
    // the board itself instead of floating on top of it.
    final labelColor = position.isLightSquare
        ? AppTheme.darkSquareColor
        : AppTheme.lightSquareColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: baseColor,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Last-move tint sits at the very bottom of the stack, so
            // it colors the empty parts of the square while the piece
            // (drawn next) remains fully legible on top of it.
            if (isLastMove) _buildLastMoveOverlay(),
            if (child != null) child!,
            if (isInCheck) _buildCheckOverlay(),
            if (isSelected) _buildSelectionOverlay(),
            if (isLegalMoveTarget) _buildLegalMoveMarker(),
            if (rankLabel != null) _buildRankLabel(labelColor),
            if (fileLabel != null) _buildFileLabel(labelColor),
          ],
        ),
      ),
    );
  }

  Widget _buildLastMoveOverlay() {
    return Positioned.fill(
      child: Container(color: AppTheme.lastMoveHighlightColor),
    );
  }

  Widget _buildCheckOverlay() {
    return Positioned.fill(
      child: Container(color: AppTheme.checkHighlightColor),
    );
  }

  Widget _buildSelectionOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: AppTheme.selectedSquareColor,
            width: 3,
          ),
        ),
      ),
    );
  }

  Widget _buildLegalMoveMarker() {
    return Center(
      child: Container(
        width: 18,
        height: 18,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.legalMoveHighlightColor,
        ),
      ),
    );
  }

  Widget _buildRankLabel(Color color) {
    return Positioned(
      top: 2,
      left: 4,
      child: Text(
        rankLabel!,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildFileLabel(Color color) {
    return Positioned(
      bottom: 2,
      right: 4,
      child: Text(
        fileLabel!,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
