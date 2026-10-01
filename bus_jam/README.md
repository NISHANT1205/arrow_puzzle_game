# Bus Jam 🚌

A Flutter parking-jam puzzle in the style of the "Bus Jam / Bus Out" mobile hits.
Drive cars, vans and buses out of a packed lot, park them at the station and
fill them with matching passengers.

## Features

- **250 levels**, each checked by the automated tests below
- **Hard from the start**: lots are 68–90% full and mix cars (4 seats),
  vans (6 seats) and buses (10 seats), with 3 to 8 colours. Every 10th level
  is a **BOSS** level; the level after a boss is a little gentler but still a
  real puzzle
- Top-down cars, vans and buses. Each one shows its fixed seats and has a
  direction badge in the middle; seats fill with passengers as they board
- Passengers walk along a winding 3-row queue, with everyone behind them
  visible. There are 5 station bays (+2 you can buy) and a road loop around
  the lot
- Animations: vehicles drive out, bump into whatever blocks them, arrive in
  their bay, and drive off once full; the queue shuffles forward
- **Login / Sign up / Guest**. Accounts are stored on the device; passwords are
  salted and hashed with SHA-256
- Separate progress per profile: unlocked levels, 1–3 stars, coins, stats
- Boosters: **Undo**, **Hint** (the solver picks a safe vehicle), **+1 bay**, **Restart**

## How to play

1. Tap a vehicle. It drives the way its roof arrow points, and only gets out
   if nothing is in front of it.
2. It parks in the first free station bay.
3. The passenger at the front of the queue boards a parked vehicle of the
   same colour. A full vehicle drives off and frees its bay.
4. Board every passenger to win. If every bay is full and the front passenger
   can't board, you lose.

## Run it

```bash
cd bus_jam
flutter pub get
flutter run            # Android / iOS device or emulator
flutter run -d chrome  # in the browser
flutter build apk --release
```

## How the levels are guaranteed solvable

`tool/generate_levels.dart` writes `assets/levels.json` (`lib/engine/generator.dart`):

1. Vehicles are parked one by one, and each new one needs a clear road out
   past the ones already parked. Removing them newest-first always works, so
   the lot can never lock up completely.
2. A random exit order is played: at each step, any vehicle with a clear road
   may go.
3. Passengers are lined up in exactly that order, then shuffled with random
   swaps. A swap is kept only if that order still wins without using more
   bays than the level's difficulty allows.
4. Two simulated players test the level. One taps the vehicle whose
   passengers are needed soonest; the other matches the front passenger. If
   either wins too often, the level is rejected. The cap is 55% at level 4
   and drops to 15% by level 250 (lower on boss levels). An independent
   solver (`lib/engine/solver.dart`) must also solve the level from the start.

Regenerate with `dart run tool/generate_levels.dart 250`.

## Tests

```bash
flutter test
```

For **every one of the 250 levels** the tests check that:

- the level data is valid: vehicles stay inside the lot, nothing overlaps, and
  there is exactly one passenger per seat for each colour
- the stored solution, replayed through the real game engine, wins
- the independent solver solves the level from the start
- random play (30 runs per level) always ends as a clear **win** or a detected
  **stuck** state; the lot never jams while a bay is free

`test/play_all_levels_test.dart` also **plays all 250 levels through the
real game screen**, tapping each vehicle the way a player would, and checks
that the win dialog appears with 3 stars.

Engine tests cover blocking, boarding, departures, the stuck state, undo,
extra bays and hints. UI tests cover sign up, login, validation, guest mode,
locked levels, winning level 1 by tapping vehicles, bumping a blocked vehicle,
and the "out of space" dialog with undo.
