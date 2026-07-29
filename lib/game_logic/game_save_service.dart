import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:chess_app/models/enums.dart';
import 'package:chess_app/models/move.dart';

/// Writes finished (or in-progress) games to disk as simple, portable
/// JSON save files.
///
/// v0.1 supports saving only -- loading a save back into a
/// [GameController] is a natural, self-contained follow-up: replay
/// each saved move's `from`/`to`/`promotesTo` through the existing
/// move-legality pipeline in order, picking the matching legal move at
/// each step. The format here is intentionally minimal (just enough to
/// replay the game) so that future loader is simple to write.
class GameSaveService {
  const GameSaveService();

  /// The folder all saves live in, created if it doesn't exist yet.
  /// Uses the platform's application-documents directory so saves
  /// persist across app updates and sit in a sensible, user-findable
  /// location on both macOS and iPadOS.
  Future<Directory> savesDirectory() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final savesDir = Directory('${documentsDir.path}/chess_saves');
    if (!await savesDir.exists()) {
      await savesDir.create(recursive: true);
    }
    return savesDir;
  }

  /// Saves [moveHistory] and the game's final [status] to a new,
  /// timestamped JSON file. Returns the full path of the file written.
  Future<String> saveGame({
    required List<Move> moveHistory,
    required GameStatus finalStatus,
  }) async {
    final savesDir = await savesDirectory();
    final now = DateTime.now();
    final stamp = _timestampFor(now);
    final file = File('${savesDir.path}/game_$stamp.json');

    final data = <String, dynamic>{
      'savedAt': now.toIso8601String(),
      'result': finalStatus.name,
      'moves': moveHistory.map(_moveToJson).toList(),
    };

    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    return file.path;
  }

  /// Encodes just enough of a [Move] to replay it later: the origin
  /// and destination squares in algebraic notation, plus the
  /// promotion piece type when relevant. Everything else about the
  /// move (capture, castling, check flags) is re-derived automatically
  /// when it's replayed through the normal move-legality pipeline.
  Map<String, dynamic> _moveToJson(Move move) {
    final json = <String, dynamic>{
      'from': move.from.algebraic,
      'to': move.to.algebraic,
    };
    if (move.promotesTo != null) {
      json['promotesTo'] = move.promotesTo!.name;
    }
    return json;
  }

  String _timestampFor(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)}_'
        '${two(time.hour)}-${two(time.minute)}-${two(time.second)}';
  }
}
