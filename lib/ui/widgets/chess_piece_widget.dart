import 'package:flutter/material.dart';
import 'package:chess_app/models/enums.dart';
import 'package:chess_app/models/piece.dart';

/// Renders a single chess piece using the licensed line-art piece set
/// (assets/pieces/*.png).
///
/// Each asset is a single-color silhouette with a transparent
/// background -- one file per piece type, shared by both colors. The
/// actual white/black rendering is done here via [ColorFiltered]
/// tinting rather than shipping two separate colored image sets: this
/// halves the asset count and guarantees white and black pieces are
/// pixel-identical in shape, differing only in color.
///
/// A second, slightly larger copy of the same asset is drawn behind
/// the tinted piece in a contrasting color to create a thin outline --
/// this keeps white pieces legible on light squares and black pieces
/// legible on dark squares, the same problem that motivated moving off
/// plain Unicode glyphs in the first place.
class ChessPieceWidget extends StatelessWidget {
  final Piece piece;

  /// Size (width and height) this piece should render at, derived from
  /// the current square size so pieces scale responsively.
  final double size;

  const ChessPieceWidget({
    super.key,
    required this.piece,
    required this.size,
  });

  /// Maps this piece's type to its shared asset file. Both colors of
  /// the same piece type use the same underlying image.
  String get _assetPath {
    final name = switch (piece.type) {
      PieceType.pawn => 'pawn',
      PieceType.knight => 'knight',
      PieceType.bishop => 'bishop',
      PieceType.rook => 'rook',
      PieceType.queen => 'queen',
      PieceType.king => 'king',
    };
    return 'assets/pieces/$name.png';
  }

  @override
  Widget build(BuildContext context) {
    final isWhite = piece.color == PieceColor.white;
    final fillColor =
        isWhite ? const Color(0xFFF8F4EC) : const Color(0xFF2B2A27);
    final outlineColor = isWhite ? Colors.black87 : Colors.white70;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outline halo: same silhouette, slightly enlarged, tinted
          // with a contrasting color so it peeks out from behind the
          // main fill and reads as a thin border.
          Transform.scale(
            scale: 1.06,
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(outlineColor, BlendMode.srcIn),
              child: Image.asset(
                _assetPath,
                width: size,
                height: size,
                fit: BoxFit.contain,
              ),
            ),
          ),
          // Main fill, drawn on top at the true size.
          ColorFiltered(
            colorFilter: ColorFilter.mode(fillColor, BlendMode.srcIn),
            child: Image.asset(
              _assetPath,
              width: size,
              height: size,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}
