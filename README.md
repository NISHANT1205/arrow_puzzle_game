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

**300 bundled levels, each one harder than the one before**, then endless
generated levels at the hardest settings.

### Always harder

Every level has a difficulty score (`BoardStats.score`):

```
score = cells covered by arrows × (1 + 0.2 × layers) × (0.6 + trap ratio)
```

- **cells**: how much arrow there is to trace. Bigger boards and longer
  arrows mean more.
- **layers**: the longest chain of "this arrow must go before that one".
- **trap ratio**: the share of arrows that can't move at the start.

### Difficulty schedule

The badge marks the stage: **HARD** from level 100, **SUPER HARD** from
200.

| Levels | Board | What happens |
|---|---|---|
| 1–100 | 4×6 → 11×15 | Learning curve: short arrows, no deliberate traps |
| 100–200 | 12×17 → 21×29 | Steep climb: boards grow fast, arrows get longer, **traps** switch on and reach full strength |
| 200–300 | 22×30 | Hardest knobs: full traps, long winding arrows, lanes of 3+ cells |

**Traps** (`LevelConfig.blockLanes`): the generator keeps track of which
arrows can currently escape and puts new arrows right in their escape
lanes, so they can't leave until the new arrow is gone. It also won't place
an arrow on the edge pointing straight out (`minLane`), because those could
never be trapped.

| Level | Board | Arrows | Chain | Score (before → now) |
|---|---|---|---|---|
| 100 | 11×15 | 35 | 8 | 327 → 495 |
| 150 | 16×22 | 47 | 11 | 666 → 1283 |
| 200 | 21×29 | 53 | 17 | 1107 → 2834 |
| 250 | 22×30 | 69 | 17 | 1730 → 3419 |
| 300 | 22×30 | 57 | 26 | 3007 → 4893 |

`tool/build_levels.dart` builds the levels. Levels that share a board size
share a pool of boards (160 per size, 640+ for the 22×30 levels). The pool
is sorted by score, and evenly spaced boards that beat the previous level
are handed out.

```bash
dart run tool/build_levels.dart 300   # rebuilds assets/levels/levels.json
```

### Always solvable, never stuck

Arrows are placed one at a time, and each new arrow's escape lane must be
clear of the arrows already placed, so removing them in reverse order always
works. Removing an arrow never blocks another one, so once a level is
solvable it stays solvable whatever order you play in. The only way to
lose is running out of hearts.

The tests check every bundled level:

- It is solvable, and its recorded stats match.
- It scores higher than the level before, on a board at least as big.
- A perfect player wins it with 0 mistakes.
- 5 random players per level, who tap any arrow including blocked ones,
  always end in a win or a loss. There is always a safe move while the game
  is on, and no game runs longer than arrows + 4 taps.
- The hint is always a safe move.
- `test/game_screen_test.dart` plays **all bundled levels in a row on the
  real game screen**. It taps each arrow's head, checks that every tap
  removes an arrow, waits for "Level Complete!" and presses "Next Level".
  It also checks losing, Continue, Try Again, and winning on the last
  heart.

Safety nets in the app:

- The win/lose dialog also has a timer backup, so it shows even if an
  animation never reports back.
- A board with no possible move (which the checks rule out) ends the game
  instead of hanging.
- A level that fails to load shows "Try again" instead of spinning forever.

## Project structure

```
lib/
  main.dart                     App + theme
  models/
    arrow_path.dart             Cell, Dir, ArrowPath (tail -> head cells)
    level.dart                  Level (rows, cols, arrows)
    level_codec.dart            Compact level file format
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
  services/
    level_repository.dart       Bundled levels, then endless ones
    ...                         Storage, system sounds, haptics
assets/levels/levels.json       The bundled levels
test/                           Rules, every level, real-screen play
tool/build_levels.dart          Builds and checks the bundled levels
```

## Run

```bash
flutter pub get
flutter run
flutter test
flutter build apk --release
```
