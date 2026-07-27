import 'package:chess_app/game_logic/board.dart';
import 'package:chess_app/models/enums.dart';
import 'package:chess_app/models/game_state.dart';
import 'package:chess_app/models/move.dart';
import 'package:chess_app/models/piece.dart';
import 'package:chess_app/models/position.dart';

/// Generates *pseudo-legal* moves: moves that follow each piece's
/// movement pattern and respect occupied squares, but do NOT yet check
/// whether making the move would leave the mover's own king in check.
class MoveGenerator {
  const MoveGenerator._();

  static const _diagonalDirections = [
    (1, 1), (1, -1), (-1, 1), (-1, -1),
  ];

  static const _orthogonalDirections = [
    (1, 0), (-1, 0), (0, 1), (0, -1),
  ];

  static const _knightOffsets = [
    (1, 2), (2, 1), (2, -1), (1, -2),
    (-1, -2), (-2, -1), (-2, 1), (-1, 2),
  ];

  /// Generates all pseudo-legal moves for every piece belonging to [color].
  static List<Move> allPseudoLegalMoves(GameState state, PieceColor color) {
    final moves = <Move>[];
    for (final position in Board.squaresOccupiedBy(state, color)) {
      moves.addAll(pseudoLegalMovesFrom(state, position));
    }
    return moves;
  }

  /// Generates all pseudo-legal moves for the single piece standing on [from].
  static List<Move> pseudoLegalMovesFrom(GameState state, Position from) {
    final piece = state.pieceAt(from);
    if (piece == null) return [];

    return switch (piece.type) {
      PieceType.pawn => _pawnMoves(state, from, piece),
      PieceType.knight => _knightMoves(state, from, piece),
      PieceType.bishop =>
        _slidingMoves(state, from, piece, _diagonalDirections),
      PieceType.rook =>
        _slidingMoves(state, from, piece, _orthogonalDirections),
      PieceType.queen => _slidingMoves(
          state, from, piece, [..._diagonalDirections, ..._orthogonalDirections]),
      PieceType.king => _kingMoves(state, from, piece),
    };
  }

  /// Returns every square attacked by [color] in the current [state].
  static Set<Position> attackedSquares(GameState state, PieceColor color) {
    final attacked = <Position>{};
    for (final from in Board.squaresOccupiedBy(state, color)) {
      final piece = state.pieceAt(from)!;
      switch (piece.type) {
        case PieceType.pawn:
          final direction = piece.color == PieceColor.white ? 1 : -1;
          for (final fileDelta in [-1, 1]) {
            final target = from.offset(fileDelta, direction);
            if (target.isValid) attacked.add(target);
          }
        case PieceType.knight:
          for (final (df, dr) in _knightOffsets) {
            final target = from.offset(df, dr);
            if (target.isValid) attacked.add(target);
          }
        case PieceType.king:
          for (final df in [-1, 0, 1]) {
            for (final dr in [-1, 0, 1]) {
              if (df == 0 && dr == 0) continue;
              final target = from.offset(df, dr);
              if (target.isValid) attacked.add(target);
            }
          }
        case PieceType.bishop:
          attacked.addAll(_slidingAttacks(state, from, _diagonalDirections));
        case PieceType.rook:
          attacked.addAll(_slidingAttacks(state, from, _orthogonalDirections));
        case PieceType.queen:
          attacked.addAll(_slidingAttacks(
              state, from, [..._diagonalDirections, ..._orthogonalDirections]));
      }
    }
    return attacked;
  }

  // ---------------------------------------------------------------------
  // Pawn moves
  // ---------------------------------------------------------------------

  static List<Move> _pawnMoves(GameState state, Position from, Piece piece) {
    final moves = <Move>[];
    final direction = piece.color == PieceColor.white ? 1 : -1;
    final startRank = piece.color == PieceColor.white ? 1 : 6;
    final promotionRank = piece.color == PieceColor.white ? 7 : 0;

    final oneStep = from.offset(0, direction);
    if (oneStep.isValid && Board.isEmpty(state, oneStep)) {
      _addPawnMoveOrPromotion(moves, from, oneStep, piece, promotionRank);

      if (from.rank == startRank) {
        final twoStep = from.offset(0, direction * 2);
        if (twoStep.isValid && Board.isEmpty(state, twoStep)) {
          moves.add(Move(
            from: from,
            to: twoStep,
            piece: piece,
            flag: MoveFlag.doublePawnPush,
          ));
        }
      }
    }

    for (final fileDelta in [-1, 1]) {
      final target = from.offset(fileDelta, direction);
      if (!target.isValid) continue;

      if (Board.isOccupiedByOpponent(state, target, piece.color)) {
        _addPawnMoveOrPromotion(
          moves, from, target, piece, promotionRank,
          capturedPiece: state.pieceAt(target),
        );
      } else if (target == state.enPassantTarget) {
        final capturedPawnSquare = Position(target.file, from.rank);
        moves.add(Move(
          from: from,
          to: target,
          piece: piece,
          capturedPiece: state.pieceAt(capturedPawnSquare),
          enPassantCapturedSquare: capturedPawnSquare,
          flag: MoveFlag.enPassant,
        ));
      }
    }

    return moves;
  }

  static void _addPawnMoveOrPromotion(
    List<Move> moves,
    Position from,
    Position to,
    Piece piece,
    int promotionRank, {
    Piece? capturedPiece,
  }) {
    final isPromotion = to.rank == promotionRank;

    if (!isPromotion) {
      moves.add(Move(
        from: from,
        to: to,
        piece: piece,
        capturedPiece: capturedPiece,
        flag: capturedPiece != null ? MoveFlag.capture : MoveFlag.normal,
      ));
      return;
    }

    const promotionOptions = [
      PieceType.queen,
      PieceType.rook,
      PieceType.bishop,
      PieceType.knight,
    ];
    for (final promotesTo in promotionOptions) {
      moves.add(Move(
        from: from,
        to: to,
        piece: piece,
        capturedPiece: capturedPiece,
        flag: capturedPiece != null
            ? MoveFlag.promotionCapture
            : MoveFlag.promotion,
        promotesTo: promotesTo,
      ));
    }
  }

  // ---------------------------------------------------------------------
  // Knight moves
  // ---------------------------------------------------------------------

  static List<Move> _knightMoves(GameState state, Position from, Piece piece) {
    final moves = <Move>[];
    for (final (df, dr) in _knightOffsets) {
      final target = from.offset(df, dr);
      if (!target.isValid) continue;
      if (Board.isOccupiedByColor(state, target, piece.color)) continue;

      final capturedPiece = state.pieceAt(target);
      moves.add(Move(
        from: from,
        to: target,
        piece: piece,
        capturedPiece: capturedPiece,
        flag: capturedPiece != null ? MoveFlag.capture : MoveFlag.normal,
      ));
    }
    return moves;
  }

  // ---------------------------------------------------------------------
  // Sliding moves (bishop, rook, queen)
  // ---------------------------------------------------------------------

  static List<Move> _slidingMoves(
    GameState state,
    Position from,
    Piece piece,
    List<(int, int)> directions,
  ) {
    final moves = <Move>[];
    for (final (df, dr) in directions) {
      var target = from.offset(df, dr);
      while (target.isValid) {
        if (Board.isOccupiedByColor(state, target, piece.color)) break;

        final capturedPiece = state.pieceAt(target);
        moves.add(Move(
          from: from,
          to: target,
          piece: piece,
          capturedPiece: capturedPiece,
          flag: capturedPiece != null ? MoveFlag.capture : MoveFlag.normal,
        ));

        if (capturedPiece != null) break;
        target = target.offset(df, dr);
      }
    }
    return moves;
  }

  static Set<Position> _slidingAttacks(
    GameState state,
    Position from,
    List<(int, int)> directions,
  ) {
    final attacked = <Position>{};
    for (final (df, dr) in directions) {
      var target = from.offset(df, dr);
      while (target.isValid) {
        attacked.add(target);
        if (!Board.isEmpty(state, target)) break;
        target = target.offset(df, dr);
      }
    }
    return attacked;
  }

  // ---------------------------------------------------------------------
  // King moves (including castling)
  // ---------------------------------------------------------------------

  static List<Move> _kingMoves(GameState state, Position from, Piece piece) {
    final moves = <Move>[];

    for (final df in [-1, 0, 1]) {
      for (final dr in [-1, 0, 1]) {
        if (df == 0 && dr == 0) continue;
        final target = from.offset(df, dr);
        if (!target.isValid) continue;
        if (Board.isOccupiedByColor(state, target, piece.color)) continue;

        final capturedPiece = state.pieceAt(target);
        moves.add(Move(
          from: from,
          to: target,
          piece: piece,
          capturedPiece: capturedPiece,
          flag: capturedPiece != null ? MoveFlag.capture : MoveFlag.normal,
        ));
      }
    }

    moves.addAll(_castlingMoves(state, from, piece));
    return moves;
  }

  static List<Move> _castlingMoves(GameState state, Position from, Piece king) {
    final moves = <Move>[];
    if (king.hasMoved) return moves;

    final rank = king.color == PieceColor.white ? 0 : 7;
    if (from.rank != rank || from.file != 4) return moves;

    final opponentAttacks = attackedSquares(state, king.color.opposite);
    if (opponentAttacks.contains(from)) return moves;

    final kingsideRook = state.pieceAt(Position(7, rank));
    if (kingsideRook != null &&
        kingsideRook.type == PieceType.rook &&
        !kingsideRook.hasMoved &&
        Board.isEmpty(state, Position(5, rank)) &&
        Board.isEmpty(state, Position(6, rank)) &&
        !opponentAttacks.contains(Position(5, rank)) &&
        !opponentAttacks.contains(Position(6, rank))) {
      moves.add(Move(
        from: from,
        to: Position(6, rank),
        piece: king,
        flag: MoveFlag.castleKingside,
      ));
    }

    final queensideRook = state.pieceAt(Position(0, rank));
    if (queensideRook != null &&
        queensideRook.type == PieceType.rook &&
        !queensideRook.hasMoved &&
        Board.isEmpty(state, Position(1, rank)) &&
        Board.isEmpty(state, Position(2, rank)) &&
        Board.isEmpty(state, Position(3, rank)) &&
        !opponentAttacks.contains(Position(3, rank)) &&
        !opponentAttacks.contains(Position(2, rank))) {
      moves.add(Move(
        from: from,
        to: Position(2, rank),
        piece: king,
        flag: MoveFlag.castleQueenside,
      ));
    }

    return moves;
  }
}
