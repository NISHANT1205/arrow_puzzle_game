"""Select 75 hardest puzzles per original 100-level slot.

Usage: python3 tool/curate_levels.py [source.json] [output.json]
Run after tool/build_levels.dart generates the original 300-level source.
"""
import copy
import json
import sys
from pathlib import Path

source_path = Path(sys.argv[1] if len(sys.argv) > 1 else 'assets/levels/levels.json')
output_path = Path(sys.argv[2] if len(sys.argv) > 2 else 'assets/levels/levels.json')
data = json.loads(source_path.read_text())
source = data['levels']
if len(source) != 300 or [entry['n'] for entry in source] != list(range(1, 301)):
    raise SystemExit('Expected the original 300 levels numbered 1–300.')
result = []
for slot in range(3):
    ranked = sorted(source[slot * 100:(slot + 1) * 100], key=lambda entry: entry['s']['score'])
    selected = ranked[-75:]
    regular, hardest = selected[:60], selected[60:]
    for block in range(15):
        for original in regular[block * 4:block * 4 + 4] + [hardest[block]]:
            entry = copy.deepcopy(original)
            entry['sourceLevel'] = entry['n']
            entry['n'] = len(result) + 1
            result.append(entry)
data['levels'] = result
output_path.write_text(json.dumps(data, separators=(',', ':')) + '\n')
print(f'Wrote {len(result)} levels to {output_path}')
