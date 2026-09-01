import 'package:flutter/foundation.dart';

import 'package:chess_app/models/move_analysis.dart';
import 'package:chess_app/engine/move_classifier.dart';

import 'coaching_state.dart';

/// Coordinates the chess coach's response to game events.
///
/// The CoachingEngine sits between move analysis and the UI:
///
///   MoveClassifier → CoachingEngine → Coach UI
///
/// MoveClassifier determines what happened.
/// CoachingEngine determines what the coach should do about it.
class CoachingEngine extends ChangeNotifier {
  CoachingState _state = CoachingState.idle;

  /// The coach's current state.
  CoachingState get state => _state;

  MoveAnalysis? _currentAnalysis;

  /// Analysis of the most recent move being considered by the coach.
  MoveAnalysis? get currentAnalysis => _currentAnalysis;

  /// Gives the coach a newly analyzed move to observe.
  void observeMove(MoveAnalysis analysis) {
    _currentAnalysis = analysis;

    // Decide whether the latest move requires the coach to intervene.
    switch (analysis.quality) {
      case MoveQuality.excellent:
      case MoveQuality.good:
        _state = CoachingState.observing;
        break;

      case MoveQuality.mistake:
      case MoveQuality.blunder:
        _state = CoachingState.mistakeDetected;
        break;
    }

    // Temporary verification: confirm that the coach receives each move analysis.
    debugPrint(
      'Coach received an analysis '
      '| Quality: ${analysis.quality} '
      '| CPL: ${analysis.centipawnLoss} '
      '| Best move: ${analysis.bestMove}',
    );

    notifyListeners();
  }
}