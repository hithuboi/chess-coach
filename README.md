# Chess (v0.2)

A cross-platform chess application built with Flutter, targeting **macOS**
and **iPadOS** as the primary platforms for this release. The codebase is
plain Dart/Flutter with no platform-specific code, so it also builds for
iOS, Android, Windows, Linux, and web with minimal extra setup.

## Features (v0.1)

- Human vs. Computer play
- Standard chess rules, including castling, en passant, and promotion
- Full legal move validation (no illegal moves possible, by either side)
- Move highlighting: selected square, legal destinations, king in check
- Undo (steps back to the human's previous turn)
- Restart (with confirmation)
- Move history panel in standard algebraic notation
- Clean Material 3 interface, light/dark mode following system appearance


## Features Added (v0.2)

- Save completed games
- Review saved games using the review board
- Fixed an issue with the New Game button



## Getting Started

```bash
flutter pub get

# Run on macOS
flutter run -d macos

# Run on an iPad simulator or connected device
flutter run -d ios
```

If the `macos/` or `ios/` platform folders are missing from this project,
generate them first:

```bash
flutter create --platforms=macos,ios .
```

To add other platforms later (Windows, Android, etc.), the same pattern
applies — e.g. `flutter create --platforms=windows,android .` — since
nothing in the codebase is platform-specific.

## Project Structure

```
lib/
├── main.dart                  # App entry point, theme + root widget

├── models/                    # Pure data classes — no Flutter, no rules
│   ├── enums.dart             # PieceType, PieceColor, GameStatus, MoveFlag
│   ├── piece.dart             # Piece (type, color, hasMoved)
│   ├── position.dart          # Board coordinate (file, rank)
│   ├── move.dart              # A single move, incl. SAN rendering
│   └── game_state.dart        # Full immutable snapshot of a game

├── game_logic/                # Rules engine — pure Dart, fully testable
│   ├── board.dart              # Board queries + move application
│   ├── move_generator.dart     # Pseudo-legal move generation
│   ├── move_validator.dart     # Full legality (own-king-safety check)
│   ├── check_detector.dart     # Check / checkmate / stalemate / draws
│   └── game_controller.dart    # Orchestrates a live game (make/undo/restart)

├── engine/                    # Computer opponent
│   ├── chess_engine.dart       # Abstract interface for any opponent
│   ├── evaluation.dart         # Static position scoring
│   └── simple_engine.dart      # v0.1 opponent: minimax + alpha-beta

├── ui/
│   ├── screens/
│   │   └── game_screen.dart    # Main screen, responsive layout
│   ├── widgets/
│   │   ├── chess_board_widget.dart
│   │   ├── chess_square_widget.dart
│   │   ├── chess_piece_widget.dart
│   │   ├── move_history_panel.dart
│   │   └── game_controls_bar.dart
│   └── theme/
│       └── app_theme.dart      # Material 3 theme, single source of styling

└── utils/
    ├── constants.dart          # Shared constants (board size, breakpoints…)
    └── extensions.dart         # Small helper extensions
```

## Architecture Notes

- **`models/` and `game_logic/` have zero Flutter dependency.** They're
  plain, testable Dart. This means the rules engine could be reused
  outside Flutter entirely (e.g. a CLI or server) without changes.
- **`ChessEngine` is an abstract interface.** `SimpleEngine` is the only
  v0.1 implementation, but future opponents (a coaching engine, an
  adaptive-difficulty engine) are new classes implementing the same
  interface — no other code needs to change to swap them in.
- **`GameController` is the single path for making moves.** Both the
  human player's taps and the computer's chosen move go through
  `GameController.makeMove()`, so both are held to identical rules.
- **Undo works by snapshotting full `GameState` objects**, not by
  reverse-computing moves — simple and correct by construction, and
  the same data model a future "Saved Games" feature would serialize.

## Planned for Future Versions (not yet implemented)

The architecture is deliberately structured so these can be added without
restructuring existing code:

- Player profiles
- Statistics
- Coach AI (a new `ChessEngine` implementation)
- Adaptive difficulty (parameterizing/wrapping `SimpleEngine`)
- Themes (extending `app_theme.dart`'s centralized styling)
- Saved games (serializing `GameState`)
- Settings (human color, engine depth, etc. are currently hardcoded
  constants in `game_screen.dart`, ready to become user-configurable)

## Known v0.1 Simplifications

Documented in code comments where relevant:

- SAN move notation does not yet disambiguate two identical pieces that
  could reach the same square (e.g. `Nbd7` vs `Nfd7`).
- Threefold repetition detection is a documented stub (always returns
  `false`) — proper detection needs a position-history map that will be
  added alongside a more complete `GameController`.
- Piece rendering uses Unicode chess glyphs rather than image assets,
  keeping the app asset-free; swapping to custom art is isolated to
  `chess_piece_widget.dart`.

