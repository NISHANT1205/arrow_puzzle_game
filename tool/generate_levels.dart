// tool/generate_levels.dart
// Run with: dart tool/generate_levels.dart

import 'dart:io';
import 'dart:math';
import 'dart:convert';

// Copy of ArrowDirection enum for the generator
enum ArrowDirection {
  up,
  down,
  left,
  right,
  upLeft,
  upRight,
  downLeft,
  downRight;

  (int, int) getDelta() {
    return switch (this) {
      ArrowDirection.up => (-1, 0),
      ArrowDirection.down => (1, 0),
      ArrowDirection.left => (0, -1),
      ArrowDirection.right => (0, 1),
      ArrowDirection.upLeft => (-1, -1),
      ArrowDirection.upRight => (-1, 1),
      ArrowDirection.downLeft => (1, -1),
      ArrowDirection.downRight => (1, 1),
    };
  }

  String toJsonString() => name;
}

class Arrow {
  final int row;
  final int col;
  final ArrowDirection direction;

  Arrow({
    required this.row,
    required this.col,
    required this.direction,
  });

  Arrow copyWith({
    int? row,
    int? col,
    ArrowDirection? direction,
  }) {
    return Arrow(
      row: row ?? this.row,
      col: col ?? this.col,
      direction: direction ?? this.direction,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'row': row,
      'col': col,
      'direction': direction.toJsonString(),
    };
  }

  @override
  String toString() => 'Arrow($row,$col,${direction.name})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Arrow &&
        row == other.row &&
        col == other.col &&
        direction == other.direction;
  }

  @override
  int get hashCode => Object.hash(row, col, direction);
}

class Level {
  final int id;
  final String pack;
  final int gridSize;
  final List<Arrow> arrows;
  final List<List<int>> solutionOrder;

  Level({
    required this.id,
    required this.pack,
    required this.gridSize,
    required this.arrows,
    required this.solutionOrder,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pack': pack,
      'gridSize': gridSize,
      'arrows': arrows.map((a) => a.toJson()).toList(),
      'solutionOrder': solutionOrder,
    };
  }

  @override
  String toString() =>
      'Level($id, $pack, ${gridSize}x$gridSize, ${arrows.length} arrows)';
}

/// Board state for generation.
class GeneratorBoard {
  final int gridSize;
  final Set<(int, int)> occupied;

  GeneratorBoard({required this.gridSize}) : occupied = {};

  bool isOccupied(int row, int col) => occupied.contains((row, col));

  /// Check if a path from (row, col) in a given direction is clear.
  bool isPathClear(int row, int col, ArrowDirection direction) {
    final (dRow, dCol) = direction.getDelta();
    int r = row + dRow;
    int c = col + dCol;

    while (r >= 0 && r < gridSize && c >= 0 && c < gridSize) {
      if (isOccupied(r, c)) return false;
      r += dRow;
      c += dCol;
    }

    return true;
  }

  void occupyCell(int row, int col) {
    occupied.add((row, col));
  }

  void vacateCell(int row, int col) {
    occupied.remove((row, col));
  }

  ArrowBoard toArrowBoard(List<Arrow> arrows) {
    return ArrowBoard(
      gridSize: gridSize,
      initialArrows: arrows,
    );
  }
}

/// Board state for validation (same as game engine).
class ArrowBoard {
  final int gridSize;
  final Map<(int, int), Arrow> _arrows;

  ArrowBoard({
    required this.gridSize,
    required List<Arrow> initialArrows,
  }) : _arrows = {for (var a in initialArrows) (a.row, a.col): a};

  List<Arrow> get arrows => _arrows.values.toList();

  Arrow? getArrowAt(int row, int col) => _arrows[(row, col)];

  bool isOccupied(int row, int col) => _arrows.containsKey((row, col));

  bool tapArrow(int row, int col) {
    final arrow = _arrows[(row, col)];
    if (arrow == null) return false;

    if (!isPathClear(arrow)) return false;

    _arrows.remove((row, col));
    return true;
  }

  bool isPathClear(Arrow arrow) {
    final (dRow, dCol) = arrow.direction.getDelta();
    int r = arrow.row + dRow;
    int c = arrow.col + dCol;

    while (r >= 0 && r < gridSize && c >= 0 && c < gridSize) {
      if (isOccupied(r, c)) return false;
      r += dRow;
      c += dCol;
    }

    return true;
  }

  bool isCleared() => _arrows.isEmpty;

  void printDebug() {
    final grid = List.generate(
      gridSize,
      (_) => List.generate(gridSize, (_) => '.'),
    );

    for (var arrow in arrows) {
      grid[arrow.row][arrow.col] =
          arrow.direction.name.substring(0, 1).toUpperCase();
    }

    for (var row in grid) {
      print(row.join(' '));
    }
  }
}

/// Validates that a generated level is solvable by replaying the solution order.
bool validateLevel(Level level) {
  final board =
      ArrowBoard(gridSize: level.gridSize, initialArrows: level.arrows);

  for (final pos in level.solutionOrder) {
    final row = pos[0];
    final col = pos[1];

    if (!board.tapArrow(row, col)) {
      return false;
    }
  }

  return board.isCleared();
}

/// Generate a single level using reverse construction.
Level? generateLevel(
    int id, String pack, int gridSize, int arrowCount, bool allowDiagonals) {
  const maxRetries = 100;

  for (int attempt = 0; attempt < maxRetries; attempt++) {
    final board = GeneratorBoard(gridSize: gridSize);
    final arrows = <Arrow>[];
    final solutionOrder = <List<int>>[];

    // Step 1: Choose the intended removal order (k distinct cells)
    final availableCells = <(int, int)>[];
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        availableCells.add((r, c));
      }
    }
    availableCells.shuffle(Random());

    if (availableCells.length < arrowCount) {
      continue; // Grid too small for this arrow count
    }

    final removalOrder = availableCells.take(arrowCount).toList();

    // Step 2: Build board in reverse order (from k down to 1)
    bool generationFailed = false;

    for (int i = removalOrder.length - 1; i >= 0; i--) {
      final (targetRow, targetCol) = removalOrder[i];

      // Try to find a valid direction for this position
      final directions = allowDiagonals
          ? ArrowDirection.values.toList()
          : [
              ArrowDirection.up,
              ArrowDirection.down,
              ArrowDirection.left,
              ArrowDirection.right
            ];

      directions.shuffle(Random());

      bool foundDirection = false;

      for (final direction in directions) {
        if (board.isPathClear(targetRow, targetCol, direction)) {
          // This direction works! Add the arrow.
          final arrow = Arrow(
            row: targetRow,
            col: targetCol,
            direction: direction,
          );
          arrows.add(arrow);
          board.occupyCell(targetRow, targetCol);
          solutionOrder.insert(
              0, [targetRow, targetCol]); // Prepend to maintain forward order
          foundDirection = true;
          break;
        }
      }

      if (!foundDirection) {
        // No valid direction found; this attempt failed.
        generationFailed = true;
        break;
      }
    }

    if (generationFailed) {
      continue; // Try again with different random choices
    }

    // Step 3: Create the level
    final level = Level(
      id: id,
      pack: pack,
      gridSize: gridSize,
      arrows: arrows,
      solutionOrder: solutionOrder,
    );

    // Step 4: Validate
    if (validateLevel(level)) {
      return level;
    }
  }

  return null; // Failed to generate after max retries
}

/// Pack definition: grid size, arrow count range, allow diagonals.
class PackConfig {
  final String name;
  final int gridSize;
  final int minArrows;
  final int maxArrows;
  final bool allowDiagonals;

  PackConfig({
    required this.name,
    required this.gridSize,
    required this.minArrows,
    required this.maxArrows,
    required this.allowDiagonals,
  });
}

void main() async {
  print('=== Arrow Puzzle Level Generator ===\n');

  // Define pack configurations based on the brief
  final packs = [
    PackConfig(
      name: 'Beginner',
      gridSize: 5,
      minArrows: 6,
      maxArrows: 9,
      allowDiagonals: false,
    ),
    PackConfig(
      name: 'Elementary',
      gridSize: 6,
      minArrows: 10,
      maxArrows: 14,
      allowDiagonals: false,
    ),
    PackConfig(
      name: 'Intermediate I',
      gridSize: 7,
      minArrows: 15,
      maxArrows: 18,
      allowDiagonals: false,
    ),
    PackConfig(
      name: 'Intermediate II',
      gridSize: 7,
      minArrows: 19,
      maxArrows: 22,
      allowDiagonals: false,
    ),
    PackConfig(
      name: 'Advanced I',
      gridSize: 8,
      minArrows: 20,
      maxArrows: 25,
      allowDiagonals: true,
    ),
    PackConfig(
      name: 'Advanced II',
      gridSize: 8,
      minArrows: 26,
      maxArrows: 30,
      allowDiagonals: true,
    ),
    PackConfig(
      name: 'Expert I',
      gridSize: 9,
      minArrows: 30,
      maxArrows: 38,
      allowDiagonals: true,
    ),
    PackConfig(
      name: 'Expert II',
      gridSize: 9,
      minArrows: 39,
      maxArrows: 45,
      allowDiagonals: true,
    ),
  ];

  final allLevels = <Level>[];
  int levelId = 1;
  int levelsPerPack = 25;

  for (final packConfig in packs) {
    print('Generating ${packConfig.name} pack...');

    for (int i = 0; i < levelsPerPack; i++) {
      final arrowCount = packConfig.minArrows +
          Random().nextInt(packConfig.maxArrows - packConfig.minArrows + 1);

      Level? level = generateLevel(
        levelId,
        packConfig.name,
        packConfig.gridSize,
        arrowCount,
        packConfig.allowDiagonals,
      );

      if (level != null) {
        allLevels.add(level);
        print(
            '  Level $levelId: ${level.gridSize}x${level.gridSize}, ${level.arrows.length} arrows');
        levelId++;
      } else {
        print('  Level $levelId: FAILED TO GENERATE (max retries exceeded)');
        // Try again with different params
        for (int retry = 0; retry < 5; retry++) {
          final newArrowCount = packConfig.minArrows +
              Random().nextInt(packConfig.maxArrows - packConfig.minArrows + 1);
          level = generateLevel(
            levelId,
            packConfig.name,
            packConfig.gridSize,
            newArrowCount,
            packConfig.allowDiagonals,
          );
          if (level != null) {
            allLevels.add(level);
            print(
                '  Level $levelId (retry $retry): ${level.gridSize}x${level.gridSize}, ${level.arrows.length} arrows');
            levelId++;
            break;
          }
        }

        if (level == null) {
          print('  Level $levelId: Skipped after multiple retries\n');
        }
      }
    }

    print('  ${packConfig.name} complete\n');
  }

  print('\n=== Validation Pass ===\n');

  int validCount = 0;
  int invalidCount = 0;

  for (final level in allLevels) {
    if (validateLevel(level)) {
      validCount++;
    } else {
      print('VALIDATION FAILED: Level ${level.id}');
      invalidCount++;
    }
  }

  print('Validation: $validCount passed, $invalidCount failed\n');

  if (invalidCount > 0) {
    print('ERROR: Some levels failed validation! Aborting.\n');
    exit(1);
  }

  // Step 5: Write levels.json
  print('=== Writing levels.json ===\n');

  final assetsDir = Directory('assets/data');
  if (!assetsDir.existsSync()) {
    assetsDir.createSync(recursive: true);
  }

  final levelsJson = allLevels.map((l) => l.toJson()).toList();
  final jsonContent = jsonEncode(levelsJson);

  final outputFile = File('assets/data/levels.json');
  await outputFile.writeAsString(jsonContent);

  print('✓ Generated ${allLevels.length} levels');
  print('✓ Saved to assets/data/levels.json\n');
}
