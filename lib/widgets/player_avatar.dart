import 'package:flutter/material.dart';

const avatarNames = [
  'Arrow Scout',
  'Cube Bot',
  'Maze Guardian',
  'Path Finder',
  'Bolt Runner',
  'Portal Mage',
];
const _avatarFiles = [
  'arrow-scout',
  'cube-bot',
  'maze-guardian',
  'path-finder',
  'bolt-runner',
  'portal-mage',
];

class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({super.key, required this.avatarId, this.size = 48});
  final int avatarId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final index = avatarId >= 0 ? avatarId % _avatarFiles.length : 0;
    return Semantics(
      image: true,
      label: '${avatarNames[index]} avatar',
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * .06),
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.primaryContainer),
        child: ClipOval(
            child: Image.asset(
                'assets/avatars/puzzle/${_avatarFiles[index]}.png',
                fit: BoxFit.contain,
                cacheWidth:
                    (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
                excludeFromSemantics: true)),
      ),
    );
  }
}
