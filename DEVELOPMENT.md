# Arrow Puzzle - Development Guide

This guide is for developers who want to understand and extend the Arrow Puzzle codebase.

## Architecture Overview

### Game Loop
1. **Level Load**: User selects level → `LevelRepository.getLevelById()`
2. **Game Init**: `GameNotifier.startGame(level)` → Creates `GameState` with fresh board
3. **Gameplay Loop**:
   - User taps grid cell → `_handleTap(row, col)`
   - `GameNotifier.tapArrow()` → Checks ray-casting logic
   - If valid: Remove arrow, update state, play sound/haptic
   - If blocked: Increment counter, play feedback, no state change
4. **Win Condition**: Check `board.isCleared()` → Show completion dialog
5. **Progress Save**: `ProgressNotifier.saveLevelProgress()` → SharedPreferences

### State Management (Riverpod)

**Three main state providers:**

1. **GameProvider** (`lib/state/game_provider.dart`)
   - Holds active `GameState` (board, undo history, move count, blocked count)
   - Notifier methods: `startGame()`, `tapArrow()`, `undo()`, `reset()`, `getHint()`
   - Watched by: GameScreen, ArrowBoardWidget

2. **ProgressProvider** (`lib/state/progress_provider.dart`)
   - Holds map of `LevelProgress` (id → progress)
   - Persists to SharedPreferences
   - Watched by: PackSelectScreen, LevelSelectScreen, GameScreen

3. **LevelProvider** (`lib/state/level_provider.dart`)
   - Caches loaded levels from JSON
   - Provides: all levels, by pack, by ID, next/previous
   - Family providers for lazy loading

**Dependency Graph:**
```
GameProvider
  └─ Watched by: GameScreen, ArrowBoardWidget

ProgressProvider
  └─ Watched by: PackSelectScreen, LevelSelectScreen

LevelProvider
  └─ Watched by: LevelSelectScreen, PackSelectScreen

SettingsProvider
  └─ Watched by: main.dart (theme), services (audio/haptics)
```

### Game Logic (Engine)

**Ray-Casting Algorithm** (`lib/engine/arrow_board.dart`)

```dart
bool isPathClear(Arrow arrow) {
  final (dRow, dCol) = arrow.direction.getDelta();
  int r = arrow.row + dRow;
  int c = arrow.col + dCol;
  
  // Walk along the ray until off-board
  while (r >= 0 && r < gridSize && c >= 0 && c < gridSize) {
    if (isOccupied(r, c)) return false;  // Blocked!
    r += dRow;
    c += dCol;
  }
  
  return true;  // Made it to edge
}
```

**Undo Implementation:**
- Maintain `List<Arrow> undoHistory` (stack of removed arrows)
- `tapArrow()`: Add removed arrow to history
- `undo()`: Pop arrow, restore to board, decrement move count
- Cannot undo a blocked tap (nothing changed)

### Level Generation (Reverse Construction)

**Location**: `tool/generate_levels.dart`

**Algorithm**:
```
Given: k (arrow count), gridSize, allowDiagonals

1. Generate random removal order: [r₁, r₂, ..., rₖ] (k distinct cells)

2. Build board BACKWARDS (from k to 1):
   For i = k down to 1:
     - For each direction (shuffled):
       - If path from rᵢ in that direction is clear:
         - Place arrow at rᵢ with that direction
         - Mark rᵢ as occupied
         - Break
     - If no valid direction found: retry entire level

3. Validate: Replay order [r₁, r₂, ..., rₖ] against game logic
   - Each tap must succeed
   - Final board must be empty

4. If valid: Save level
   If invalid: Discard and retry
```

**Why it works:**
- When we place r₁, no other arrows exist → trivially tappable
- When we place r₂, we avoid r₁'s path → r₁ still tappable
- By induction: full order is always valid

**Difficulty Parameters:**

```dart
PackConfig(
  name: 'Example',
  gridSize: 7,           // Grid dimensions
  minArrows: 15,         // Min arrows on board
  maxArrows: 18,         // Max arrows on board
  allowDiagonals: false, // Use ↑↓←→ or +↗↘↖↙
)
```

### UI Component Hierarchy

```
HomeScreen
├─ PackSelectScreen
│  └─ LevelSelectScreen
│     └─ GameScreen
│        └─ ArrowBoardWidget
│           ├─ ArrowTile (tappable)
│           ├─ SlidingArrowTile (animation on remove)
│           └─ BouncingArrowTile (animation on blocked)
```

### Data Flow Example: Tap an Arrow

```
User Taps Grid
  ↓
ArrowBoardWidget._handleTap(row, col)
  ↓
GameNotifier.tapArrow(row, col)
  ├─ Get arrow from board
  ├─ Check board.isPathClear(arrow)
  ├─ If yes:
  │   ├─ Remove from board
  │   ├─ Update undo history
  │   ├─ Increment move count
  │   ├─ Check if board is cleared
  │   └─ Emit new GameState
  └─ If no:
      ├─ Increment blocked tap count
      └─ Emit updated GameState (no board change)
  ↓
Riverpod rebuilds watching widgets
  ├─ ArrowBoardWidget (updates grid)
  ├─ GameScreen (updates HUD)
  └─ GameScreen (plays sound/haptics)
  ↓
If game won:
  └─ Show completion dialog
      └─ On confirm:
          ├─ Save progress
          ├─ Navigate to pack select
          └─ Clear game state
```

## Extending the Game

### Adding a New Pack

1. **Edit** `tool/generate_levels.dart`:
   ```dart
   final packs = [
     // ... existing packs ...
     PackConfig(
       name: 'Legendary',
       gridSize: 10,
       minArrows: 50,
       maxArrows: 60,
       allowDiagonals: true,
     ),
   ];
   ```

2. **Regenerate levels**:
   ```bash
   dart tool/generate_levels.dart
   ```

3. **Verify** `assets/data/levels.json` has new pack

### Adding a New Feature

**Example: Sound toggle in settings**

1. **Add to SettingsProvider**:
   ```dart
   class AppSettings {
     final bool soundEnabled;
     // ... add field to copyWith(), init, etc.
   }
   ```

2. **Add UI in SettingsScreen** (TODO):
   ```dart
   SwitchListTile(
     title: const Text('Sound'),
     value: settings.soundEnabled,
     onChanged: (val) => ref.read(settingsProvider.notifier).setSoundEnabled(val),
   )
   ```

3. **Use in AudioService**:
   ```dart
   final soundEnabled = ref.watch(soundEnabledProvider);
   AudioService().setEnabled(soundEnabled);
   ```

### Customizing Animations

**Slide-off animation** (currently instant removal):
- Edit `lib/widgets/arrow_tile.dart` → `SlidingArrowTile`
- Implement using `AnimatedBuilder` + `AnimationController`
- Duration: `AnimationDurations.slideOff` (300ms)

**Bounce animation** (currently instant feedback):
- Edit `lib/widgets/arrow_tile.dart` → `BouncingArrowTile`
- Currently has shake animation, but board doesn't show it
- Wire into `ArrowBoardWidget` to display during blocked taps

## Testing Strategy

### Unit Tests (Recommended)
```dart
// test/engine/arrow_board_test.dart

test('isPathClear returns true when path is empty', () {
  final board = ArrowBoard(gridSize: 5, initialArrows: [...]);
  final arrow = Arrow(row: 0, col: 0, direction: ArrowDirection.right);
  expect(board.isPathClear(arrow), isTrue);
});

test('isPathClear returns false when blocked', () {
  // Two arrows in same column
  expect(board.isPathClear(arrow), isFalse);
});
```

### Manual Testing Checklist
- [ ] Play levels 1, 50, 100, 150, 200 (one per difficulty)
- [ ] Verify undo works
- [ ] Verify reset works
- [ ] Verify hint highlights correct arrow
- [ ] Verify blocked tap doesn't change board
- [ ] Verify slide-off animation (if implemented)
- [ ] Verify bounce feedback (if implemented)
- [ ] Verify star rating (0, 1, 2, 3 stars)
- [ ] Verify progress persists across app restart
- [ ] Test on phone and tablet

### Level Validation
```bash
dart tool/generate_levels.dart
# Should output: "Validation: 200 passed, 0 failed"
```

## Performance Optimization Tips

1. **Lazy-load levels**: `FutureProvider.family` already does this
2. **Memo GameState**: Riverpod handles automatically
3. **Efficient grid**: `GridView.builder` only renders visible cells
4. **Cache board**: Don't recreate `ArrowBoard` unless necessary
5. **Batch state updates**: Emit once per tap, not multiple times

## Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| Levels not loading | levels.json not found | Run `dart tool/generate_levels.dart` |
| Undo greyed out | Undo history empty | Check `gameState.undoHistory.isNotEmpty` before enabling |
| Hint not working | No tappable arrows | Verify `board.findTappableArrows()` is called |
| State not updating | Provider not watched | Add `ref.watch(gameProvider)` in build |
| Performance slow | Too many rebuilds | Check that only necessary providers are watched |

## Debugging

### Print Game State
```dart
final gameState = ref.watch(gameProvider);
print('Remaining: ${gameState?.getRemainingArrows()}');
print('Moves: ${gameState?.moveCount}');
print('Board:');
gameState?.board.printDebug();
```

### Print Level Info
```dart
final level = await LevelRepository().getLevelById(1);
print('Level: ${level?.gridSize}x${level?.gridSize}');
print('Arrows: ${level?.arrows.length}');
print('Solution: ${level?.solutionOrder}');
```

### Enable Riverpod Logging
```dart
// In main.dart
runApp(
  ProviderScope(
    observers: [RiverpodObserver()],
    child: const ArrowPuzzleApp(),
  ),
);
```

## Code Style

- **Naming**: `camelCase` for variables, `PascalCase` for classes
- **Comments**: Document "why", not "what"
- **Imports**: Group by type (dart, flutter, package, relative)
- **Line length**: Max 80 chars (enforced by analysis_options.yaml)

---

Happy coding! 🎮

