# Screw Jam 🔩

A Flutter puzzle game in the style of the "Screw Jam / Nuts & Bolts" mobile hits.
Tap screws to unscrew them, sort them into matching colour boxes, and drop
every plate off the board.

## Features

- **250 levels**, each checked by the automated tests below
- Difficulty curve: tutorial levels, then more plates, screws and colours;
  every 10th level is a **HARD** boss level, with easier "breather" levels in between
- **Login / Sign up / Guest** with 8 avatars. Accounts are stored on the device;
  passwords are salted and hashed with SHA-256
- Separate progress per profile: unlocked levels, 1–3 stars, coins, stats
- Boosters: **Undo**, **Hint** (the solver finds a safe move), **+1 tray slot**, **Restart**
- Win dialog with stars and coins, and an "Out of space" dialog when you are stuck
- Animations: falling plates, screws popping into boxes, box refills, shake on a blocked screw
- Sound and vibration toggles, profile page, reset progress

## How to play

1. Tap a screw. It goes into the open box of the same colour, or into the tray if no box matches.
2. A screw under another plate can't be moved until that plate falls.
3. A plate falls when all of its screws are out.
4. A full box (3 screws) leaves and the next box comes in. Matching screws in the tray jump into it.
5. Fill every box to win. If the tray is full and nothing can move, you lose.

## Run it

```bash
cd screw_jam
flutter pub get
flutter run            # Android / iOS device or emulator
flutter run -d chrome  # in the browser
flutter build apk --release
```

## How the levels are guaranteed solvable

`tool/generate_levels.dart` writes `assets/levels.json` (`lib/engine/generator.dart`):

1. Stack random plates and pin them with screws.
2. Play a random "remove any free screw" order to the end. This always works,
   because the top plate is never covered.
3. Colour the screws along that order so it fills the boxes exactly, then
   scramble the colours with random swaps. A swap is kept only if that order
   still wins within the tray limit.
4. Reject the level if a simulated casual player wins it too often (too easy)
   or almost never (too hard). An independent solver
   (`lib/engine/solver.dart`) must also solve it from the start.

Regenerate with `dart run tool/generate_levels.dart 250`.

## Tests

```bash
flutter test
```

For **every one of the 250 levels** the tests check that:

- the level data is valid: screw counts match the boxes, one screw per cell, and every plate has a screw
- the stored solution, replayed through the real game engine, wins
- the independent solver solves the level from the start
- random play (30 runs per level) always ends as a clear **win** or a detected
  **stuck** state, never a hang or an invalid state

UI tests cover sign up, wrong password, login, validation, guest mode, locked
levels, winning level 1 by tapping the board, and the "out of space" dialog with undo.
