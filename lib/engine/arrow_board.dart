// lib/engine/arrow_board.dart

import '../models/level.dart';

/// Represents the current state of a board during gameplay.
/// Tracks which arrows are still present (index -> arrow).
class ArrowBoard {
  final int gridSize;
  final Map<(int, int), Arrow> _arrows; // key: (row, col)

  ArrowBoard({
    required this.gridSize,
    required List<Arrow> initialArrows,
  }) : _arrows = {for (var a in initialArrows) (a.row, a.col): a};

  /// Get all current arrows on the board.
  List<Arrow> get arrows => _arrows.values.toList();

  /// Get arrow at a specific position, or null if empty.
  Arrow? getArrowAt(int row, int col) => _arrows[(row, col)];

  /// Check if a cell is occupied.
  bool isOccupied(int row, int col) => _arrows.containsKey((row, col));

  /// Try to tap an arrow at (row, col).
  /// Returns true if successful (arrow was removed), false if blocked.
  bool tapArrow(int row, int col) {
    final arrow = _arrows[(row, col)];
    if (arrow == null) return false; // No arrow at this location

    // Check if the path is clear
    if (!isPathClear(arrow)) return false;

    // Path is clear, remove the arrow
    _arrows.remove((row, col));
    return true;
  }

  /// Check if an arrow's path to the edge is completely clear.
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

  /// Get the next position where an arrow would land if tapped (for animation).
  /// Returns (finalRow, finalCol, numCellsTraversed).
  /// Only valid if isPathClear(arrow) is true.
  (int, int, int) getSlideDestination(Arrow arrow) {
    final (dRow, dCol) = arrow.direction.getDelta();
    int r = arrow.row + dRow;
    int c = arrow.col + dCol;
    int cells = 0;

    while (r >= 0 && r < gridSize && c >= 0 && c < gridSize) {
      cells++;
      r += dRow;
      c += dCol;
    }

    // We've gone one step too far (off the board), so go back one step.
    r -= dRow;
    c -= dCol;

    return (r, c, cells);
  }

  /// Find all arrows that can be tapped right now (paths are clear).
  List<Arrow> findTappableArrows() {
    return arrows.where((arrow) => isPathClear(arrow)).toList();
  }

  /// Undo the last arrow removal by restoring it.
  void restoreArrow(Arrow arrow) {
    _arrows[(arrow.row, arrow.col)] = arrow;
  }

  /// Check if the board is completely clear (all arrows removed).
  bool isCleared() => _arrows.isEmpty;

  /// Create a deep copy of the board.
  ArrowBoard copy() {
    return ArrowBoard(
      gridSize: gridSize,
      initialArrows: arrows.map((a) => a).toList(),
    );
  }

  /// Reset to initial state from a list of arrows.
  void reset(List<Arrow> initialArrows) {
    _arrows.clear();
    for (var a in initialArrows) {
      _arrows[(a.row, a.col)] = a;
    }
  }

  /// Get board state as a 2D grid for debugging.
  List<List<String>> toDebugGrid() {
    final grid = List.generate(
      gridSize,
      (_) => List.generate(gridSize, (_) => '.'),
    );

    for (var arrow in arrows) {
      grid[arrow.row][arrow.col] =
          arrow.direction.name.substring(0, 1).toUpperCase();
    }

    return grid;
  }

  /// Print debug grid.
  void printDebug() {
    final grid = toDebugGrid();
    for (var row in grid) {
      print(row.join(' '));
    }
  }
}
