# Chess (v0.5.1)

A cross-platform chess application built with Flutter, targeting **macOS**
and **iPadOS** as the primary platforms for this release. The codebase is
plain Dart/Flutter with no platform-specific code, so it also builds for
iOS, Android, Windows, Linux, and web with minimal extra setup.

## Features Added (v0.5.1)

- Fixed threefold repetition detection by ensuring the latest move is
  included in the move history before checking the resulting game status.

## Features Added (v0.5.0)

- Added a Coaching Engine to process move analysis and determine when
  coaching intervention is required.
- Connected the Coaching Engine to the Game Controller.
- Added move-quality analysis data to the coaching pipeline, including
  move quality, centipawn loss, and best-move information.
- Added coaching states for observing moves and detecting mistakes or
  blunders.
- Added initial mistake categorisation for coaching, including:
  - Hanging piece
  - Missed capture
  - Missed check
  - Repeated queen moves

## Features Added (v0.4.1)

- Revamped New Game functionality with an added Resign button.
- Added Review Game functionality, enabling the user to review all moves
  from the starting move of the game through to the ending move.

## Features Added (v0.4.0)

- Fixed the buggy Undo button.
- Implemented board coordinate labels (a to h and 1 to 8).

## Features Added (v0.3.0)

- Added piece colour selection, allowing the user to play as either White
  or Black.
- Added move classification, categorising moves as:
  - Excellent
  - Good
  - Mistake
  - Blunder

## Bug Fixes (v0.2.1)

- Fixed the buggy New Game button.

## Features Added (v0.2.0)

- Added the ability to save completed games.
- Added the ability to review the board upon completion.

## Features (v0.1.0)

- Human vs. Computer play.
- Standard chess rules, including castling, en passant, and promotion.
- Full legal move validation (no illegal moves possible, by either side).
- Move highlighting:
  - Selected square
  - Legal destinations
  - King in check
- Undo (steps back to the human player's previous turn).
- Restart with confirmation.
- Move history panel in standard algebraic notation.
- Clean Material 3 interface with light/dark mode following system
  appearance.

## Getting Started

```bash
flutter pub get

# Run on macOS
flutter run -d macos

# Run on an iPad simulator or connected device
flutter run -d ios
