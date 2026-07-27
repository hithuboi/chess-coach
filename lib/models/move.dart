import 'package:chess_app/models/enums.dart';
import 'package:chess_app/models/piece.dart';
import 'package:chess_app/models/position.dart';

/// An immutable record of a single move made in the game.
class Move {
  /// Square the piece moved from.
  final Position from;

  /// Square the piece moved to.
  final Position to;

  /// The piece that moved (its state *before* the move).
  final Piece piece;

  /// The piece captured by this move, if any.
  final Piece? capturedPiece;

  /// For en passant captures, the square the captured pawn actually
  /// stood on (different from [to]). Null for all other moves.
  final Position? enPassantCapturedSquare;

  /// Special-case classification of this move. See [MoveFlag].
  final MoveFlag flag;

  /// If this move is a promotion, the piece type the pawn becomes.
  final PieceType? promotesTo;

  /// True if this move puts the opposing king in check.
  final bool isCheck;

  /// True if this move is checkmate.
  final bool isCheckmate;

  const Move({
    required this.from,
    required this.to,
    required this.piece,
    this.capturedPiece,
    this.enPassantCapturedSquare,
    this.flag = MoveFlag.normal,
    this.promotesTo,
    this.isCheck = false,
    this.isCheckmate = false,
  });

  /// Whether this move is a castling move (either side).
  bool get isCastling =>
      flag == MoveFlag.castleKingside || flag == MoveFlag.castleQueenside;

  /// Whether this move captures any piece (direct or en passant).
  bool get isCapture =>
      capturedPiece != null ||
      flag == MoveFlag.capture ||
      flag == MoveFlag.enPassant ||
      flag == MoveFlag.promotionCapture;

  /// Returns a copy of this move with check/checkmate flags updated.
  Move copyWith({bool? isCheck, bool? isCheckmate}) {
    return Move(
      from: from,
      to: to,
      piece: piece,
      capturedPiece: capturedPiece,
      enPassantCapturedSquare: enPassantCapturedSquare,
      flag: flag,
      promotesTo: promotesTo,
      isCheck: isCheck ?? this.isCheck,
      isCheckmate: isCheckmate ?? this.isCheckmate,
    );
  }

  /// Renders this move in Standard Algebraic Notation (SAN), e.g.
  /// "e4", "Nf3", "O-O", "exd5", "e8=Q+".
  ///
  /// v0.1 note: does not yet disambiguate two identical pieces that
  /// could both move to the same square (e.g. "Nbd7" vs "Nfd7").
  String toSan() {
    if (isCastling) {
      final base = flag == MoveFlag.castleKingside ? 'O-O' : 'O-O-O';
      return _withCheckSuffix(base);
    }

    final pieceLetter = _pieceLetterForSan(piece.type);
    final captureMarker = isCapture ? 'x' : '';

    final origin =
        (piece.type == PieceType.pawn && isCapture) ? from.algebraic[0] : '';

    var san = '$pieceLetter$origin$captureMarker${to.algebraic}';

    if (promotesTo != null) {
      san += '=${_pieceLetterForSan(promotesTo!)}';
    }

    return _withCheckSuffix(san);
  }

  String _withCheckSuffix(String san) {
    if (isCheckmate) return '$san#';
    if (isCheck) return '$san+';
    return san;
  }

  String _pieceLetterForSan(PieceType type) => switch (type) {
        PieceType.pawn => '',
        PieceType.knight => 'N',
        PieceType.bishop => 'B',
        PieceType.rook => 'R',
        PieceType.queen => 'Q',
        PieceType.king => 'K',
      };

  @override
  String toString() => toSan();
}
