import 'package:flutter/material.dart';

/// Uma fase: meta de distância, dificuldade, visual e tráfego.
class LevelDef {
  final String name;
  final String description;
  final int goal; // metros para completar
  final double amp; // altura dos morros
  final double bumpP; // chance de pedras/rampas
  final double bumpH; // altura das pedras
  final double fuelGap; // distância entre galões (px)
  final double fuelRate; // consumo de combustível
  final Color skyTop, skyBottom, hillFar, hillNear;
  final Color grass, grassDark, dirtTop, dirtBottom, dirtLight;
  final bool hasTraffic;
  final bool isHighway;

  const LevelDef({
    required this.name,
    required this.goal,
    required this.amp,
    required this.bumpP,
    required this.bumpH,
    required this.fuelGap,
    required this.fuelRate,
    required this.skyTop,
    required this.skyBottom,
    required this.hillFar,
    required this.hillNear,
    required this.grass,
    required this.grassDark,
    required this.dirtTop,
    required this.dirtBottom,
    required this.dirtLight,
    this.hasTraffic = false,
    this.isHighway = false,
    this.description = 'Trilha off-road com relevo e obstáculos naturais.',
  });
}

const kLevels = <LevelDef>[
  LevelDef(
    name: 'Campo Verde',
    goal: 300,
    amp: 0.8,
    bumpP: 0.25,
    bumpH: 0.8,
    fuelGap: 2300,
    fuelRate: 1.0,
    description: 'Trilha natural com morros de terra, grama e saltos suaves.',
    skyTop: Color(0xFF4FB0F2),
    skyBottom: Color(0xFFFFE9B8),
    hillFar: Color(0xFF9DB7C9),
    hillNear: Color(0xFF6E9A78),
    grass: Color(0xFF58A83A),
    grassDark: Color(0xFF3E8A2C),
    dirtTop: Color(0xFF9C6B3B),
    dirtBottom: Color(0xFF4E321A),
    dirtLight: Color(0xFFB88650),
  ),
  LevelDef(
    name: 'Rodovia Expressa',
    goal: 500,
    amp: 0.35,
    bumpP: 0.16,
    bumpH: 0.85,
    fuelGap: 2400,
    fuelRate: 1.05,
    hasTraffic: false,
    isHighway: true,
    description: 'Pista de asfalto veloz e plana com faixas brancas e iluminação.',
    skyTop: Color(0xFF0A0E17),
    skyBottom: Color(0xFF2A1B4E),
    hillFar: Color(0xFF161F30),
    hillNear: Color(0xFF212C3D),
    grass: Color(0xFFFFD54F), // Faixa amarela contínua de asfalto
    grassDark: Color(0xFFE0E0E0), // Faixa branca tracejada
    dirtTop: Color(0xFF263238), // Asfalto escuro
    dirtBottom: Color(0xFF12181B), // Base profunda de piche
    dirtLight: Color(0xFF37474F), // Borda de acostamento
  ),
  LevelDef(
    name: 'Deserto',
    goal: 450,
    amp: 1.0,
    bumpP: 0.32,
    bumpH: 1.0,
    fuelGap: 2500,
    fuelRate: 1.1,
    description: 'Dunas douradas e calor intenso com pouca tração.',
    skyTop: Color(0xFF59A9E0),
    skyBottom: Color(0xFFFFD79A),
    hillFar: Color(0xFFD9B98A),
    hillNear: Color(0xFFC79B63),
    grass: Color(0xFFD8B25A),
    grassDark: Color(0xFFB38A3A),
    dirtTop: Color(0xFFD8A862),
    dirtBottom: Color(0xFF8A5E2E),
    dirtLight: Color(0xFFE8C37E),
  ),
  LevelDef(
    name: 'Entardecer',
    goal: 600,
    amp: 1.2,
    bumpP: 0.38,
    bumpH: 1.15,
    fuelGap: 2700,
    fuelRate: 1.2,
    description: 'Cânions avermelhados com rampas desafiadoras.',
    skyTop: Color(0xFF5B3A8C),
    skyBottom: Color(0xFFFF9A5A),
    hillFar: Color(0xFF7A5C96),
    hillNear: Color(0xFF4F3A6B),
    grass: Color(0xFF6E8E2F),
    grassDark: Color(0xFF4F6E1F),
    dirtTop: Color(0xFF8A5A3A),
    dirtBottom: Color(0xFF3F2616),
    dirtLight: Color(0xFFA8734A),
  ),
  LevelDef(
    name: 'Montanha Gelada',
    goal: 800,
    amp: 1.4,
    bumpP: 0.45,
    bumpH: 1.3,
    fuelGap: 2900,
    fuelRate: 1.3,
    description: 'Pistas de gelo e neve com declives escorregadios.',
    skyTop: Color(0xFF8FB8DE),
    skyBottom: Color(0xFFEAF3FA),
    hillFar: Color(0xFFC4D6E8),
    hillNear: Color(0xFFA9C2DA),
    grass: Color(0xFFF4F8FC),
    grassDark: Color(0xFFC9D8E6),
    dirtTop: Color(0xFF8F9BA8),
    dirtBottom: Color(0xFF4E5865),
    dirtLight: Color(0xFFB3BEC9),
  ),
  LevelDef(
    name: 'Vulcão',
    goal: 1000,
    amp: 1.6,
    bumpP: 0.5,
    bumpH: 1.45,
    fuelGap: 3100,
    fuelRate: 1.4,
    description: 'Trilha vulcânica extrema entre rochas escuras e magma.',
    skyTop: Color(0xFF2B0F1E),
    skyBottom: Color(0xFFFF5A2A),
    hillFar: Color(0xFF4A2030),
    hillNear: Color(0xFF331018),
    grass: Color(0xFF5A3A32),
    grassDark: Color(0xFF2E1B18),
    dirtTop: Color(0xFF5A2B1E),
    dirtBottom: Color(0xFF1E0D0A),
    dirtLight: Color(0xFF7A3B26),
  ),
];
