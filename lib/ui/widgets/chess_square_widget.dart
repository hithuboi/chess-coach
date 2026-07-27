import 'package:flutter/material.dart';
import 'package:chess_app/models/position.dart';
import 'package:chess_app/ui/theme/app_theme.dart';
import 'package:chess_app/utils/extensions.dart';

/// A single square on the chess board: background color, optional
/// highlight state, and a tap handler.
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

  /// Called when the user taps this square.
  final VoidCallback? onTap;

  const ChessSquareWidget({
    super.key,
    required this.position,
    this.child,
    this.isSelected = false,
    this.isLegalMoveTarget = false,
    this.isInCheck = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = position.isLightSquare
        ? AppTheme.lightSquareColor
        : AppTheme.darkSquareColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: baseColor,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (child != null) child!,
            if (isInCheck) _buildCheckOverlay(),
            if (isSelected) _buildSelectionOverlay(),
            if (isLegalMoveTarget) _buildLegalMoveMarker(),
          ],
        ),
      ),
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
}
