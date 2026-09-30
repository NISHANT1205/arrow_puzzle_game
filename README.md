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
- **Pinch to zoom** (up to 6×) and pan on big boards.

## Levels

Levels are generated on the fly and never run out. The same level number
always gives the same puzzle.

### Difficulty

| Levels | Board | What changes |
|---|---|---|
| 1–4 | 4×6 | Tutorial: short arrows, most of them free |
| 5–40 | up to 14×19 | Boards grow fast, arrows get longer and bend more |
| 40–160 | up to 18×25 | Slow growth, more arrows aimed across the board |
| every 5th | +2 columns | **HARD** badge, longer arrows, 95% fill target |
| every 10th | +4 columns, up to 22×30 | **SUPER HARD** badge, 97% fill target, most tries |

How hard levels are made hard:

- **Aimed arrows**: many arrows point along their longest clear lane, so later
  arrows end up in that lane and must be moved first. This builds long chains
  of "move that one first".
- **Scored candidates**: several boards are built for each level (6 normal,
  10 Hard, 16 Super Hard). The winner is picked on fill, chain length, and
  how few arrows are free at the start.
- **Tail filling**: after building, arrow tails grow into leftover holes, so
  boards end up about 90% full, like the original.

`PuzzleBoard.analyze()` reports the numbers used:

- `free`: arrows free at the start
- `layers`: the longest "this must go before that" chain
- `narrowest`: the tightest moment, when only 1 or 2 moves are safe

### Always solvable

Arrows are placed one at a time, and each new arrow's escape lane must be
clear of the arrows already placed. Removing them in reverse order always
works. Tail filling only adds cells that no later arrow's lane needs, so it
keeps this guarantee.

Removing an arrow never blocks another one, so a board is solvable exactly
when greedily removing free arrows clears it. The tests replay levels 1–500,
and the tool below checks any range:

```bash
dart run tool/level_stats.dart 1 5000
# level 100 [Super Hard] 20x27 fill=88% arrows=56 free=9 layers=13 narrowest=1 solvable=true
# checked 5000 levels: unsolvable=0
```

Levels are generated on a background isolate, so big boards never freeze
the UI.

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
    tier_badge.dart             HARD / SUPER HARD pill
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
