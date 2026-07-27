/// Core enumerations used throughout the chess application.
library;

/// The six standard chess piece types.
enum PieceType {
  pawn,
  knight,
  bishop,
  rook,
  queen,
  king,
}

/// The two sides in a chess game.
enum PieceColor {
  white,
  black;

  /// Returns the opposing color.
  PieceColor get opposite =>
      this == PieceColor.white ? PieceColor.black : PieceColor.white;
}

/// The two sides of the board relevant to castling.
enum CastlingSide {
  kingside,
  queenside,
}

/// High-level status of a game at any point in time.
enum GameStatus {
  active,
  check,
  checkmate,
  stalemate,
  insufficientMaterial,
  fiftyMoveRule,
  threefoldRepetition,
}

/// Special move flags used to distinguish standard moves from moves
/// with side effects (captures, castling, promotion, en passant).
enum MoveFlag {
  normal,
  capture,
  doublePawnPush,
  enPassant,
  castleKingside,
  castleQueenside,
  promotion,
  promotionCapture,
}
