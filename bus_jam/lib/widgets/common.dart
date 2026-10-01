import 'package:flutter/material.dart';

import '../app_state.dart';
import 'palette.dart';

/// Makes [AppState] available to the widget tree and rebuilds dependents.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

class GameButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color;
  final double height;

  const GameButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.color = Palette.accent,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final base = enabled ? color : Colors.grey;
    return GestureDetector(
      onTap: onPressed == null
          ? null
          : () {
              AppScope.read(context).click();
              onPressed!();
            },
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(base, Colors.white, 0.25)!, base],
          ),
          border: Border(
            bottom: BorderSide(
              color: Color.lerp(base, Colors.black, 0.35)!,
              width: 5,
            ),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: height * 0.45),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: height * 0.34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  shadows: const [
                    Shadow(color: Colors.black38, offset: Offset(0, 2)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CoinChip extends StatelessWidget {
  final int coins;
  const CoinChip({super.key, required this.coins});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Palette.accent.withValues(alpha: 0.6)),
        boxShadow: Palette.softShadow(0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.monetization_on_rounded,
            color: Palette.accent,
            size: 20,
          ),
          const SizedBox(width: 6),
          Text(
            '$coins',
            key: const Key('coins'),
            style: const TextStyle(
              color: Palette.ink,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  final int index;
  final double size;
  const Avatar({super.key, required this.index, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = Palette.avatars[index % Palette.avatars.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.55),
    );
  }
}

void showToast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1400),
      ),
    );
}
