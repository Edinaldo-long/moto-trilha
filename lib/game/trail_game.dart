import 'dart:async';
import 'dart:math' as math;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamepads/gamepads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../effects/camera_shaker.dart';
import '../effects/game_audio.dart';
import '../effects/game_haptics.dart';
import '../effects/trail_particle_system.dart';
import '../models/bump.dart';
import '../models/collectibles.dart';
import '../models/game_phase.dart';
import '../models/level_def.dart';
import '../models/terrain.dart';
import '../systems/stunt_system.dart';

class TrailGame extends FlameGame with KeyboardEvents {
  final math.Random _rnd = math.Random();
  late Terrain terrain;
  Phase phase = Phase.menu;
  int level = 0, unlocked = 0;
  LevelDef get lv => kLevels[level];

  // Entradas do jogador
  bool gas = false, brake = false, leanBack = false, leanFwd = false;
  bool turboPressed = false;

  // Controle (gamepad)
  StreamSubscription? _padSub, _rawSub;
  final Set<GamepadButton> _held = {};
  final Set<int> _rawHeld = {};
  bool _gotNormalized = false;
  double _ax = 0, _ay = 0, _lt = 0, _rt = 0;

  // Configuração (calibração) dos botões do controle
  bool calibrating = false;
  int _calStep = 0;
  bool _calWait = true;
  String lastRaw = '';
  final Map<String, String> _calKeys = {};
  final Set<String> _calHeld = {};
  static const calActions = ['gas', 'brake', 'leanBack', 'leanFwd', 'turbo'];
  static const calLabels = [
    'ACELERAR',
    'FREAR',
    'EMPINAR',
    'ABAIXAR A FRENTE',
    'TURBO (ADRENALINA)'
  ];

  // Estado da Moto
  double px = 100, py = 0, vx = 0, vy = 0, ang = 0, angVel = 0, wheelRot = 0;
  int contactsCount = 0;
  double _airTime = 0, _airRot = 0;
  bool _wasInAir = false;

  // Suspensão Reativa & Cinemática
  double suspRear = 0.0, suspFront = 0.0;
  double targetSuspRear = 0.0, targetSuspFront = 0.0;
  bool rearContact = false, frontContact = false;
  double rearPen = 0.0, frontPen = 0.0;
  double groundAngle = 0.0;

  // Subsistemas de Efeitos e Adrenalina
  final CameraShaker cameraShaker = CameraShaker();
  final TrailParticleSystem particleSystem = TrailParticleSystem();
  final StuntSystem stuntSystem = StuntSystem();

  // Status de Corrida
  double distance = 0, best = 0, fuel = 100;
  int coins = 0, totalCoins = 0;
  bool newRecord = false;
  String crashReason = '';

  // Mundo
  final List<Coin> coinList = [];
  final List<FuelCan> cans = [];
  double _spawnX = 0, _nextCanX = 0;

  // Câmera estável e suave
  double camX = 0, camY = 0, time = 0;
  bool _camInit = false;
  String _popText = '';
  double _popTimer = 0;

  // Ragdoll do Piloto na Queda
  bool riderEjected = false;
  double gx = 0, gy = 0, gvx = 0, gvy = 0, gAng = 0, gAngV = 0;
  double _crashTimer = 0;

  // Escala sólida e estável: zero oscilação ou efeito de tela travando
  double get zoom => (size.y / 650).clamp(0.75, 1.5).toDouble();

  double get _dusk => (distance / lv.goal).clamp(0.0, 1.0).toDouble() * 0.7;

  // ---------- ciclo de vida ----------
  @override
  Future<void> onLoad() async {
    try {
      await GameAudio.init();
      final p = await SharedPreferences.getInstance();
      best = p.getDouble('best') ?? 0;
      totalCoins = p.getInt('totalCoins') ?? 0;
      unlocked = (p.getInt('unlocked') ?? 0).clamp(0, kLevels.length - 1).toInt();
      level = unlocked;
      final cal = p.getStringList('cal3') ?? p.getStringList('cal2');
      if (cal != null) {
        for (var i = 0; i < cal.length && i < calActions.length; i++) {
          _calKeys[calActions[i]] = cal[i];
        }
      }
    } catch (_) {}
    _reset();
    overlays.add('menu');
    _initPad();
  }

  @override
  void onRemove() {
    _padSub?.cancel();
    _rawSub?.cancel();
    super.onRemove();
  }

  void _reset() {
    terrain = Terrain(_rnd, lv.amp);
    coinList.clear();
    cans.clear();
    particleSystem.clear();
    stuntSystem.reset();
    px = 100;
    py = terrain.y(px) - 32;
    vx = vy = ang = angVel = wheelRot = 0;
    suspRear = suspFront = targetSuspRear = targetSuspFront = 0;
    rearContact = frontContact = false;
    rearPen = frontPen = groundAngle = 0;
    distance = 0;
    coins = 0;
    fuel = 100;
    _airTime = 0;
    _airRot = 0;
    _wasInAir = false;
    contactsCount = 0;
    _popTimer = 0;
    riderEjected = false;
    newRecord = false;
    gas = brake = leanBack = leanFwd = turboPressed = false;
    _spawnX = 500;
    _nextCanX = lv.fuelGap * 0.9;
    _camInit = false;
    _spawnAhead();
  }

  void startRun() {
    _reset();
    phase = Phase.playing;
    overlays.remove('menu');
    overlays.remove('gameover');
    overlays.remove('won');
    overlays.add('controls');
    _popText = 'FASE ${level + 1}: ${lv.name}';
    _popTimer = 1.6;
  }

  void nextLevel() {
    level = (level + 1 < kLevels.length) ? level + 1 : 0;
    startRun();
  }

  void _go() {
    if (phase == Phase.won) {
      nextLevel();
    } else {
      startRun();
    }
  }

  void _win() {
    phase = Phase.won;
    riderEjected = false;
    totalCoins += coins;
    best = math.max(best, distance);
    if (level + 1 < kLevels.length && level + 1 > unlocked) unlocked = level + 1;
    _save();
    overlays.remove('controls');
    gas = brake = leanBack = leanFwd = turboPressed = false;
    _crashTimer = 1.2;
    particleSystem.emitGenericBurst(
        x: px, y: py - 40, count: 40, color: const Color(0xFFFFD54F), speed: 260);
    GameAudio.playTrick();
    GameHaptics.impact(350);
    _popText = 'FASE CONCLUÍDA!';
    _popTimer = 1.6;
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble('best', best);
      await p.setInt('totalCoins', totalCoins);
      await p.setInt('unlocked', unlocked);
    } catch (_) {}
  }

  void setTurbo(bool active) {
    turboPressed = active;
    if (phase != Phase.playing) return;
    if (active && stuntSystem.canUseTurbo() && !stuntSystem.turboActive) {
      GameAudio.playBoost();
      GameHaptics.boost();
    }
    stuntSystem.setTurbo(active);
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (calibrating) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        calibrating = false;
        overlays.add('menu');
      }
      return KeyEventResult.handled;
    }
    final playing = phase == Phase.playing;
    gas = playing &&
        (keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
            keysPressed.contains(LogicalKeyboardKey.keyD));
    brake = playing &&
        (keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
            keysPressed.contains(LogicalKeyboardKey.keyA));
    leanBack = playing &&
        (keysPressed.contains(LogicalKeyboardKey.arrowUp) ||
            keysPressed.contains(LogicalKeyboardKey.keyW));
    leanFwd = playing &&
        (keysPressed.contains(LogicalKeyboardKey.arrowDown) ||
            keysPressed.contains(LogicalKeyboardKey.keyS));

    final turbo = playing &&
        (keysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
            keysPressed.contains(LogicalKeyboardKey.shiftRight) ||
            keysPressed.contains(LogicalKeyboardKey.keyE));
    setTurbo(turbo);

    final canStart = phase == Phase.menu ||
        ((phase == Phase.crashed || phase == Phase.won) && _crashTimer <= 0);
    if (canStart &&
        event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.enter)) {
      _go();
    }
    return KeyEventResult.handled;
  }

  // ---------- controle (gamepad) ----------
  void _initPad() {
    try {
      _padSub = Gamepads.normalizedEvents.listen(_onPad);
      _rawSub = Gamepads.events.listen(_onRaw);
    } catch (e) {
      debugPrint('Gamepad indisponível: $e');
    }
  }

  void _onPad(NormalizedGamepadEvent e) {
    _gotNormalized = true;
    if (calibrating || _calKeys.length >= calActions.length) return;
    final b = e.button;
    if (b != null && !calibrating && _calKeys.length < calActions.length) {
      if (e.value > 0.5) {
        _held.add(b);
        if (b == GamepadButton.a || b == GamepadButton.start) _padStart();
      } else {
        _held.remove(b);
      }
    }
    final a = e.axis;
    if (a == GamepadAxis.leftStickX) _ax = e.value;
    if (a == GamepadAxis.leftStickY) _ay = e.value;
    if (a == GamepadAxis.leftTrigger) _lt = e.value;
    if (a == GamepadAxis.rightTrigger) _rt = e.value;
    _applyPad();
  }

  void _onRaw(GamepadEvent e) {
    lastRaw = '${e.key} = ${e.value}';
    final on = e.value.abs() > 0.5;

    if (calibrating) {
      if (!on) {
        _calWait = false;
        return;
      }
      final id = '${e.key}|${e.value > 0 ? '+' : '-'}';
      if (_calWait || _calKeys.containsValue(id)) return;
      _calKeys[calActions[_calStep]] = id;
      _calStep++;
      _calWait = true;
      if (_calStep >= calActions.length) {
        calibrating = false;
        _saveCal();
        overlays.add('menu');
      }
      return;
    }

    if (_calKeys.length >= calActions.length) {
      final plus = '${e.key}|+', minus = '${e.key}|-';
      if (on) {
        final id = e.value > 0 ? plus : minus;
        _calHeld.add(id);
        _calHeld.remove(e.value > 0 ? minus : plus);
        if (id == _calKeys['gas']) _padStart();
      } else {
        _calHeld.remove(plus);
        _calHeld.remove(minus);
      }
      _applyPad();
      return;
    }

    if (_gotNormalized) return;
    final m = RegExp(r'\d+').firstMatch(e.key);
    if (m == null) return;
    final idx = int.parse(m.group(0)!);
    if (e.type.toString().toLowerCase().contains('button')) {
      final on = e.value > 0.5;
      if (on) {
        _rawHeld.add(idx);
        if (idx == 0 || idx == 7 || idx == 9) _padStart();
      } else {
        _rawHeld.remove(idx);
      }
    } else {
      var v = e.value.toDouble();
      if (v.abs() > 1.5) v /= 32767;
      if (idx == 0) _ax = v;
      if (idx == 1) _ay = v;
    }
    _applyPad();
  }

  void _padStart() {
    final canStart = phase == Phase.menu ||
        ((phase == Phase.crashed || phase == Phase.won) && _crashTimer <= 0);
    if (canStart && !calibrating) _go();
  }

  void startCalibration() {
    calibrating = true;
    _calStep = 0;
    _calWait = true;
    _calKeys.clear();
    _calHeld.clear();
    _ax = _ay = _lt = _rt = 0;
    overlays.remove('menu');
  }

  Future<void> _saveCal() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList('cal3', [for (final a in calActions) _calKeys[a] ?? '']);
    } catch (_) {}
  }

  void _applyPad() {
    if (phase != Phase.playing) return;
    final cal = _calKeys.length >= 4;
    bool h(String a) => cal && _calHeld.contains(_calKeys[a]);

    gas = (cal && _calKeys.containsKey('gas'))
        ? h('gas')
        : (_held.contains(GamepadButton.a) ||
            _rawHeld.contains(0) ||
            _rt > 0.3 ||
            _ax > 0.5);
    brake = (cal && _calKeys.containsKey('brake'))
        ? h('brake')
        : (_held.contains(GamepadButton.b) ||
            _rawHeld.contains(1) ||
            _lt > 0.3 ||
            _ax < -0.5);
    leanBack = (cal && _calKeys.containsKey('leanBack'))
        ? h('leanBack')
        : (_held.contains(GamepadButton.x) ||
            _held.contains(GamepadButton.leftBumper) ||
            _held.contains(GamepadButton.dpadUp) ||
            _rawHeld.contains(2) ||
            _rawHeld.contains(4) ||
            _ay < -0.5);
    leanFwd = (cal && _calKeys.containsKey('leanFwd'))
        ? h('leanFwd')
        : (_held.contains(GamepadButton.y) ||
            _held.contains(GamepadButton.dpadDown) ||
            _rawHeld.contains(3) ||
            _rawHeld.contains(5) ||
            _ay > 0.5);

    final padTurbo = (cal && _calKeys.containsKey('turbo'))
        ? h('turbo')
        : (_held.contains(GamepadButton.rightBumper) ||
            _rt > 0.85 ||
            _rawHeld.contains(5));
    setTurbo(turboPressed || padTurbo);
  }

  // ---------- geração do mundo ----------
  void _spawnAhead() {
    while (_spawnX < px + 2600) {
      final x = _spawnX;
      final dif = (x / 15000).clamp(0.0, 1.0).toDouble();
      _spawnX += 240 + _rnd.nextDouble() * 220;

      if (x >= _nextCanX) {
        cans.add(FuelCan(x, terrain.y(x) - 50));
        _nextCanX = x + lv.fuelGap + _rnd.nextDouble() * 900;
        continue;
      }
      final r = _rnd.nextDouble();
      if (r < lv.bumpP + dif * 0.2) {
        final h = (16 + _rnd.nextDouble() * (18 + dif * 16)) * lv.bumpH;
        final w = 38 + _rnd.nextDouble() * 34;
        terrain.bumps.add(Bump(x, h, w));
        if (_rnd.nextDouble() < 0.75) _coinArc(x - 100, 6, 50);
      } else if (r < 0.75) {
        _coinArc(x, 3 + _rnd.nextInt(4), 0);
      }
    }
  }

  void _coinArc(double x0, int n, double lift) {
    for (var i = 0; i < n; i++) {
      final x = x0 + i * 40;
      final t = n > 1 ? i / (n - 1) : 0.0;
      final y = terrain.y(x) - 48 - lift * math.sin(math.pi * t);
      coinList.add(Coin(x, y, i * 0.6));
    }
  }

  void _cull() {
    coinList.removeWhere((c) => c.x < px - 700);
    cans.removeWhere((c) => c.x < px - 700);
    terrain.bumps.removeWhere((b) => b.x < px - 1500);
  }

  // ---------- física avançada com suspensão ----------
  void _step(double dt) {
    const g = 900.0, L = 32.0, R = 18.0;
    const k = 1600.0, c = 95.0, inertia = 1800.0;
    final maxSpeed = stuntSystem.turboActive ? 980.0 : 680.0;

    final alive = phase == Phase.playing;
    final drive = alive && gas && fuel > 0;
    final braking = alive && brake;
    final vyBefore = vy;

    double ax = 0, ay = g, torque = 0, groundAngSum = 0;
    int contacts = 0;
    final ca = math.cos(ang), sa = math.sin(ang);

    rearContact = false;
    frontContact = false;
    rearPen = 0.0;
    frontPen = 0.0;

    for (final s in const [-1.0, 1.0]) {
      final isRear = s < 0;
      final lx = s * L, ly = 14.0;
      final ox = lx * ca - ly * sa;
      final oy = lx * sa + ly * ca;
      final wx = px + ox, wy = py + oy;
      final pen = wy + R - terrain.y(wx);

      if (pen <= 0) continue;
      contacts++;

      if (isRear) {
        rearContact = true;
        rearPen = pen;
      } else {
        frontContact = true;
        frontPen = pen;
      }

      final slope = terrain.slope(wx);
      groundAngSum += math.atan(slope);
      final inv = 1 / math.sqrt(slope * slope + 1);
      final nx = slope * inv, ny = -inv; // normal (para cima)
      final tx = inv, ty = slope * inv; // tangente (para frente)

      final wvx = vx - angVel * oy;
      final wvy = vy + angVel * ox;
      final vn = wvx * nx + wvy * ny;
      final vt = wvx * tx + wvy * ty;

      final cc = vn < 0 ? c : 420.0;
      final fn = (k * pen - cc * vn).clamp(0.0, 6500.0).toDouble();

      double ft = -vt * 0.12;
      if (drive && vt < maxSpeed) {
        ft += stuntSystem.turboActive ? 1050.0 : 640.0;
      }
      if (braking) ft += -vt * 6.5;

      final fnx = nx * fn, fny = ny * fn;
      final ftx = tx * ft, fty = ty * ft;
      ax += fnx + ftx;
      ay += fny + fty;
      torque += ox * fny - oy * fnx;
      torque += ox * fty - oy * 0.3 * ftx;
    }

    groundAngle = contacts > 0 ? (groundAngSum / contacts) : 0.0;

    // Dinâmica de Suspensão (Alvos e Visco-elasticidade)
    final squat = (drive ? 2.5 : 0.0) + (stuntSystem.turboActive ? 3.5 : 0.0);
    final dive = (braking ? 4.0 : 0.0);
    targetSuspRear = (rearContact ? (rearPen * 0.85 + squat) : -3.0).clamp(-3.0, 13.0);
    targetSuspFront = (frontContact ? (frontPen * 0.85 + dive) : -3.0).clamp(-3.0, 13.0);

    final rearRate = (targetSuspRear > suspRear) ? 36.0 : 16.0;
    final frontRate = (targetSuspFront > suspFront) ? 36.0 : 16.0;
    suspRear += (targetSuspRear - suspRear) * math.min(1.0, rearRate * dt);
    suspFront += (targetSuspFront - suspFront) * math.min(1.0, frontRate * dt);

    if (alive) {
      final lean = contacts == 0 ? 9200.0 : 11500.0;
      if (leanBack) torque -= lean;
      if (leanFwd) torque += lean;

      if (contacts > 0) {
        var diff = groundAngle - ang;
        diff = math.atan2(math.sin(diff), math.cos(diff));
        final stab = (leanBack != leanFwd) ? 0.35 : 1.0;
        torque += diff * (contacts == 2 ? 9000.0 : 2500.0) * stab;
      }
    }

    vx += ax * dt;
    vy += ay * dt;
    final maxSpeedClamp = stuntSystem.turboActive ? 1250.0 : 1100.0;
    vx = vx.clamp(-maxSpeedClamp, maxSpeedClamp).toDouble();
    angVel += torque / inertia * dt;
    angVel *= math.exp(-(contacts > 0 ? 2.0 : 0.5) * dt);
    angVel = angVel.clamp(-9.0, 9.0).toDouble();
    px += vx * dt;
    py += vy * dt;
    ang += angVel * dt;
    wheelRot += (vx / R) * dt;
    contactsCount = contacts;

    if (!alive) return;

    // Cabeça do piloto bateu no chão = queda
    final ca2 = math.cos(ang), sa2 = math.sin(ang);
    const hx0 = 6.0, hy0 = -39.0;
    final hx = px + hx0 * ca2 - hy0 * sa2;
    final hy = py + hx0 * sa2 + hy0 * ca2;
    if (hy + 8 > terrain.y(hx)) {
      _crash('Você caiu!');
      return;
    }

    // Raspagem do chassi em pedras/terreno gera faíscas
    final chassisBottomY = py + 18;
    if (chassisBottomY > terrain.y(px) - 2 && vx.abs() > 150) {
      particleSystem.emitSparks(x: px, y: chassisBottomY, vx: vx, count: 2);
      GameHaptics.impact(180);
    }

    // Tempo no ar, saltos e aterrissagem
    if (contacts == 0) {
      _airTime += dt;
      _airRot += angVel * dt;
      _wasInAir = true;
    } else {
      if (_wasInAir && _airTime > 0.25) {
        final impact = vyBefore.abs();
        if (impact > 220) {
          // Solavanco rápido e vertical suave, sem tontura
          final traumaAmt = (impact / 1200.0).clamp(0.12, 0.35);
          cameraShaker.addTrauma(traumaAmt);
          GameHaptics.impact(impact);
          GameAudio.playLand(impact);

          // Efeito de impacto no solo (poeira bilateral)
          particleSystem.emitLandingShockwave(
            x: px,
            y: py + 22,
            color: lv.dirtLight,
            count: (impact > 450 ? 20 : 12),
          );
        }

        // Avaliação de manobras de salto
        final deltaAngleToSlope = (ang - groundAngle);
        stuntSystem.onAirLanding(
          airTime: _airTime,
          airRot: _airRot,
          deltaAngleToSlope: deltaAngleToSlope,
          onStunt: (stunt) {
            coins += stunt.bonusCoins;
            GameAudio.playTrick();
            GameHaptics.boost();
          },
        );
      }
      _airTime = 0;
      _airRot = 0;
      _wasInAir = false;
    }

    // Avaliação contínua de manobras de solo (Grau / Stoppie)
    stuntSystem.update(
      dt: dt,
      rearContact: rearContact,
      frontContact: frontContact,
      relAngle: ang - groundAngle,
      speedX: vx,
      onStunt: (stunt) {
        coins += stunt.bonusCoins;
        GameHaptics.coin();
      },
    );
  }

  void _crash(String reason, {bool eject = true}) {
    phase = Phase.crashed;
    crashReason = reason;
    riderEjected = eject;
    newRecord = distance > best && distance > 10;
    best = math.max(best, distance);
    totalCoins += coins;
    _save();
    overlays.remove('controls');
    gas = brake = leanBack = leanFwd = turboPressed = false;
    stuntSystem.turboActive = false;
    _crashTimer = eject ? 1.3 : 0.6;

    // SOM, VIBRAÇÃO E IMPACTO CONTROLADO NA BATIDA
    GameAudio.playCrash();
    GameHaptics.crash();
    cameraShaker.addTrauma(0.5);

    if (eject) {
      final ca = math.cos(ang), sa = math.sin(ang);
      gx = px + 6 * ca + 30 * sa;
      gy = py + 6 * sa - 30 * ca;
      gvx = vx * 0.9 + 80;
      gvy = vy - 240;
      gAng = ang;
      gAngV = vx >= 0 ? 6 : -6;
      particleSystem.emitGenericBurst(
        x: gx,
        y: gy,
        count: 32,
        color: const Color(0xFFFF7043),
        speed: 240,
      );
      particleSystem.emitSparks(x: gx, y: gy, vx: gvx, count: 18);
    }
  }

  void _stepRagdoll(double dt) {
    if (!riderEjected) return;
    gvy += 900 * dt;
    gx += gvx * dt;
    gy += gvy * dt;
    gAng += gAngV * dt;
    final floor = terrain.y(gx) - 22;
    if (gy > floor) {
      gy = floor;
      if (gvy > 0) {
        gvy = -gvy * 0.35;
        particleSystem.emitLandingShockwave(x: gx, y: gy, color: lv.dirtTop, count: 6);
      }
      gvx *= math.exp(-4 * dt);
      gAngV *= math.exp(-3 * dt);
    }
  }

  void _consumeFuel(double dt) {
    final rate = (stuntSystem.turboActive ? 8.5 : (gas ? 5.5 : 1.0)) * lv.fuelRate * dt;
    fuel -= rate;
    if (fuel <= 0) {
      fuel = 0;
      if (vx.abs() < 20 && contactsCount > 0) {
        _crash('Sem combustível!', eject: false);
      }
    }
  }

  void _collect() {
    for (final c in coinList) {
      if (c.taken) continue;
      final dx = c.x - px, dy = c.y - (py - 6);
      if (dx * dx + dy * dy < 46 * 46) {
        c.taken = true;
        coins++;
        stuntSystem.addAdrenaline(4.0);
        GameAudio.playCoin();
        GameHaptics.coin();
        particleSystem.emitGenericBurst(
          x: c.x,
          y: c.y,
          count: 8,
          color: const Color(0xFFFFD54F),
          speed: 100,
        );
      }
    }
    for (final f in cans) {
      if (f.taken) continue;
      final dx = f.x - px, dy = f.y - (py - 6);
      if (dx * dx + dy * dy < 52 * 52) {
        f.taken = true;
        fuel = 100;
        stuntSystem.addAdrenaline(40.0);
        GameAudio.playFuel();
        GameHaptics.boost();
        _popText = 'COMBUSTÍVEL CHEIO!';
        _popTimer = 1.2;
        particleSystem.emitGenericBurst(
          x: f.x,
          y: f.y,
          count: 18,
          color: const Color(0xFFFF5252),
          speed: 150,
        );
      }
    }
  }

  // ---------- emissão contínua de partículas ----------
  void _emitParticles() {
    if (phase != Phase.playing) return;

    final ca = math.cos(ang), sa = math.sin(ang);
    final rearAxleX = px - 32 * ca - (14 - suspRear) * sa;
    final rearAxleY = py - 32 * sa + (14 - suspRear) * ca;

    // 1. Terra e Cascalho espirrando (Roost)
    if (rearContact && gas && fuel > 0 && vx.abs() > 60) {
      final intensity = stuntSystem.turboActive ? 5 : 2;
      particleSystem.emitRoost(
        x: rearAxleX,
        y: rearAxleY + 16,
        vx: vx,
        vy: vy,
        color: lv.dirtLight,
        count: intensity,
      );
    }

    // 2. Fumaça de Pneu / Burnout
    if (rearContact && (brake || (gas && vx.abs() < 120))) {
      particleSystem.emitBurnout(x: rearAxleX, y: rearAxleY + 16, count: 1);
    }

    // 3. Chamas e Fogo do Turbo no Escapamento (sem chacoalhar tela)
    if (stuntSystem.turboActive) {
      final exhX = px - 38 * ca - 4 * sa;
      final exhY = py - 38 * sa + 4 * ca;
      particleSystem.emitTurboFlame(
        x: exhX,
        y: exhY,
        dirX: -ca,
        dirY: -sa,
        count: 3,
      );
    }
  }

  // ---------- ciclo de atualização ----------
  @override
  void update(double dt) {
    super.update(dt);
    if (size.x <= 0) return;
    dt = math.min(dt, 1 / 30);
    time += dt;

    cameraShaker.update(dt);

    if (phase == Phase.playing) {
      const sub = 6;
      for (var i = 0; i < sub; i++) {
        _step(dt / sub);
        if (phase != Phase.playing) break;
      }
      if (phase == Phase.playing) {
        distance = math.max(distance, (px - 100) / 50);
        if (distance >= lv.goal) _win();
        _consumeFuel(dt);
        _collect();
        _spawnAhead();
        _cull();
        _emitParticles();
      }
    } else if (phase == Phase.crashed || phase == Phase.won) {
      for (var i = 0; i < 6; i++) {
        _step(dt / 6);
      }
      _stepRagdoll(dt);
      if (_crashTimer > 0) {
        _crashTimer -= dt;
        if (_crashTimer <= 0) {
          overlays.add(phase == Phase.won ? 'won' : 'gameover');
        }
      }
    }

    particleSystem.update(dt);
    if (_popTimer > 0) _popTimer -= dt;
    _updateCamera(dt);
  }

  void _updateCamera(double dt) {
    final z = zoom;
    final vw = size.x / z, vh = size.y / z;
    final tx = px - vw * 0.32;
    final ty = py - vh * 0.58;
    if (!_camInit) {
      camX = tx;
      camY = ty;
      _camInit = true;
      return;
    }
    camX += (tx - camX) * math.min(1.0, 10 * dt);
    camY += (ty - camY) * math.min(1.0, 6 * dt);
  }

  // ============================================================
  //  RENDERIZAÇÃO
  // ============================================================
  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _text(Canvas canvas, String s, Offset pos,
      {double fs = 16,
      Color color = Colors.white,
      FontWeight w = FontWeight.w700,
      bool center = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: color,
          fontSize: fs,
          fontWeight: w,
          shadows: const [
            Shadow(blurRadius: 4, color: Colors.black87, offset: Offset(0, 2)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center ? pos - Offset(tp.width / 2, 0) : pos);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (size.x <= 0) return;
    final z = zoom;
    final vw = size.x / z, vh = size.y / z;

    canvas.save();
    canvas.scale(z);

    // Céu e montanhas de fundo
    _drawSky(canvas, vw, vh);
    _drawHills(canvas, vw, vh, 0.12, 0.50, 38, lv.hillFar, 0.0022, 0.0061);
    _drawHills(canvas, vw, vh, 0.30, 0.62, 30, lv.hillNear, 0.0030, 0.0083);

    _drawTerrain(canvas, vw, vh);
    _drawRocks(canvas, vw);
    _drawItems(canvas, vw);

    particleSystem.render(canvas, camX, camY);

    _drawBike(canvas, px - camX, py - camY,
        !(phase == Phase.crashed && riderEjected));
    if (phase == Phase.crashed && riderEjected) _drawRagdoll(canvas);

    canvas.restore();

    _drawHud(canvas);

    if (calibrating && _calStep < calLabels.length) {
      _drawCalibration(canvas);
    }
  }

  void _drawSky(Canvas canvas, double vw, double vh) {
    final t = _dusk;
    final top = lv.skyTop;
    final bottom = lv.skyBottom;
    final rect = Rect.fromLTWH(0, 0, vw, vh);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(rect),
    );

    // Sol
    final sun = Offset(vw * 0.78, vh * 0.2 + t * vh * 0.25);
    canvas.drawCircle(sun, 62, Paint()..color = const Color(0x33FFF3B0));
    canvas.drawCircle(
        sun,
        36,
        Paint()
          ..color = Color.lerp(
              const Color(0xFFFFF3B0), const Color(0xFFFF7A3D), t)!);

    // Nuvens
    final cloud = Paint()..color = const Color.fromRGBO(255, 255, 255, 0.75);
    final par = camX * 0.12;
    final first = (par / 340).floor() - 1;
    final count = (vw / 340).ceil() + 3;
    for (var i = first; i < first + count; i++) {
      final cx = i * 340.0 - par + 60 * math.sin(i * 2.3);
      final cy = vh * 0.12 + 40 * (math.sin(i * 1.7) + 1);
      final s = 0.8 + 0.3 * math.sin(i * 3.1).abs();
      canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, cy), width: 90 * s, height: 26 * s),
          cloud);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(cx + 18 * s, cy - 10 * s),
              width: 56 * s,
              height: 26 * s),
          cloud);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(cx - 22 * s, cy - 5 * s),
              width: 44 * s,
              height: 20 * s),
          cloud);
    }
  }

  void _drawHills(Canvas canvas, double vw, double vh, double par,
      double baseFrac, double amp, Color color, double f1, double f2) {
    final path = Path()..moveTo(0, vh);
    for (double sx = 0; sx <= vw + 10; sx += 10) {
      final wx = camX * par + sx;
      final y = vh * baseFrac -
          camY * par * 0.4 -
          math.sin(wx * f1) * amp -
          math.sin(wx * f2) * amp * 0.4;
      path.lineTo(sx, y);
    }
    path.lineTo(vw + 10, vh);
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawTerrain(Canvas canvas, double vw, double vh) {
    final fill = Path()..moveTo(-10, vh + 40);
    final top = Path();
    var first = true;
    for (double sx = -10; sx <= vw + 14; sx += 7) {
      final sy = terrain.y(camX + sx) - camY;
      fill.lineTo(sx, sy);
      if (first) {
        top.moveTo(sx, sy);
        first = false;
      } else {
        top.lineTo(sx, sy);
      }
    }
    fill.lineTo(vw + 14, vh + 40);
    fill.close();

    final rect = Rect.fromLTRB(0, vh * 0.4, vw, vh);
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lv.dirtTop, lv.dirtBottom],
        ).createShader(rect),
    );

    canvas.save();
    canvas.translate(0, 12);
    canvas.drawPath(top, _stroke(lv.dirtLight, 24));
    canvas.restore();
    canvas.drawPath(top, _stroke(lv.grass, 9));

    if (lv.isHighway) {
      // Faixas brancas tracejadas e iluminação na rodovia
      final dashPaint = _stroke(Colors.white.withAlpha(220), 3.0);
      final startDash = (camX / 48).floor() * 48.0;
      for (double wx = startDash; wx < camX + vw + 48; wx += 48) {
        final sx1 = wx - camX;
        final sy1 = terrain.y(wx) - camY + 8;
        final sx2 = sx1 + 24;
        final sy2 = terrain.y(wx + 24) - camY + 8;
        canvas.drawLine(Offset(sx1, sy1), Offset(sx2, sy2), dashPaint);
      }

      // Postes de iluminação noturna ao longo da pista
      final polePaint = _stroke(const Color(0xFF78909C), 3.0);
      final lightPaint = Paint()..color = const Color(0xFFFFF176);
      final poleStart = (camX / 260).floor() * 260.0;
      for (double wx = poleStart; wx < camX + vw + 260; wx += 260) {
        final sx = wx - camX;
        final groundY = terrain.y(wx) - camY;
        canvas.drawLine(Offset(sx, groundY), Offset(sx, groundY - 65), polePaint);
        canvas.drawLine(Offset(sx, groundY - 65), Offset(sx + 16, groundY - 67), polePaint);
        canvas.drawCircle(Offset(sx + 16, groundY - 65), 4.5, lightPaint);
      }
    } else {
      // Tufos de grama tradicionais das trilhas
      final grassPaint = _stroke(lv.grassDark, 2.5);
      final startX = (camX / 36).floor() * 36.0;
      for (double wx = startX; wx < camX + vw + 36; wx += 36) {
        final h = 5 + 4 * math.sin(wx * 12.9898).abs();
        final sy = terrain.y(wx) - camY - 3;
        final sx = wx - camX;
        canvas.drawLine(Offset(sx, sy), Offset(sx - 3, sy - h), grassPaint);
        canvas.drawLine(Offset(sx, sy), Offset(sx + 3, sy - h * 0.8), grassPaint);
      }
    }
  }

  void _drawRocks(Canvas canvas, double vw) {
    final fill = Paint()..color = const Color(0xFF8E9196);
    final edge = _stroke(const Color(0xFF5E6166), 2);
    final cap = _stroke(const Color(0xFFA5A9AE), 8);
    for (final b in terrain.bumps) {
      final x0 = b.x - 1.9 * b.w, x1 = b.x + 1.9 * b.w;
      if (x1 < camX - 20 || x0 > camX + vw + 20) continue;

      final topPts = <Offset>[];
      for (double wx = x0; wx <= x1; wx += 6) {
        topPts.add(Offset(wx - camX, terrain.y(wx) - camY));
      }
      final poly = Path()..moveTo(topPts.first.dx, terrain.base(x0) - camY);
      final topPath = Path()..moveTo(topPts.first.dx, topPts.first.dy);
      for (final p in topPts) {
        poly.lineTo(p.dx, p.dy);
        topPath.lineTo(p.dx, p.dy);
      }
      for (double wx = x1; wx >= x0; wx -= 6) {
        poly.lineTo(wx - camX, terrain.base(wx) - camY);
      }
      poly.close();

      canvas.drawPath(poly, fill);
      canvas.drawPath(topPath, cap);
      canvas.drawPath(poly, edge);
    }
  }

  void _drawItems(Canvas canvas, double vw) {
    final gold = Paint()..color = const Color(0xFFFFC107);
    final shine = Paint()..color = const Color(0xFFFFF59D);
    final rim = _stroke(const Color(0xFFB8860B), 2);
    for (final c in coinList) {
      if (c.taken) continue;
      final sx = c.x - camX;
      if (sx < -30 || sx > vw + 30) continue;
      final sy = c.y - camY + math.sin(time * 3 + c.phase) * 3;
      final wScale = math.cos(time * 4 + c.phase).abs() * 0.7 + 0.3;
      final r = Rect.fromCenter(
          center: Offset(sx, sy), width: 22 * wScale, height: 22);
      canvas.drawOval(r, gold);
      canvas.drawOval(r, rim);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(sx, sy), width: 10 * wScale, height: 12),
          shine);
    }

    for (final f in cans) {
      if (f.taken) continue;
      final sx = f.x - camX;
      if (sx < -40 || sx > vw + 40) continue;
      final sy = f.y - camY + math.sin(time * 2.5 + f.x) * 4;
      final pulse = 0.5 + 0.5 * math.sin(time * 5);
      canvas.drawCircle(Offset(sx, sy), 30,
          Paint()..color = Color.fromRGBO(255, 80, 60, 0.12 + 0.12 * pulse));
      final body = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(sx, sy), width: 26, height: 32),
        const Radius.circular(5),
      );
      canvas.drawRRect(body, Paint()..color = const Color(0xFFD32F2F));
      canvas.drawRRect(body, _stroke(const Color(0xFF7F1010), 2));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(sx - 5, sy - 21, 10, 7), const Radius.circular(2)),
        Paint()..color = const Color(0xFF7F1010),
      );
      _text(canvas, 'F', Offset(sx, sy - 11), fs: 18, center: true);
    }
  }

  void _wheel(Canvas canvas, Offset c) {
    canvas.drawCircle(c, 18, Paint()..color = const Color(0xFF1C1C1C));
    final knob = _stroke(const Color(0xFF3F3F3F), 3);
    for (var i = 0; i < 14; i++) {
      final a = wheelRot + i * 2 * math.pi / 14;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * 15.5, c + d * 18.5, knob);
    }
    canvas.drawCircle(c, 11.5, _stroke(const Color(0xFFC9CDD2), 2.5));
    final spoke = _stroke(const Color(0xFFC9CDD2), 1.5);
    for (var i = 0; i < 3; i++) {
      final a = wheelRot + i * math.pi / 3;
      final d = Offset(math.cos(a), math.sin(a)) * 11;
      canvas.drawLine(c - d, c + d, spoke);
    }
    canvas.drawCircle(c, 3.5, Paint()..color = const Color(0xFF555A61));
  }

  // ---------- MOTO COM SUSPENSÃO E PILOTO REATIVOS ----------
  void _drawBike(Canvas canvas, double sx, double sy, bool rider) {
    canvas.save();
    canvas.translate(sx, sy);
    canvas.rotate(ang);

    // Eixos calculados dinamicamente com base na compressão das molas
    final rearAxle = Offset(-32, 14 - suspRear);
    final frontAxle = Offset(32 - 0.47 * suspFront, 14 - 0.88 * suspFront);

    // 1. Rodas nas posições dinâmicas da suspensão
    _wheel(canvas, rearAxle);
    _wheel(canvas, frontAxle);

    // 2. Balança traseira dinâmica conectada ao pivô do chassi
    const swingarmPivot = Offset(-2, 6);
    canvas.drawLine(rearAxle, swingarmPivot, _stroke(const Color(0xFF3A3F47), 5.5));

    // 3. Mola amortecedora traseira comprimindo em tempo real
    final shockMountLower = Offset.lerp(rearAxle, swingarmPivot, 0.55)!;
    canvas.drawLine(
      const Offset(-18, -4),
      shockMountLower,
      _stroke(const Color(0xFFFFD54F), 5),
    );
    canvas.drawLine(
      const Offset(-18, -4),
      shockMountLower,
      _stroke(const Color(0xFF424242), 2),
    );

    // 4. Garfo dianteiro telescópico (bengala exterior dourada + tubo interno cromado)
    const tripleClamp = Offset(18, -12);
    final forkMid = Offset.lerp(tripleClamp, frontAxle, 0.58)!;
    canvas.drawLine(tripleClamp, frontAxle, _stroke(const Color(0xFFE0E0E0), 4));
    canvas.drawLine(tripleClamp, forkMid, _stroke(const Color(0xFFFFB300), 6));

    // 5. Escapamento com saída de nitro
    final exhaust = Path()
      ..moveTo(4, 10)
      ..quadraticBezierTo(-14, 16, -36, 4);
    canvas.drawPath(exhaust, _stroke(const Color(0xFF9EA3AA), 5));

    // 6. Bloco do Motor
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(-12, -2, 26, 18), const Radius.circular(4)),
      Paint()..color = const Color(0xFF4A4F57),
    );

    // 7. Tanque e carenagem esportiva
    final tankColor = stuntSystem.turboActive ? const Color(0xFF00E5FF) : const Color(0xFFFF6D00);
    final tank = Path()
      ..moveTo(-8, -8)
      ..lineTo(14, -12)
      ..lineTo(22, -4)
      ..lineTo(14, 2)
      ..lineTo(-6, 0)
      ..close();
    canvas.drawPath(tank, Paint()..color = tankColor);

    // 8. Banco e Paralamas
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(-34, -12, 28, 6), const Radius.circular(3)),
      Paint()..color = const Color(0xFF212121),
    );
    canvas.drawLine(const Offset(-30, -8), const Offset(-42, 0),
        _stroke(tankColor, 5));

    // Paralama dianteiro acompanha o eixo dianteiro dinamicamente
    canvas.drawArc(
      Rect.fromCircle(center: frontAxle, radius: 22),
      -math.pi * 0.85,
      math.pi * 0.55,
      false,
      _stroke(tankColor, 4),
    );

    // 9. Guidão e placa
    canvas.save();
    canvas.translate(24, -14);
    canvas.rotate(-0.35);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(-6, -7, 12, 14), const Radius.circular(3)),
      Paint()..color = Colors.white,
    );
    canvas.restore();
    canvas.drawLine(const Offset(18, -12), const Offset(12, -20),
        _stroke(const Color(0xFF212121), 4));

    // 10. PILOTO COM POSTURA CINEMÁTICA PROCEDURAL
    if (rider) {
      final squash = ((suspRear + suspFront) * 0.45).clamp(0.0, 7.0);
      final riderShiftX = (gas ? -3.0 : 0.0) + (brake ? 2.5 : 0.0) - (leanBack ? 5.0 : 0.0) + (leanFwd ? 4.0 : 0.0);

      final hip = Offset(-8 + riderShiftX, -12 + squash);
      const foot = Offset(3, 9);
      final knee = Offset(hip.dx + 15, (hip.dy + foot.dy) * 0.5 + 2);

      final shoulder = Offset(2 + riderShiftX * 0.7, -31 + squash * 0.7);
      const hands = Offset(13, -18);
      final elbow = Offset(shoulder.dx + 10, shoulder.dy + 8);
      final head = Offset(shoulder.dx + 4, shoulder.dy - 8);

      final pants = _stroke(const Color(0xFF263859), 8);
      final jersey = _stroke(stuntSystem.turboActive ? const Color(0xFF00B0FF) : const Color(0xFFE53935), 10);
      final arm = _stroke(jersey.color, 6);

      // Perna (Quadril -> Joelho -> Pé nas pedaleiras)
      canvas.drawLine(hip, knee, pants);
      canvas.drawLine(knee, foot, pants);

      // Tronco e Braço articulados
      canvas.drawLine(hip, shoulder, jersey);
      canvas.drawLine(shoulder, elbow, arm);
      canvas.drawLine(elbow, hands, arm);
      canvas.drawCircle(hands, 3.5, Paint()..color = const Color(0xFF212121));

      // Capacete com viseira esportiva
      canvas.drawCircle(head, 9, Paint()..color = Colors.white);
      canvas.drawArc(
        Rect.fromCircle(center: head, radius: 9),
        -math.pi * 0.95,
        math.pi * 0.7,
        false,
        _stroke(jersey.color, 3),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(head.dx + 1, head.dy - 3, 9, 6), const Radius.circular(3)),
        Paint()..color = const Color(0xFF1A237E),
      );
    }
    canvas.restore();
  }

  void _drawRagdoll(Canvas canvas) {
    canvas.save();
    canvas.translate(gx - camX, gy - camY);
    canvas.rotate(gAng);
    final pants = _stroke(const Color(0xFF263859), 8);
    final jersey = _stroke(const Color(0xFFE53935), 10);
    final arm = _stroke(const Color(0xFFE53935), 6);
    canvas.drawLine(const Offset(0, 12), const Offset(-9, 28), pants);
    canvas.drawLine(const Offset(0, 12), const Offset(8, 27), pants);
    canvas.drawLine(const Offset(0, -12), const Offset(0, 12), jersey);
    canvas.drawLine(const Offset(0, -8), const Offset(-12, 4), arm);
    canvas.drawLine(const Offset(0, -8), const Offset(12, 2), arm);
    canvas.drawCircle(const Offset(0, -21), 9, Paint()..color = Colors.white);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(1, -25, 9, 6), const Radius.circular(3)),
      Paint()..color = const Color(0xFF1A237E),
    );
    canvas.restore();
  }

  // ---------- HUD VISCERAL COM ADRENALINA & COMBOS ----------
  void _drawHud(Canvas canvas) {
    // Progresso da fase
    final bw = math.min(240.0, size.x * 0.4);
    final bx = size.x / 2 - bw / 2;
    final pr = (distance / lv.goal).clamp(0.0, 1.0).toDouble();
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bx, 14, bw, 10), const Radius.circular(5)),
        Paint()..color = const Color(0x66000000));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bx, 14, bw * pr, 10), const Radius.circular(5)),
        Paint()..color = const Color(0xFFFFC107));
    _text(canvas, 'FASE ${level + 1}: ${lv.name}  •  meta ${lv.goal} m',
        Offset(size.x / 2, 28),
        fs: 12, center: true);

    final shown = math.max(best, distance);
    _text(canvas, '${distance.toStringAsFixed(0)} m', const Offset(16, 10),
        fs: 30, w: FontWeight.w800);
    _text(canvas, 'Recorde ${shown.toStringAsFixed(0)} m',
        const Offset(16, 46),
        fs: 14);

    // Moedas
    canvas.drawCircle(
        const Offset(26, 80), 9, Paint()..color = const Color(0xFFFFC107));
    canvas.drawCircle(
        const Offset(26, 80), 9, _stroke(const Color(0xFFB8860B), 2));
    _text(canvas, '$coins', const Offset(42, 70), fs: 18);

    // Barra de Combustível
    final bar = RRect.fromRectAndRadius(
        Rect.fromLTWH(16, 100, 150, 14), const Radius.circular(7));
    canvas.drawRRect(bar, Paint()..color = const Color(0x66000000));
    final f = (fuel / 100).clamp(0.0, 1.0).toDouble();
    final blink = fuel < 25 && (time * 4).floor() % 2 == 0;
    final col = blink
        ? const Color(0xFFFF1744)
        : (fuel > 50
            ? const Color(0xFF4CAF50)
            : (fuel > 25 ? const Color(0xFFFFC107) : const Color(0xFFFF5722)));
    if (f > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(16, 100, 150 * f, 14), const Radius.circular(7)),
        Paint()..color = col,
      );
    }
    canvas.drawRRect(bar, _stroke(Colors.white, 1.5));
    _text(canvas, 'COMBUSTÍVEL', const Offset(24, 101), fs: 9);

    // BARRA DE ADRENALINA / TURBO NITRO
    final adrBar = RRect.fromRectAndRadius(
        Rect.fromLTWH(16, 120, 150, 14), const Radius.circular(7));
    canvas.drawRRect(adrBar, Paint()..color = const Color(0x66000000));
    final adrProgress = (stuntSystem.adrenaline / 100.0).clamp(0.0, 1.0);
    if (adrProgress > 0) {
      final adrColor = stuntSystem.turboActive
          ? const Color(0xFF00E5FF)
          : (stuntSystem.adrenaline >= 10.0 ? const Color(0xFFFF9100) : const Color(0xFF757575));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(16, 120, 150 * adrProgress, 14), const Radius.circular(7)),
        Paint()..color = adrColor,
      );
    }
    canvas.drawRRect(adrBar, _stroke(Colors.white, 1.5));
    _text(
      canvas,
      stuntSystem.turboActive ? 'TURBO ATIVADO!' : 'ADRENALINA (TURBO)',
      const Offset(24, 121),
      fs: 9,
      color: stuntSystem.turboActive ? Colors.cyanAccent : Colors.white,
    );

    // Velocímetro digital dinâmico
    final kmh = (vx.abs() / 4.6).round();
    final speedColor = stuntSystem.turboActive
        ? const Color(0xFF00E5FF)
        : (kmh > 100 ? const Color(0xFFFF5722) : Colors.white);
    _text(canvas, '$kmh km/h', const Offset(16, 140), fs: 15, color: speedColor, w: FontWeight.w800);

    // Indicador das entradas (confere controles)
    const names = ['ACEL', 'FREIO', 'EMP', 'ABX', 'TURBO'];
    final on = [gas, brake, leanBack, leanFwd, stuntSystem.turboActive];
    for (var i = 0; i < 5; i++) {
      final x0 = 16 + i * 46.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x0, 162, 42, 18), const Radius.circular(5)),
        Paint()
          ..color = on[i]
              ? (i == 4 ? const Color(0xFF00E5FF) : const Color(0xEEFFC107))
              : const Color(0x55000000),
      );
      _text(canvas, names[i], Offset(x0 + 21, 165),
          fs: 9, center: true, color: on[i] ? Colors.black : Colors.white);
    }

    // Mensagens de manobras / combos / eventos
    final activeMsg = stuntSystem.popMessage.isNotEmpty ? stuntSystem.popMessage : _popText;
    final activeTimer = stuntSystem.popMessageTimer > 0 ? stuntSystem.popMessageTimer : _popTimer;
    if (activeTimer > 0 && activeMsg.isNotEmpty) {
      final a = math.min(1.0, activeTimer * 2.2);
      final isCombo = activeMsg.contains('x') || activeMsg.contains('GRAU') || activeMsg.contains('FLIP');
      _text(
        canvas,
        activeMsg,
        Offset(size.x / 2, size.y * 0.22 - (1.4 - activeTimer) * 16),
        fs: isCombo ? 34 : 28,
        w: FontWeight.w900,
        color: isCombo ? Color.fromRGBO(0, 229, 255, a) : Color.fromRGBO(255, 214, 0, a),
        center: true,
      );
    }
  }

  void _drawCalibration(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = const Color(0xDD000000));
    _text(canvas, 'CONFIGURAR CONTROLE', Offset(size.x / 2, size.y * 0.28),
        fs: 28, center: true);
    _text(canvas, 'Aperte o botão para: ${calLabels[_calStep]}',
        Offset(size.x / 2, size.y * 0.40),
        fs: 24, color: Colors.amber, center: true);
    _text(canvas, '(${_calStep + 1} de ${calLabels.length})   botão ou direção do controle   •   Esc cancela',
        Offset(size.x / 2, size.y * 0.50),
        fs: 16, center: true);
    _text(canvas, 'Último sinal recebido: ${lastRaw.isEmpty ? '-' : lastRaw}',
        Offset(size.x / 2, size.y * 0.58),
        fs: 14, color: Colors.white70, center: true);
  }
}
