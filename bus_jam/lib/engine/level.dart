/// Static level data for Bus Jam.
///
/// The parking lot is a grid of [cols] x [rows] cells. Each vehicle occupies
/// a straight line of cells and faces one of four directions. Tapping a
/// vehicle drives it forward; it leaves the lot only if every cell between
/// its nose and the edge of the lot is empty. A vehicle that leaves parks in
/// the first free bay at the station ([slots] bays). Passengers wait in a
/// single queue ([queue], colours, front first); the front passenger boards
/// a parked vehicle of the same colour that still has seats, and a full
/// vehicle departs, freeing its bay.
enum Dir { up, right, down, left }

extension DirX on Dir {
  int get dx => const [0, 1, 0, -1][index];
  int get dy => const [-1, 0, 1, 0][index];
}

enum VehicleKind { car, van, bus }

extension VehicleKindX on VehicleKind {
  int get length => const [2, 3, 4][index];
  int get seats => const [4, 6, 10][index];
}

class VehicleDef {
  /// Cell of the vehicle's nose.
  final int x, y;
  final Dir dir;
  final VehicleKind kind;
  final int color;

  const VehicleDef(this.x, this.y, this.dir, this.kind, this.color);

  int get length => kind.length;
  int get seats => kind.seats;

  /// Cells covered, nose first.
  Iterable<(int, int)> get cells sync* {
    for (var k = 0; k < length; k++) {
      yield (x - dir.dx * k, y - dir.dy * k);
    }
  }

  (int, int) get tail => (x - dir.dx * (length - 1), y - dir.dy * (length - 1));

  List<int> toJson() => [x, y, dir.index, kind.index, color];

  factory VehicleDef.fromJson(List<dynamic> j) => VehicleDef(
    j[0] as int,
    j[1] as int,
    Dir.values[j[2] as int],
    VehicleKind.values[j[3] as int],
    j[4] as int,
  );
}

class LevelDef {
  final int number;
  final int cols, rows;
  final int slots;
  final List<VehicleDef> vehicles;
  final List<int> queue;

  /// A verified winning order of vehicle taps.
  final List<int> solution;

  const LevelDef({
    required this.number,
    required this.cols,
    required this.rows,
    required this.slots,
    required this.vehicles,
    required this.queue,
    required this.solution,
  });

  int get colorCount => vehicles.map((v) => v.color).toSet().length;

  Map<String, dynamic> toJson() => {
    'n': number,
    'c': cols,
    'r': rows,
    's': slots,
    'v': vehicles.map((v) => v.toJson()).toList(),
    'q': queue,
    'sol': solution,
  };

  factory LevelDef.fromJson(Map<String, dynamic> j) => LevelDef(
    number: j['n'] as int,
    cols: j['c'] as int,
    rows: j['r'] as int,
    slots: j['s'] as int,
    vehicles: (j['v'] as List)
        .map((e) => VehicleDef.fromJson(e as List))
        .toList(),
    queue: (j['q'] as List).cast<int>(),
    solution: (j['sol'] as List).cast<int>(),
  );
}
