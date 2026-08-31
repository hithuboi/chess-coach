import 'package:chess_app/engine/move_classifier.dart';
import 'package:chess_app/models/move.dart';

class MoveAnalysis {
  final Move move;
  final MoveQuality quality;

  final int bestScore;
  final int playedScore;
  final int centipawnLoss;

  final Move? bestMove;

  const MoveAnalysis({
    required this.move,
    required this.quality,
    required this.bestScore,
    required this.playedScore,
    required this.centipawnLoss,
    this.bestMove,
  });
}