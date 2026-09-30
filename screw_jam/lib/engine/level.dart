/// Static level data for Screw Jam.
///
/// A board is a grid of [cols] x [rows] cells. Plates are axis-aligned
/// rectangles of cells stacked in layers (a higher index in [plates] means
/// the plate lies on top). Every screw sits in one cell of exactly one plate
/// and pins it to the board. A screw can only be unscrewed when no plate
/// above its own plate covers its cell. A plate falls away once all of its
/// screws are removed.
///
/// Unscrewed screws go to the coloured boxes on top ([boxes] is the queue of
/// box colours, [activeBoxes] of them are open at a time, each holding 3
/// screws) or, if no open box matches, to the holding tray of [bufferSize]
/// slots.
class PlateDef {
  final int x, y, w, h;

  const PlateDef(this.x, this.y, this.w, this.h);

  bool covers(int cx, int cy) => cx >= x && cx < x + w && cy >= y && cy < y + h;

  List<int> toJson() => [x, y, w, h];

  factory PlateDef.fromJson(List<dynamic> j) =>
      PlateDef(j[0] as int, j[1] as int, j[2] as int, j[3] as int);
}

class ScrewDef {
  final int x, y;
  final int plate;
  final int color;

  const ScrewDef(this.x, this.y, this.plate, this.color);

  List<int> toJson() => [x, y, plate, color];

  factory ScrewDef.fromJson(List<dynamic> j) =>
      ScrewDef(j[0] as int, j[1] as int, j[2] as int, j[3] as int);
}

class LevelDef {
  static const int boxCapacity = 3;

  final int number;
  final int cols, rows;
  final int bufferSize;
  final int activeBoxes;
  final List<PlateDef> plates;
  final List<ScrewDef> screws;
  final List<int> boxes;

  /// A verified winning sequence of screw indices.
  final List<int> solution;

  const LevelDef({
    required this.number,
    required this.cols,
    required this.rows,
    required this.bufferSize,
    required this.activeBoxes,
    required this.plates,
    required this.screws,
    required this.boxes,
    required this.solution,
  });

  int get colorCount => boxes.toSet().length;

  Map<String, dynamic> toJson() => {
    'n': number,
    'c': cols,
    'r': rows,
    'b': bufferSize,
    'a': activeBoxes,
    'p': plates.map((p) => p.toJson()).toList(),
    's': screws.map((s) => s.toJson()).toList(),
    'q': boxes,
    'sol': solution,
  };

  factory LevelDef.fromJson(Map<String, dynamic> j) => LevelDef(
    number: j['n'] as int,
    cols: j['c'] as int,
    rows: j['r'] as int,
    bufferSize: j['b'] as int,
    activeBoxes: j['a'] as int,
    plates: (j['p'] as List).map((e) => PlateDef.fromJson(e as List)).toList(),
    screws: (j['s'] as List).map((e) => ScrewDef.fromJson(e as List)).toList(),
    boxes: (j['q'] as List).cast<int>(),
    solution: (j['sol'] as List).cast<int>(),
  );
}
