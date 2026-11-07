import 'package:flutter/material.dart';

import '../game/trail_game.dart';
import '../models/level_def.dart';
import 'panel.dart';

class LevelWonOverlay extends StatelessWidget {
  final TrailGame game;
  const LevelWonOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final last = game.level + 1 >= kLevels.length;
    return GamePanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            last ? 'VOCÊ ZEROU O JOGO!' : 'FASE CONCLUÍDA!',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'FASE ${game.level + 1}: ${game.lv.name}',
            style: const TextStyle(
                color: Colors.amber, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Moedas: ${game.coins}   •   Total: ${game.totalCoins}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  game.overlays.remove('won');
                  game.overlays.add('menu');
                },
                icon: const Icon(Icons.home),
                label: const Text('CENÁRIOS'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: game.nextLevel,
                icon: Icon(last ? Icons.replay : Icons.skip_next),
                label: Text(last ? 'FASE 1' : 'PRÓXIMA FASE'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
