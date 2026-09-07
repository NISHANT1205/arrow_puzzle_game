// lib/screens/pack_select_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/level_provider.dart';
import '../state/progress_provider.dart';
import 'level_select_screen.dart';

class PackSelectScreen extends ConsumerWidget {
  const PackSelectScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packsAsync = ref.watch(packsProvider);
    final totalStars = ref.watch(totalStarsProvider);
    final totalCompleted = ref.watch(totalCompletedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Packs'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Stats bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    const Text('Levels'),
                    Text(
                      totalCompleted.toString(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Text('Stars'),
                    Text(
                      totalStars.toString(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Packs list
          Expanded(
            child: packsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (packs) {
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: packs.length,
                  itemBuilder: (context, index) {
                    final packName = packs[index];
                    return _PackTile(packName: packName, packIndex: index + 1);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PackTile extends ConsumerWidget {
  final String packName;
  final int packIndex;

  const _PackTile({required this.packName, required this.packIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levelsAsync = ref.watch(levelsByPackProvider(packName));

    return levelsAsync.when(
      loading: () => const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => SizedBox(
        height: 100,
        child: Center(child: Text('Error: $err')),
      ),
      data: (levels) {
        final progressMap = ref.watch(progressProvider);

        int completedCount = 0;
        int totalStars = 0;

        for (final level in levels) {
          final progress = progressMap[level.id];
          if (progress?.isCompleted ?? false) {
            completedCount++;
            totalStars += progress?.stars ?? 0;
          }
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LevelSelectScreen(packName: packName),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Pack icon/number
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          packIndex.toString(),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Pack info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            packName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$completedCount/${levels.length} levels completed',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (totalStars > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: 16,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$totalStars stars',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
