# Arrow Puzzle (Flutter)

A Flutter take on the trending "arrows escape" puzzle: a dot grid packed with
snake-like arrows. Tap an arrow and it slithers along its own body and out of
the board in the direction its head points. If another arrow is in the way,
it crashes, bounces back, flashes red, and you lose a heart. Clear the board
before you run out of hearts.

## Gameplay

- **Arrows** are paths of connected cells with any number of 90° bends. The
  head points along the last segment.
- **Tap** an arrow: it escapes if every cell straight ahead of its head, up
  to the edge, is empty.
- **Blocked**: the arrow slides until it hits the arrow in its way, turns
  red, snaps back, and costs **1 of 3 hearts**.
- **Hint** highlights an arrow that can escape right now.
- **Out of hearts**: retry the level, or continue once with +1 heart.
- **Win**: clear every arrow to unlock the next level.
- **Pinch to zoom** and pan on big boards.

## Levels

Levels are generated on the fly and never run out. The same level number
always gives the same puzzle.

- Boards grow from 4×6 up to 16×22, arrows get longer, and the grid gets
  denser as you progress.
- Every level is guaranteed solvable because of how it is built: arrows are
  placed one at a time, and each new arrow's escape lane must be clear of the
  arrows already placed. Removing them in reverse order always works.
- Several candidates are built per level and the most tightly packed one is
  kept (about 85% of the grid is covered on average).
- Removing an arrow never blocks another one, so a board is solvable exactly
  when greedily removing free arrows clears it. `PuzzleBoard.solve()` uses
  this, and the tests check the first 300 levels.

```bash
dart run tool/level_stats.dart 1 100   # size / arrow count / fill per level
```

## Project structure

```
lib/
  main.dart                     App + theme
  models/
    arrow_path.dart             Cell, Dir, ArrowPath (tail -> head cells)
    level.dart                  Level (rows, cols, arrows)
  engine/
    puzzle_board.dart           Rules: escape / blocked, solver
    level_generator.dart        Deterministic, always-solvable generator
  state/
    game_controller.dart        Lives, hints, win/lose for one play-through
    progress_provider.dart      Current level (persisted)
    settings_provider.dart      Sound / haptics / dark mode
  screens/
    home_screen.dart            Logo board + "Level N" play button
    game_screen.dart            Board, hearts, hint, restart, result dialogs
    level_select_screen.dart    Replay cleared levels
    settings_screen.dart
  widgets/
    arrow_board_view.dart       Dot grid, arrow painter, tap + animations
    hearts_bar.dart
  services/                     Storage, system sounds, haptics
test/arrow_puzzle_test.dart     Rules, lives, hints, generator solvability
tool/level_stats.dart
```

## Run

```bash
flutter pub get
flutter run
flutter test
flutter build apk --release
```
