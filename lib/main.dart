/// Shogi (将棋) — Japanese chess with a Japanese-craft art direction.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/audio.dart';
import 'src/save.dart';
import 'src/screens/game.dart';
import 'src/screens/menu.dart';
import 'src/screens/settings_screen.dart';
import 'src/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await AudioService.I.init();
  runApp(const ShogiApp());
}

class ShogiApp extends StatelessWidget {
  const ShogiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shogi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: ShogiPalette.tatami,
        colorScheme: ColorScheme.fromSeed(
          seedColor: ShogiPalette.kayaAmber,
          primary: ShogiPalette.vermilion,
        ),
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
                builder: (_) => const MenuScreen());
          case '/settings':
            return MaterialPageRoute(
                builder: (_) => const SettingsScreen());
          case '/game':
            final args =
                settings.arguments as Map<String, dynamic>? ?? {};
            final config = args['config'] as GameConfig? ??
                const GameConfig(mode: 'bot');
            final cont = args['continue'] as bool? ?? false;
            return MaterialPageRoute(
                builder: (_) =>
                    GameScreen(config: config, continueSaved: cont));
          default:
            return MaterialPageRoute(
                builder: (_) => const MenuScreen());
        }
      },
    );
  }
}
