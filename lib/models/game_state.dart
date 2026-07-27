import 'package:chess_app/models/enums.dart';
import 'package:chess_app/models/move.dart';
import 'package:chess_app/models/piece.dart';
import 'package:chess_app/models/position.dart';

/// An immutable snapshot of the entire game at one point in time.
class GameState {
  /// Board contents: null means an empty square.
  /// Indexed as `squares[file][rank]`, matching [Position].
  final List<List<Piece?>> squares;

  /// The color whose turn it is to move.
  final PieceColor turnToMove;

  /// Full history of moves made so far, in order.
  final List<Move> moveHistory;

  /// The current status of the game (active, check, checkmate, etc.).
  final GameStatus status;

  /// If the previous move was a pawn double-step, this is the square
  /// "behind" that pawn that can be targeted by an en passant capture
  /// on the *next* move only. Null if en passant is not available.
  final Position? enPassantTarget;

  /// Number of half-moves (plies) since the last pawn move or capture.
  final int halfMoveClock;

  /// Full move number, incremented after each black move.
  final int fullMoveNumber;

  const GameState({
    required this.squares,
    required this.turnToMove,
    required this.moveHistory,
    required this.status,
    this.enPassantTarget,
    required this.halfMoveClock,
    required this.fullMoveNumber,
  });

  /// Builds the standard starting position.
  factory GameState.initial() {
    final squares = List.generate(8, (_) => List<Piece?>.filled(8, null));

    const backRank = [
      PieceType.rook,
      PieceType.knight,
      PieceType.bishop,
      PieceType.queen,
      PieceType.king,
      PieceType.bishop,
      PieceType.knight,
      PieceType.rook,
    ];

    for (var file = 0; file < 8; file++) {
      squares[file][0] = Piece(type: backRank[file], color: PieceColor.white);
      squares[file][1] =
          const Piece(type: PieceType.pawn, color: PieceColor.white);
      squares[file][6] =
          const Piece(type: PieceType.pawn, color: PieceColor.black);
      squares[file][7] = Piece(type: backRank[file], color: PieceColor.black);
    }

    return GameState(
      squares: squares,
      turnToMove: PieceColor.white,
      moveHistory: const [],
      status: GameStatus.active,
      enPassantTarget: null,
      halfMoveClock: 0,
      fullMoveNumber: 1,
    );
  }

  /// Returns the piece at [position], or null if the square is empty
  /// or the position is out of bounds.
  Piece? pieceAt(Position position) {
    if (!position.isValid) return null;
    return squares[position.file][position.rank];
  }

  /// Returns a deep copy of the board grid.
  List<List<Piece?>> _copySquares() =>
      List.generate(8, (file) => List<Piece?>.from(squares[file]));

  /// Returns a new [GameState] with the given fields replaced.
  GameState copyWith({
    List<List<Piece?>>? newSquares,
    PieceColor? turnToMove,
    List<Move>? moveHistory,
    GameStatus? status,
    Position? enPassantTarget,
    bool clearEnPassantTarget = false,
    int? halfMoveClock,
    int? fullMoveNumber,
  }) {
    return GameState(
      squares: newSquares ?? _copySquares(),
      turnToMove: turnToMove ?? this.turnToMove,
      moveHistory: moveHistory ?? this.moveHistory,
      status: status ?? this.status,
      enPassantTarget: clearEnPassantTarget
          ? null
          : (enPassantTarget ?? this.enPassantTarget),
      halfMoveClock: halfMoveClock ?? this.halfMoveClock,
      fullMoveNumber: fullMoveNumber ?? this.fullMoveNumber,
    );
  }

  /// Whether the game has ended (checkmate, stalemate, or any draw).
  bool get isGameOver =>
      status == GameStatus.checkmate ||
      status == GameStatus.stalemate ||
      status == GameStatus.insufficientMaterial ||
      status == GameStatus.fiftyMoveRule ||
      status == GameStatus.threefoldRepetition;
}
