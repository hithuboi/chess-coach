import 'package:flutter/material.dart';

/// App-wide constants that don't belong to any single layer.

/// Number of files (columns) and ranks (rows) on a standard board.
const int boardSize = 8;

/// Standard starting position in Forsyth-Edwards Notation (FEN).
/// Not yet used in v0.1, kept as a reference point for a future
/// "Saved Games" feature.
const String startingPositionFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// Duration used for animations throughout the UI.
const Duration uiAnimationDuration = Duration(milliseconds: 200);

/// Default search depth for [SimpleEngine] when no explicit depth is
/// provided.
const int defaultEngineSearchDepth = 3;

/// Minimum comfortable square size, in logical pixels.
const double minComfortableSquareSize = 44.0;

/// Breakpoint, in logical pixels of available width, above which the
/// move history panel is shown alongside the board rather than stacked.
const double wideLayoutBreakpoint = 900.0;

/// Standard padding used around the board and side panel.
const EdgeInsets standardPagePadding = EdgeInsets.all(16.0);
