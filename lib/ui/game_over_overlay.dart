import 'package:flutter/material.dart';

import '../game/trail_game.dart';
import 'panel.dart';

class GameOverOverlay extends StatelessWidget {
  final TrailGame game;
  const GameOverOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) => GamePanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              game.crashReason,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900),
            ),
            if (game.newRecord)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('NOVO RECORDE!',
                    style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5)),
              ),
            const SizedBox(height: 12),
            Text(
              '${game.distance.toStringAsFixed(0)} m',
              style: const TextStyle(
                  color: Colors.deepOrangeAccent,
                  fontSize: 44,
                  fontWeight: FontWeight.w900),
            ),
            Text(
              'Moedas: ${game.coins}   •   Recorde: ${game.best.toStringAsFixed(0)} m',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    game.overlays.remove('gameover');
                    game.overlays.add('menu');
                  },
                  icon: const Icon(Icons.home),
                  label: const Text('CENÁRIOS'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: game.startRun,
                  icon: const Icon(Icons.replay),
                  label: const Text('TENTAR DE NOVO'),
                ),
              ],
            ),
          ],
        ),
      );
}
