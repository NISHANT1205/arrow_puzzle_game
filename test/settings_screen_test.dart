import 'package:arrow_puzzle/screens/settings_screen.dart';
import 'package:arrow_puzzle/services/local_storage_service.dart';
import 'package:arrow_puzzle/state/settings_provider.dart';
import 'package:arrow_puzzle/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final calls = <MethodCall>[];
  var launchSucceeds = true;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({'sound_enabled': false});
    await LocalStorageService().init();
  });
  setUp(() {
    calls.clear();
    launchSucceeds = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return launchSucceeds;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> open(WidgetTester tester,
      {Brightness brightness = Brightness.light}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => SettingsNotifier(
              initialSettings: const AppSettings(soundEnabled: false),
            ))
      ],
      child: MaterialApp(
          theme: AppTheme.build(brightness), home: const SettingsScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('saved mute is shown and both toggle directions persist',
      (tester) async {
    await open(tester);
    expect(find.text('Player profile'), findsNothing);
    expect(find.text('Muted'), findsOneWidget);
    final sound = find.widgetWithText(SwitchListTile, 'Sound effects');
    await tester.tap(sound);
    await tester.pumpAndSettle();
    expect(find.text('Sound on'), findsOneWidget);
    expect(
        await LocalStorageService().loadBoolSetting('sound_enabled'), isTrue);
    await tester.tap(sound);
    await tester.pumpAndSettle();
    expect(find.text('Muted'), findsOneWidget);
    expect(
        await LocalStorageService().loadBoolSetting('sound_enabled'), isFalse);
  });

  testWidgets('privacy and rate buttons open exact external destinations',
      (tester) async {
    await open(tester, brightness: Brightness.dark);
    await tester.ensureVisible(find.text('Privacy policy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();
    expect(calls.single.arguments['url'],
        'https://nisharc.in/privacy-policy/arrow-puzzle');
    expect(calls.single.arguments['useWebView'], isFalse);
    await tester.ensureVisible(find.text('Rate us'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rate us'));
    await tester.pumpAndSettle();
    expect(calls.last.arguments['url'],
        'https://play.google.com/store/apps/details?id=com.nisharc.arrowpuzzle');
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed external launch shows a retry message', (tester) async {
    launchSucceeds = false;
    await open(tester);
    await tester.ensureVisible(find.text('Privacy policy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();
    expect(find.text('Could not open the link. Please try again.'),
        findsOneWidget);
  });
}
