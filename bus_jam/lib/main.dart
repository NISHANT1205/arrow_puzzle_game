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
  runApp(BusJamApp(state: state));
}

class BusJamApp extends StatelessWidget {
  final AppState state;
  const BusJamApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'Bus Jam',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Palette.blue,
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: Palette.bgBottom,
          appBarTheme: const AppBarTheme(
            backgroundColor: Palette.bgTop,
            foregroundColor: Palette.ink,
            elevation: 0,
            titleTextStyle: TextStyle(
              color: Palette.ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          textTheme: ThemeData.light().textTheme.apply(
            bodyColor: Palette.ink,
            displayColor: Palette.ink,
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
