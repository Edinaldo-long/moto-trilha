import 'dart:math' as math;

class StuntEvent {
  final String title;
  final int bonusCoins;
  final double adrenalineGain;
  final bool isSpecial;

  StuntEvent({
    required this.title,
    required this.bonusCoins,
    required this.adrenalineGain,
    this.isSpecial = false,
  });
}

class StuntSystem {
  double adrenaline = 25.0; // Inicia com um pouco de adrenalina
  bool turboActive = false;

  double _wheelieDuration = 0.0;
  double _stoppieDuration = 0.0;
  double comboTimer = 0.0;
  double comboMultiplier = 1.0;

  String popMessage = '';
  double popMessageTimer = 0.0;

  void reset() {
    adrenaline = 30.0;
    turboActive = false;
    _wheelieDuration = 0.0;
    _stoppieDuration = 0.0;
    comboTimer = 0.0;
    comboMultiplier = 1.0;
    popMessage = '';
    popMessageTimer = 0.0;
  }

  void addAdrenaline(double amount) {
    adrenaline = (adrenaline + amount).clamp(0.0, 100.0);
  }

  bool canUseTurbo() => adrenaline >= 5.0;

  void setTurbo(bool active) {
    if (active && canUseTurbo()) {
      turboActive = true;
    } else {
      turboActive = false;
    }
  }

  void update({
    required double dt,
    required bool rearContact,
    required bool frontContact,
    required double relAngle,
    required double speedX,
    required void Function(StuntEvent event) onStunt,
  }) {
    if (popMessageTimer > 0) popMessageTimer -= dt;

    if (comboTimer > 0) {
      comboTimer -= dt;
      if (comboTimer <= 0) {
        comboMultiplier = 1.0;
      }
    }

    // Consumo de Turbo
    if (turboActive) {
      adrenaline -= 24.0 * dt;
      if (adrenaline <= 0.0) {
        adrenaline = 0.0;
        turboActive = false;
      }
    }

    // 1. Detecção de WHEELIE (Grau)
    // Apenas roda traseira no chão, moto inclinada para trás
    if (rearContact && !frontContact && relAngle < -0.28 && speedX.abs() > 60.0) {
      _wheelieDuration += dt;
      addAdrenaline(14.0 * dt);

      if (_wheelieDuration >= 0.4 && (_wheelieDuration - dt < 0.4 || (_wheelieDuration % 1.0 < dt))) {
        final secs = _wheelieDuration.toStringAsFixed(1);
        _registerStunt(
          StuntEvent(
            title: 'GRAU! ${secs}s',
            bonusCoins: 1,
            adrenalineGain: 8.0,
          ),
          onStunt,
        );
      }
    } else {
      _wheelieDuration = 0.0;
    }

    // 2. Detecção de STOPPIE (RL / Endo)
    // Apenas roda dianteira no chão, traseira levantada
    if (frontContact && !rearContact && relAngle > 0.22 && speedX.abs() > 40.0) {
      _stoppieDuration += dt;
      addAdrenaline(16.0 * dt);

      if (_stoppieDuration >= 0.35 && (_stoppieDuration - dt < 0.35 || (_stoppieDuration % 1.0 < dt))) {
        final secs = _stoppieDuration.toStringAsFixed(1);
        _registerStunt(
          StuntEvent(
            title: 'STOPPIE! ${secs}s',
            bonusCoins: 2,
            adrenalineGain: 10.0,
          ),
          onStunt,
        );
      }
    } else {
      _stoppieDuration = 0.0;
    }
  }

  void onAirLanding({
    required double airTime,
    required double airRot,
    required double deltaAngleToSlope,
    required void Function(StuntEvent event) onStunt,
  }) {
    // 3. Flips (giros no ar)
    final flips = (airRot.abs() / (2 * math.pi)).round();
    if (flips >= 1) {
      final isBackflip = airRot < 0;
      final name = flips > 1 ? '$flips ${isBackflip ? "BACKFLIPS" : "FRONTFLIPS"}!' : (isBackflip ? 'BACKFLIP!' : 'FRONTFLIP!');
      _registerStunt(
        StuntEvent(
          title: name,
          bonusCoins: flips * 6,
          adrenalineGain: 25.0 * flips,
          isSpecial: true,
        ),
        onStunt,
      );
    }

    // 4. Aterrissagem Perfeita (Clean Landing)
    if (airTime > 0.45 && deltaAngleToSlope.abs() < 0.20) {
      _registerStunt(
        StuntEvent(
          title: 'POUSO PERFEITO!',
          bonusCoins: 3,
          adrenalineGain: 20.0,
          isSpecial: true,
        ),
        onStunt,
      );
    } else if (airTime > 0.8) {
      _registerStunt(
        StuntEvent(
          title: 'BIG AIR! ${(airTime).toStringAsFixed(1)}s',
          bonusCoins: 2,
          adrenalineGain: 12.0,
        ),
        onStunt,
      );
    }
  }

  void _registerStunt(StuntEvent event, void Function(StuntEvent event) onStunt) {
    comboTimer = 2.0;
    comboMultiplier = math.min(3.0, comboMultiplier + 0.3);
    addAdrenaline(event.adrenalineGain);
    popMessage = comboMultiplier > 1.2
        ? '${event.title}  x${comboMultiplier.toStringAsFixed(1)}'
        : event.title;
    popMessageTimer = 1.3;
    onStunt(event);
  }
}
