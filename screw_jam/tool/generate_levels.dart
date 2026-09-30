// Generates assets/levels.json. Run from the screw_jam folder:
//   dart run tool/generate_levels.dart [count]
import 'dart:convert';
import 'dart:io';

import 'package:screw_jam/engine/generator.dart';

void main(List<String> args) {
  final count = args.isEmpty ? 250 : int.parse(args.first);
  final sw = Stopwatch()..start();
  final levels = [
    for (var n = 1; n <= count; n++) LevelGenerator.generate(n).toJson(),
  ];
  File('assets/levels.json').writeAsStringSync(jsonEncode(levels));
  stdout.writeln('Wrote $count levels in ${sw.elapsedMilliseconds} ms');
}
