import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/local_storage_service.dart';
import 'services/audio_service.dart';
import 'services/haptic_service.dart';
import 'state/settings_provider.dart';
import 'state/progress_provider.dart';
import 'screens/pack_select_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorageService().init();
  runApp(const ProviderScope(child: ArrowPuzzleApp()));
}

class ArrowPuzzleApp extends ConsumerWidget {
  const ArrowPuzzleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkMode = ref.watch(darkModeProvider);
    final soundEnabled = ref.watch(soundEnabledProvider);
    final hapticsEnabled = ref.watch(hapticsEnabledProvider);

    // Configure audio and haptic services based on settings
    AudioService().setEnabled(soundEnabled);
    HapticService().setEnabled(hapticsEnabled);

    return MaterialApp(
      title: 'Arrow Puzzle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E90FF),
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        ),
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF6F7FC),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        dialogTheme: DialogThemeData(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6EA8F0),
          brightness: Brightness.dark,
        ),
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF11131B),
        dialogTheme: DialogThemeData(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
      ),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final completedLevels = ref.watch(totalCompletedProvider);
    final earnedStars = ref.watch(totalStarsProvider);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _HomeBackgroundPainter(
                  color: colors.primary.withValues(alpha: 0.09),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: IconButton.filledTonal(
                      tooltip: 'Settings',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.settings_rounded),
                    ),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 40,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _PuzzleMark(colorScheme: colors),
                            const SizedBox(height: 28),
                            Text(
                              'ARROW PUZZLE',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .displaySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.5,
                                    height: 1,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Clear the board. One smart move at a time.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                            ),
                            const SizedBox(height: 34),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 430),
                              child: Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    height: 58,
                                    child: FilledButton.icon(
                                      onPressed: () =>
                                          Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const PackSelectScreen(),
                                        ),
                                      ),
                                      icon:
                                          const Icon(Icons.play_arrow_rounded),
                                      label: Text(
                                        completedLevels > 0
                                            ? 'Continue playing'
                                            : 'Start playing',
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  _ProgressCard(
                                    completedLevels: completedLevels,
                                    earnedStars: earnedStars,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),
                            Padding(
                              padding: EdgeInsets.zero,
                              child: Text(
                                '8 PACKS  •  200 LEVELS  •  ENDLESS FUN',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: colors.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PuzzleMark extends StatelessWidget {
  const _PuzzleMark({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 116,
      height: 116,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/icon/app_icon.png',
        fit: BoxFit.cover,
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.completedLevels,
    required this.earnedStars,
  });

  final int completedLevels;
  final int earnedStars;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              icon: Icons.flag_rounded,
              value: '$completedLevels / 200',
              label: 'Levels cleared',
              color: colors.primary,
            ),
          ),
          Container(
            width: 1,
            height: 42,
            color: colors.outlineVariant,
          ),
          Expanded(
            child: _Stat(
              icon: Icons.star_rounded,
              value: '$earnedStars',
              label: 'Stars earned',
              color: const Color(0xFFFFB020),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 25, color: color),
        const SizedBox(width: 9),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeBackgroundPainter extends CustomPainter {
  const _HomeBackgroundPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    const iconSize = 42.0;
    const spacing = 118.0;
    for (double y = 80; y < size.height; y += spacing) {
      for (double x = -20; x < size.width; x += spacing) {
        final offsetX = ((y / spacing).round().isEven) ? 0.0 : 58.0;
        final center = Offset(x + offsetX, y);
        canvas.drawLine(
          center.translate(-iconSize / 3, iconSize / 3),
          center.translate(iconSize / 3, -iconSize / 3),
          paint,
        );
        canvas.drawLine(
          center.translate(iconSize / 3, -iconSize / 3),
          center.translate(iconSize / 3, 3),
          paint,
        );
        canvas.drawLine(
          center.translate(iconSize / 3, -iconSize / 3),
          center.translate(-3, -iconSize / 3),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HomeBackgroundPainter oldDelegate) =>
      oldDelegate.color != color;
}
