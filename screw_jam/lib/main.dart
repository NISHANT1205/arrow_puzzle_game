import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'screens/splash_screen.dart';
import 'widgets/common.dart';
import 'widgets/palette.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final state = await AppState.create();
  runApp(ScrewJamApp(state: state));
}

class ScrewJamApp extends StatelessWidget {
  final AppState state;
  const ScrewJamApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'Screw Jam',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Palette.accent,
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: Palette.bgBottom,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
