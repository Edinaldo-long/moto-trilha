import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/trail_game.dart';
import 'ui/controls_overlay.dart';
import 'ui/game_over_overlay.dart';
import 'ui/level_won_overlay.dart';
import 'ui/menu_overlay.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final game = TrailGame();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepOrange),
      home: Scaffold(
        body: GameWidget<TrailGame>(
          game: game,
          overlayBuilderMap: {
            'menu': (context, g) => MenuOverlay(game: g),
            'controls': (context, g) => ControlsOverlay(game: g),
            'gameover': (context, g) => GameOverOverlay(game: g),
            'won': (context, g) => LevelWonOverlay(game: g),
          },
        ),
      ),
    ),
  );
}
