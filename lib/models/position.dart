/// An immutable coordinate on the chess board.
///
/// Internally stored as zero-indexed `file` (column, a-h => 0-7) and
/// `rank` (row, 1-8 => 0-7).
class Position {
  /// Column index, 0-7, corresponding to files a-h.
  final int file;

  /// Row index, 0-7, corresponding to ranks 1-8.
  final int rank;

  const Position(this.file, this.rank);

  /// Parses standard algebraic notation (e.g. "e4") into a [Position].
  factory Position.fromAlgebraic(String square) {
    if (square.length != 2) {
      throw FormatException('Invalid square notation: $square');
    }
    final fileChar = square[0].toLowerCase();
    final rankChar = square[1];

    final file = fileChar.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.tryParse(rankChar);

    if (file < 0 || file > 7 || rank == null || rank < 1 || rank > 8) {
      throw FormatException('Invalid square notation: $square');
    }

    return Position(file, rank - 1);
  }

  /// Whether this position falls within the bounds of an 8x8 board.
  bool get isValid => file >= 0 && file < 8 && rank >= 0 && rank < 8;

  /// Returns a new position offset by [fileDelta] and [rankDelta].
  Position offset(int fileDelta, int rankDelta) =>
      Position(file + fileDelta, rank + rankDelta);

  /// Converts back to standard algebraic notation (e.g. "e4").
  String get algebraic {
    final fileChar = String.fromCharCode('a'.codeUnitAt(0) + file);
    final rankChar = (rank + 1).toString();
    return '$fileChar$rankChar';
  }

  @override
  bool operator ==(Object other) =>
      other is Position && other.file == file && other.rank == rank;

  @override
  int get hashCode => file * 8 + rank;

  @override
  String toString() => algebraic;
}
