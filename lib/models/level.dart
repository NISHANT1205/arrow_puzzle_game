// lib/models/level.dart

/// Represents a direction an arrow can point.
enum ArrowDirection {
  up,
  down,
  left,
  right,
  upLeft,
  upRight,
  downLeft,
  downRight;

  /// Get the direction as a pair of (row delta, col delta).
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

  /// Convert string to ArrowDirection.
  static ArrowDirection fromString(String value) {
    return ArrowDirection.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => throw FormatException('Unknown arrow direction: $value'),
    );
  }

  /// Convert to string for JSON serialization.
  String toJsonString() => name;
}

/// Represents a single arrow tile on the board.
class Arrow {
  final int row;
  final int col;
  final ArrowDirection direction;

  Arrow({
    required this.row,
    required this.col,
    required this.direction,
  });

  /// Create a copy with optional field overrides.
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

  /// Convert to JSON for serialization.
  Map<String, dynamic> toJson() {
    return {
      'row': row,
      'col': col,
      'direction': direction.toJsonString(),
    };
  }

  /// Create from JSON.
  factory Arrow.fromJson(Map<String, dynamic> json) {
    return Arrow(
      row: json['row'] as int,
      col: json['col'] as int,
      direction: ArrowDirection.fromString(json['direction'] as String),
    );
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

/// Represents a complete puzzle level.
class Level {
  final int id;
  final String pack;
  final int gridSize;
  final List<Arrow> arrows;

  /// The intended clearing order (for generation and validation).
  /// Each element is [row, col] of an arrow position.
  final List<List<int>> solutionOrder;

  Level({
    required this.id,
    required this.pack,
    required this.gridSize,
    required this.arrows,
    required this.solutionOrder,
  });

  /// Convert to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pack': pack,
      'gridSize': gridSize,
      'arrows': arrows.map((a) => a.toJson()).toList(),
      'solutionOrder': solutionOrder,
    };
  }

  /// Create from JSON.
  factory Level.fromJson(Map<String, dynamic> json) {
    return Level(
      id: json['id'] as int,
      pack: json['pack'] as String,
      gridSize: json['gridSize'] as int,
      arrows: (json['arrows'] as List<dynamic>)
          .map((a) => Arrow.fromJson(a as Map<String, dynamic>))
          .toList(),
      solutionOrder: (json['solutionOrder'] as List<dynamic>)
          .cast<List<dynamic>>()
          .map((e) => e.cast<int>().toList())
          .toList(),
    );
  }

  @override
  String toString() =>
      'Level($id, $pack, ${gridSize}x$gridSize, ${arrows.length} arrows)';
}
