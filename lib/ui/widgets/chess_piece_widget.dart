import 'package:flutter/material.dart';
import 'package:chess_app/models/enums.dart';
import 'package:chess_app/models/piece.dart';

/// Renders a single chess piece using a pre-baked, flat-color PNG.
///
/// Deliberately simple: one plain [Image.asset] call, no runtime color
/// filtering, no shaders, no compositing. Each of the 12 piece/color
/// combinations (6 types x 2 colors) is a separate, pre-made asset
/// (assets/pieces/white_king.png, assets/pieces/black_king.png, etc.)
/// baked once offline -- solid white fill with a dark outline for
/// white pieces, solid black fill with a light outline for black
/// pieces, so both are unambiguous at a glance on either square color.
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

  String get _assetPath {
    final colorPrefix = piece.color == PieceColor.white ? 'white' : 'black';
    final typeName = switch (piece.type) {
      PieceType.pawn => 'pawn',
      PieceType.knight => 'knight',
      PieceType.bishop => 'bishop',
      PieceType.rook => 'rook',
      PieceType.queen => 'queen',
      PieceType.king => 'king',
    };
    return 'assets/pieces/${colorPrefix}_$typeName.png';
  }

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
