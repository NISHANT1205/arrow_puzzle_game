import 'dart:math';

import 'package:flutter/material.dart';

import '../widgets/common.dart';
import '../widgets/palette.dart';
import '../widgets/screw_painter.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s != AnimationStatus.completed || !mounted) return;
      final loggedIn = AppScope.read(context).user != null;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (_, _, _) =>
              loggedIn ? const HomeScreen() : const LoginScreen(),
          transitionsBuilder: (_, a, _, child) =>
              FadeTransition(opacity: a, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameBackground(
        child: Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) {
              final t = Curves.easeOutBack.transform(_c.value.clamp(0, 1));
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.rotate(
                    angle: _c.value * pi * 2,
                    child: Transform.scale(
                      scale: t,
                      child: const ScrewIcon(color: Palette.accent, size: 120),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Opacity(opacity: _c.value, child: const Logo()),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class Logo extends StatelessWidget {
  final double size;
  const Logo({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    TextStyle s(Color c) => TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w900,
      color: c,
      letterSpacing: 2,
      shadows: const [
        Shadow(color: Colors.black54, offset: Offset(0, 4), blurRadius: 6),
      ],
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('SCREW ', style: s(Colors.white)),
          Text('JAM', style: s(Palette.accent)),
        ],
      ),
    );
  }
}
