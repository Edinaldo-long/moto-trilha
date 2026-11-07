import 'package:flutter/material.dart';

import '../game/trail_game.dart';
import '../models/level_def.dart';
import 'panel.dart';

class MenuOverlay extends StatefulWidget {
  final TrailGame game;
  const MenuOverlay({super.key, required this.game});

  @override
  State<MenuOverlay> createState() => _MenuOverlayState();
}

class _MenuOverlayState extends State<MenuOverlay> {
  TrailGame get game => widget.game;

  IconData _getIconForLevel(int idx) {
    switch (idx) {
      case 0:
        return Icons.forest;
      case 1:
        return Icons.add_road; // Rodovia Expressa
      case 2:
        return Icons.wb_sunny;
      case 3:
        return Icons.landscape;
      case 4:
        return Icons.ac_unit;
      case 5:
        return Icons.local_fire_department;
      default:
        return Icons.two_wheeler;
    }
  }

  @override
  Widget build(BuildContext context) => GamePanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.two_wheeler, color: Colors.deepOrange, size: 54),
            const Text(
              'MOTO TRILHA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Acelere, faça manobras e sobreviva aos desafios!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 14),
            Text(
              'Recorde: ${game.best.toStringAsFixed(0)} m   •   Moedas: ${game.totalCoins}',
              style: const TextStyle(
                  color: Colors.amber, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),

            // SELETOR LIVRE DE CENÁRIOS
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0x66000000),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: game.lv.isHighway ? Colors.cyanAccent : Colors.deepOrange,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => setState(() => game.level =
                            (game.level - 1 + kLevels.length) % kLevels.length),
                        icon: const Icon(Icons.chevron_left, size: 32),
                        color: Colors.white,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_getIconForLevel(game.level),
                                    color: game.lv.isHighway
                                        ? Colors.cyanAccent
                                        : Colors.amber,
                                    size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  game.lv.name.toUpperCase(),
                                  style: TextStyle(
                                    color: game.lv.isHighway
                                        ? Colors.cyanAccent
                                        : Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              game.lv.description,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 11),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Meta: ${game.lv.goal} m   •   Cenário ${game.level + 1} de ${kLevels.length}',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() =>
                            game.level = (game.level + 1) % kLevels.length),
                        icon: const Icon(Icons.chevron_right, size: 32),
                        color: Colors.white,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            const Text(
              'COMANDOS\n'
              'D / Direita: Acelera   •   A / Esquerda: Freia\n'
              'W / Cima: Empina   •   S / Baixo: Abaixa a frente\n'
              'Shift / E / Botão Raio: TURBO BOOST (Nitro)\n\n'
              'MANOBRAS & ADRENALINA\n'
              '• Mande GRAU ou STOPPIE para carregar a barra de Turbo!\n'
              '• Na Rodovia, passe raspando nos carros (Near Miss) para bônus!\n'
              '• Mapeie o controle clicando em CONFIGURAR CONTROLE.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: game.startRun,
              icon: const Icon(Icons.play_arrow),
              label: const Text('PILOTAR AGORA'),
              style: FilledButton.styleFrom(
                backgroundColor: game.lv.isHighway ? Colors.cyan : Colors.deepOrange,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: game.startCalibration,
              icon: const Icon(Icons.sports_esports),
              label: const Text('CONFIGURAR CONTROLE'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
            ),
          ],
        ),
      );
}
