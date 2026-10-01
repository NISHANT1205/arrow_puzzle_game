// Generates assets/levels.json. Run from the bus_jam folder:
//   dart run tool/generate_levels.dart [count]
import 'dart:convert';
import 'dart:io';

import 'package:bus_jam/engine/generator.dart';

void main(List<String> args) {
  final count = args.isEmpty ? 250 : int.parse(args.first);
  final sw = Stopwatch()..start();
  final levels = <Map<String, dynamic>>[];
  for (var n = 1; n <= count; n++) {
    levels.add(LevelGenerator.generate(n).toJson());
    if (n % 25 == 0) {
      stdout.writeln('  $n levels (${sw.elapsedMilliseconds} ms)');
    }
  }
  File('assets/levels.json').writeAsStringSync(jsonEncode(levels));
  stdout.writeln('Wrote $count levels in ${sw.elapsedMilliseconds} ms');
}
