import 'package:chess_app/models/enums.dart';

/// Represents a single chess piece: its type, color, and movement history.
class Piece {
  final PieceType type;
  final PieceColor color;

  /// Whether this piece has moved at least once during the game.
  final bool hasMoved;

  const Piece({
    required this.type,
    required this.color,
    this.hasMoved = false,
  });

  /// Returns a copy of this piece with the given fields replaced.
  Piece copyWith({
    PieceType? type,
    PieceColor? color,
    bool? hasMoved,
  }) {
    return Piece(
      type: type ?? this.type,
      color: color ?? this.color,
      hasMoved: hasMoved ?? this.hasMoved,
    );
  }

  /// Single-character symbol used for lightweight text rendering/debugging.
  String get symbol {
    final letter = switch (type) {
      PieceType.pawn => 'p',
      PieceType.knight => 'n',
      PieceType.bishop => 'b',
      PieceType.rook => 'r',
      PieceType.queen => 'q',
      PieceType.king => 'k',
    };
    return color == PieceColor.white ? letter.toUpperCase() : letter;
  }

  /// Unicode chess glyph for this piece, used by the UI to render
  /// pieces without needing image assets.
  String get unicodeSymbol {
    return switch ((type, color)) {
      (PieceType.king, PieceColor.white) => '♔',
      (PieceType.queen, PieceColor.white) => '♕',
      (PieceType.rook, PieceColor.white) => '♖',
      (PieceType.bishop, PieceColor.white) => '♗',
      (PieceType.knight, PieceColor.white) => '♘',
      (PieceType.pawn, PieceColor.white) => '♙',
      (PieceType.king, PieceColor.black) => '♚',
      (PieceType.queen, PieceColor.black) => '♛',
      (PieceType.rook, PieceColor.black) => '♜',
      (PieceType.bishop, PieceColor.black) => '♝',
      (PieceType.knight, PieceColor.black) => '♞',
      (PieceType.pawn, PieceColor.black) => '♟',
    };
  }

  /// Standard material value in pawns.
  int get materialValue => switch (type) {
        PieceType.pawn => 1,
        PieceType.knight => 3,
        PieceType.bishop => 3,
        PieceType.rook => 5,
        PieceType.queen => 9,
        PieceType.king => 0,
      };

  @override
  bool operator ==(Object other) =>
      other is Piece &&
      other.type == type &&
      other.color == color &&
      other.hasMoved == hasMoved;

  @override
  int get hashCode => Object.hash(type, color, hasMoved);

  @override
  String toString() => symbol;
}
