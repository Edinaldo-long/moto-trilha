// MOTO TRILHA - jogo de moto em trilha (Flutter + Flame) com suporte a controle
//
// Dependências:  flutter pub add flame shared_preferences gamepads
//
// Android: o pacote gamepads exige um MainActivity que repassa os eventos do
// controle (exemplo no README: https://pub.dev/packages/gamepads).
import 'dart:async';
import 'dart:math' as math;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamepads/gamepads.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
            'menu': (context, g) => _Menu(game: g),
            'controls': (context, g) => _Controls(game: g),
            'gameover': (context, g) => _GameOver(game: g),
            'won': (context, g) => _LevelWon(game: g),
          },
        ),
      ),
    ),
  );
}

// ============================================================
//  MODELOS
// ============================================================

/// Pedra/rampa: uma "lombada" suave somada ao terreno.
class Bump {
  final double x, h, w;
  Bump(this.x, this.h, this.w);
}

/// Terreno infinito gerado por senos + lombadas.
class Terrain {
  final double s1, s2, s3, amp;
  final List<Bump> bumps = [];

  Terrain(math.Random r, this.amp)
      : s1 = r.nextDouble() * 2000,
        s2 = r.nextDouble() * 2000,
        s3 = r.nextDouble() * 2000;

  /// Relevo base (começa plano e fica mais difícil com a distância).
  double base(double x) {
    final f = (x / 900).clamp(0.0, 1.0).toDouble();
    final d = (1 + (x / 12000).clamp(0.0, 1.0).toDouble()) * amp;
    return -f *
        (math.sin((x + s1) * 0.0040) * 70 * d +
            math.sin((x + s2) * 0.0115) * 30 * d +
            math.sin((x + s3) * 0.0300) * 5);
  }

  double bump(double x) {
    double b = 0;
    for (final k in bumps) {
      final t = (x - k.x) / k.w;
      if (t > -3 && t < 3) b -= k.h * math.exp(-t * t);
    }
    return b;
  }

  double y(double x) => base(x) + bump(x);

  double slope(double x) => (y(x + 1) - y(x - 1)) / 2;
}

class Coin {
  final double x, y, phase;
  bool taken = false;
  Coin(this.x, this.y, this.phase);
}

class FuelCan {
  final double x, y;
  bool taken = false;
  FuelCan(this.x, this.y);
}

/// Partícula (poeira, brilho de moeda, explosão).
class Dust {
  double x, y, vx, vy, life;
  final double maxLife, size;
  final Color color;
  Dust(this.x, this.y, this.vx, this.vy, this.maxLife, this.size, this.color)
      : life = maxLife;
}

enum Phase { menu, playing, crashed, won }

/// Uma fase: meta de distância, dificuldade e visual.
class LevelDef {
  final String name;
  final int goal; // metros para completar
  final double amp; // altura dos morros
  final double bumpP; // chance de pedras/rampas
  final double bumpH; // altura das pedras
  final double fuelGap; // distância entre galões (px)
  final double fuelRate; // consumo de combustível
  final Color skyTop, skyBottom, hillFar, hillNear;
  final Color grass, grassDark, dirtTop, dirtBottom, dirtLight;
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
    name: 'Deserto',
    goal: 450,
    amp: 1.0,
    bumpP: 0.32,
    bumpH: 1.0,
    fuelGap: 2500,
    fuelRate: 1.1,
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

// ============================================================
//  JOGO
// ============================================================

class TrailGame extends FlameGame with KeyboardEvents {
  final math.Random _rnd = math.Random();
  late Terrain terrain;
  Phase phase = Phase.menu;
  int level = 0, unlocked = 0;
  LevelDef get lv => kLevels[level];

  // Entradas
  bool gas = false, brake = false, leanBack = false, leanFwd = false;

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
  final Map<String, String> _calKeys = {}; // ação -> nome do botão
  final Set<String> _calHeld = {};
  static const _calActions = ['gas', 'brake', 'leanBack', 'leanFwd'];
  static const _calLabels = [
    'ACELERAR',
    'FREAR',
    'EMPINAR',
    'ABAIXAR A FRENTE'
  ];

  // Moto
  double px = 100, py = 0, vx = 0, vy = 0, ang = 0, angVel = 0, wheelRot = 0;
  int _contacts = 0;
  double _airTime = 0, _airRot = 0;

  // Status
  double distance = 0, best = 0, fuel = 100;
  int coins = 0, totalCoins = 0;
  bool newRecord = false;
  String crashReason = '';

  // Mundo
  final List<Coin> coinList = [];
  final List<FuelCan> cans = [];
  final List<Dust> dust = [];
  double _spawnX = 0, _nextCanX = 0;

  // Câmera e efeitos
  double camX = 0, camY = 0, shake = 0, time = 0;
  bool _camInit = false;
  String _popText = '';
  double _popTimer = 0;

  // Piloto arremessado na queda
  bool riderEjected = false;
  double gx = 0, gy = 0, gvx = 0, gvy = 0, gAng = 0, gAngV = 0;
  double _crashTimer = 0;

  double get _zoom => (size.y / 650).clamp(0.75, 1.5).toDouble();
  double get _dusk => (distance / lv.goal).clamp(0.0, 1.0).toDouble() * 0.7;

  // ---------- ciclo de vida ----------
  @override
  Future<void> onLoad() async {
    try {
      final p = await SharedPreferences.getInstance();
      best = p.getDouble('best') ?? 0;
      totalCoins = p.getInt('totalCoins') ?? 0;
      unlocked = (p.getInt('unlocked') ?? 0).clamp(0, kLevels.length - 1).toInt();
      level = unlocked;
      final cal = p.getStringList('cal2');
      if (cal != null && cal.length == 4) {
        for (var i = 0; i < 4; i++) {
          _calKeys[_calActions[i]] = cal[i];
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
    dust.clear();
    px = 100;
    py = terrain.y(px) - 32;
    vx = vy = ang = angVel = wheelRot = 0;
    distance = 0;
    coins = 0;
    fuel = 100;
    shake = 0;
    _airTime = 0;
    _airRot = 0;
    _contacts = 0;
    _popTimer = 0;
    riderEjected = false;
    newRecord = false;
    gas = brake = leanBack = leanFwd = false;
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
    gas = brake = leanBack = leanFwd = false;
    _crashTimer = 1.2;
    _burst(px, py - 40, 40, const Color(0xFFFFD54F), 260);
    _popText = 'FASE CONCLUÍDA!';
    _popTimer = 1.4;
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble('best', best);
      await p.setInt('totalCoins', totalCoins);
      await p.setInt('unlocked', unlocked);
    } catch (_) {}
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keys) {
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
        (keys.contains(LogicalKeyboardKey.arrowRight) ||
            keys.contains(LogicalKeyboardKey.keyD));
    brake = playing &&
        (keys.contains(LogicalKeyboardKey.arrowLeft) ||
            keys.contains(LogicalKeyboardKey.keyA));
    leanBack = playing &&
        (keys.contains(LogicalKeyboardKey.arrowUp) ||
            keys.contains(LogicalKeyboardKey.keyW));
    leanFwd = playing &&
        (keys.contains(LogicalKeyboardKey.arrowDown) ||
            keys.contains(LogicalKeyboardKey.keyS));

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

  /// Eventos "normalizados" (A, B, bumpers, gatilhos, analógico, D-pad).
  void _onPad(NormalizedGamepadEvent e) {
    _gotNormalized = true;
    if (calibrating || _calKeys.length == 4) return; // usa só os botões escolhidos
    final b = e.button;
    if (b != null && !calibrating && _calKeys.length < 4) {
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

  /// Plano B para controles genéricos (botões numerados 1, 2, 3, 4...):
  /// só é usado se o pacote nunca reconheceu o controle como padrão.
  /// Também imprime no console o nome real de cada botão (útil para ajustar).
  void _onRaw(GamepadEvent e) {
    debugPrint('RAW ${e.type} key=${e.key} value=${e.value}');
    lastRaw = '${e.key} = ${e.value}';
    final on = e.value.abs() > 0.5;

    // Modo configuração: guarda o nome exato de cada botão apertado
    if (calibrating) {
      if (!on) {
        _calWait = false;
        return;
      }
      // O sinal (+ / -) entra na identificação: assim "direção para cima" e
      // "direção para baixo" (mesmo eixo) viram dois comandos diferentes.
      final id = '${e.key}|${e.value > 0 ? '+' : '-'}';
      if (_calWait || _calKeys.containsValue(id)) return;
      _calKeys[_calActions[_calStep]] = id;
      _calStep++;
      _calWait = true;
      if (_calStep >= _calActions.length) {
        calibrating = false;
        _saveCal();
        overlays.add('menu');
      }
      return;
    }

    // Controle já configurado: usa os botões escolhidos pelo jogador
    if (_calKeys.length == 4) {
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
      if (v.abs() > 1.5) v /= 32767; // eixos brutos vêm em +-32767
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
      await p.setStringList('cal2', [for (final a in _calActions) _calKeys[a]!]);
    } catch (_) {}
  }

  void _applyPad() {
    if (phase != Phase.playing) return;
    final cal = _calKeys.length == 4;
    bool h(String a) => cal && _calHeld.contains(_calKeys[a]);
    // Controle configurado: valem SÓ os 4 comandos escolhidos.
    gas = h('gas') ||
        (!cal &&
            (_held.contains(GamepadButton.a) ||
                _rawHeld.contains(0) ||
                _rt > 0.3 ||
                _ax > 0.5));
    brake = h('brake') ||
        (!cal &&
            (_held.contains(GamepadButton.b) ||
                _rawHeld.contains(1) ||
                _lt > 0.3 ||
                _ax < -0.5));
    leanBack = h('leanBack') ||
        (!cal &&
            (_held.contains(GamepadButton.x) ||
                _held.contains(GamepadButton.leftBumper) ||
                _held.contains(GamepadButton.dpadUp) ||
                _rawHeld.contains(2) ||
                _rawHeld.contains(4) ||
                _ay < -0.5));
    leanFwd = h('leanFwd') ||
        (!cal &&
            (_held.contains(GamepadButton.y) ||
                _held.contains(GamepadButton.rightBumper) ||
                _held.contains(GamepadButton.dpadDown) ||
                _rawHeld.contains(3) ||
                _rawHeld.contains(5) ||
                _ay > 0.5));
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

  // ---------- física ----------
  void _step(double dt) {
    const g = 900.0, L = 32.0, R = 18.0;
    const k = 1500.0, c = 90.0, inertia = 1800.0, maxSpeed = 680.0;

    final alive = phase == Phase.playing;
    final drive = alive && gas && fuel > 0;
    final braking = alive && brake;
    final vyBefore = vy;

    double ax = 0, ay = g, torque = 0, groundAng = 0;
    int contacts = 0;
    final ca = math.cos(ang), sa = math.sin(ang);

    for (final s in const [-1.0, 1.0]) {
      final lx = s * L, ly = 14.0;
      final ox = lx * ca - ly * sa;
      final oy = lx * sa + ly * ca;
      final wx = px + ox, wy = py + oy;
      final pen = wy + R - terrain.y(wx);
      if (pen <= 0) continue;
      contacts++;

      final slope = terrain.slope(wx);
      groundAng += math.atan(slope);
      final inv = 1 / math.sqrt(slope * slope + 1);
      final nx = slope * inv, ny = -inv; // normal (para cima)
      final tx = inv, ty = slope * inv; // tangente (para frente)

      final wvx = vx - angVel * oy;
      final wvy = vy + angVel * ox;
      final vn = wvx * nx + wvy * ny;
      final vt = wvx * tx + wvy * ty;

      // Amortecimento assimétrico: absorve forte o impacto (vn < 0) e quase
      // não devolve energia na volta (vn > 0). Assim a moto não quica.
      final cc = vn < 0 ? c : 400.0;
      final fn = (k * pen - cc * vn).clamp(0.0, 6000.0).toDouble();
      double ft = -vt * 0.12; // atrito de rolagem
      if (drive && vt < maxSpeed) ft += 620; // tração nas duas rodas
      if (braking) ft += -vt * 6;

      final fnx = nx * fn, fny = ny * fn;
      final ftx = tx * ft, fty = ty * ft;
      ax += fnx + ftx;
      ay += fny + fty;
      torque += ox * fny - oy * fnx;
      torque += ox * fty - oy * 0.3 * ftx; // tração empina menos
    }

    if (alive) {
      // Inclinar o piloto (no ar o efeito é maior)
      final lean = contacts == 0 ? 9000.0 : 11000.0;
      if (leanBack) torque -= lean;
      if (leanFwd) torque += lean;

      // Ajuda para a moto acompanhar o chão (evita capotar à toa)
      if (contacts > 0) {
        var diff = groundAng / contacts - ang;
        diff = math.atan2(math.sin(diff), math.cos(diff));
        // Enquanto o jogador inclina, a ajuda do chão fica bem mais fraca
        final stab = (leanBack != leanFwd) ? 0.35 : 1.0;
        torque += diff * (contacts == 2 ? 9000.0 : 2500.0) * stab;
      }
    }

    vx += ax * dt;
    vy += ay * dt;
    vx = vx.clamp(-1100.0, 1100.0).toDouble();
    angVel += torque / inertia * dt;
    angVel *= math.exp(-(contacts > 0 ? 2.0 : 0.5) * dt);
    angVel = angVel.clamp(-9.0, 9.0).toDouble();
    px += vx * dt;
    py += vy * dt;
    ang += angVel * dt;
    wheelRot += (vx / R) * dt;
    _contacts = contacts;

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

    // Tempo no ar, giros e pouso
    if (contacts == 0) {
      _airTime += dt;
      _airRot += angVel * dt;
    } else {
      if (_airTime > 0.3) {
        final impact = vyBefore.abs();
        if (impact > 300) {
          shake = math.max(shake, math.min(10.0, impact / 90));
          _burst(px, py + 30, 10, const Color(0xFFC9A36B), 110);
        }
        final flips = (_airRot.abs() / (2 * math.pi)).round();
        if (flips >= 1) {
          final bonus = flips * 5;
          coins += bonus;
          _popText = flips > 1 ? '$flips FLIPS!  +$bonus' : 'FLIP!  +$bonus';
          _popTimer = 1.4;
        }
      }
      _airTime = 0;
      _airRot = 0;
    }
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
    gas = brake = leanBack = leanFwd = false;
    _crashTimer = eject ? 1.3 : 0.6;
    if (eject) {
      final ca = math.cos(ang), sa = math.sin(ang);
      gx = px + 6 * ca + 30 * sa;
      gy = py + 6 * sa - 30 * ca;
      gvx = vx * 0.9 + 80;
      gvy = vy - 240;
      gAng = ang;
      gAngV = vx >= 0 ? 6 : -6;
      shake = 14;
      _burst(gx, gy, 26, const Color(0xFFFFB74D), 220);
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
      if (gvy > 0) gvy = -gvy * 0.35;
      gvx *= math.exp(-4 * dt);
      gAngV *= math.exp(-3 * dt);
    }
  }

  void _consumeFuel(double dt) {
    fuel -= (gas ? 5.5 : 1.0) * lv.fuelRate * dt;
    if (fuel <= 0) {
      fuel = 0;
      if (vx.abs() < 20 && _contacts > 0) {
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
        _burst(c.x, c.y, 6, const Color(0xFFFFD54F), 90);
      }
    }
    for (final f in cans) {
      if (f.taken) continue;
      final dx = f.x - px, dy = f.y - (py - 6);
      if (dx * dx + dy * dy < 52 * 52) {
        f.taken = true;
        fuel = 100;
        _popText = 'COMBUSTÍVEL CHEIO!';
        _popTimer = 1.2;
        _burst(f.x, f.y, 14, const Color(0xFFFF5252), 130);
      }
    }
  }

  // ---------- partículas ----------
  void _burst(double x, double y, int n, Color color, double speed) {
    for (var i = 0; i < n; i++) {
      final a = _rnd.nextDouble() * 2 * math.pi;
      final s = speed * (0.3 + _rnd.nextDouble());
      dust.add(Dust(x, y, math.cos(a) * s, math.sin(a) * s - 60,
          0.5 + _rnd.nextDouble() * 0.5, 3 + _rnd.nextDouble() * 4, color));
    }
    if (dust.length > 250) dust.removeRange(0, dust.length - 250);
  }

  void _emitDust() {
    if (_contacts == 0 || !gas || fuel <= 0 || vx.abs() < 80) return;
    if (_rnd.nextDouble() > 0.7) return;
    final ca = math.cos(ang), sa = math.sin(ang);
    final wx = px - 32 * ca - 14 * sa;
    final wy = py - 32 * sa + 14 * ca;
    dust.add(Dust(
      wx,
      wy + 16,
      -vx * 0.12 + (_rnd.nextDouble() - 0.5) * 40,
      -20 - _rnd.nextDouble() * 60,
      0.5 + _rnd.nextDouble() * 0.4,
      4 + _rnd.nextDouble() * 4,
      const Color(0xFFC9A36B),
    ));
  }

  void _updateDust(double dt) {
    for (final d in dust) {
      d.life -= dt;
      d.x += d.vx * dt;
      d.y += d.vy * dt;
      d.vy += 60 * dt;
      d.vx *= math.exp(-1.5 * dt);
    }
    dust.removeWhere((d) => d.life <= 0);
  }

  // ---------- atualização ----------
  @override
  void update(double dt) {
    super.update(dt);
    if (size.x <= 0) return;
    dt = math.min(dt, 1 / 30);
    time += dt;

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
        _emitDust();
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

    _updateDust(dt);
    if (_popTimer > 0) _popTimer -= dt;
    shake = math.max(0, shake - 30 * dt);
    _updateCamera(dt);
  }

  void _updateCamera(double dt) {
    final z = _zoom;
    final vw = size.x / z, vh = size.y / z;
    final tx = px - vw * 0.3 + (phase == Phase.playing ? vx * 0.06 : 0);
    final ty = py - vh * 0.58;
    if (!_camInit) {
      camX = tx;
      camY = ty;
      _camInit = true;
      return;
    }
    camX += (tx - camX) * math.min(1.0, 8 * dt);
    camY += (ty - camY) * math.min(1.0, 4 * dt);
  }

  // ============================================================
  //  DESENHO
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
            Shadow(blurRadius: 4, color: Colors.black54, offset: Offset(0, 2)),
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
    final z = _zoom;
    final vw = size.x / z, vh = size.y / z;

    canvas.save();
    canvas.scale(z);
    _drawSky(canvas, vw, vh);

    _drawHills(canvas, vw, vh, 0.12, 0.50, 38, lv.hillFar, 0.0022, 0.0061);
    _drawHills(canvas, vw, vh, 0.30, 0.62, 30, lv.hillNear, 0.0030, 0.0083);

    if (shake > 0) {
      canvas.translate((_rnd.nextDouble() - 0.5) * shake,
          (_rnd.nextDouble() - 0.5) * shake);
    }
    _drawTerrain(canvas, vw, vh);
    _drawRocks(canvas, vw);
    _drawItems(canvas, vw);
    _drawDust(canvas);
    _drawBike(canvas, px - camX, py - camY,
        !(phase == Phase.crashed && riderEjected));
    if (phase == Phase.crashed && riderEjected) _drawRagdoll(canvas);
    canvas.restore();

    _drawHud(canvas);

    if (calibrating && _calStep < _calLabels.length) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y),
          Paint()..color = const Color(0xDD000000));
      _text(canvas, 'CONFIGURAR CONTROLE', Offset(size.x / 2, size.y * 0.28),
          fs: 28, center: true);
      _text(canvas, 'Aperte o botão para: ${_calLabels[_calStep]}',
          Offset(size.x / 2, size.y * 0.40),
          fs: 24, color: Colors.amber, center: true);
      _text(canvas, '(${_calStep + 1} de 4)   botão ou direção do controle   •   Esc cancela',
          Offset(size.x / 2, size.y * 0.50),
          fs: 16, center: true);
      _text(canvas, 'Último sinal recebido: ${lastRaw.isEmpty ? '-' : lastRaw}',
          Offset(size.x / 2, size.y * 0.58),
          fs: 14, color: Colors.white70, center: true);
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

    // Nuvens (parallax)
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

    // Faixa de terra clara logo abaixo da grama
    canvas.save();
    canvas.translate(0, 12);
    canvas.drawPath(top, _stroke(lv.dirtLight, 24));
    canvas.restore();
    // Grama
    canvas.drawPath(top, _stroke(lv.grass, 9));

    // Tufos de grama
    final grass = _stroke(lv.grassDark, 2.5);
    final startX = (camX / 36).floor() * 36.0;
    for (double wx = startX; wx < camX + vw + 36; wx += 36) {
      final h = 5 + 4 * math.sin(wx * 12.9898).abs();
      final sy = terrain.y(wx) - camY - 3;
      final sx = wx - camX;
      canvas.drawLine(Offset(sx, sy), Offset(sx - 3, sy - h), grass);
      canvas.drawLine(Offset(sx, sy), Offset(sx + 3, sy - h * 0.8), grass);
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
    // Moedas
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

    // Galões de combustível
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

  void _drawDust(Canvas canvas) {
    for (final d in dust) {
      final t = d.life / d.maxLife;
      canvas.drawCircle(
        Offset(d.x - camX, d.y - camY),
        d.size * (1 + (1 - t) * 1.6),
        Paint()..color = d.color.withAlpha((t * 150).round()),
      );
    }
  }

  void _wheel(Canvas canvas, Offset c) {
    canvas.drawCircle(c, 18, Paint()..color = const Color(0xFF1C1C1C));
    // Cravos do pneu
    final knob = _stroke(const Color(0xFF3F3F3F), 3);
    for (var i = 0; i < 14; i++) {
      final a = wheelRot + i * 2 * math.pi / 14;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * 15.5, c + d * 18.5, knob);
    }
    // Aro e raios
    canvas.drawCircle(c, 11.5, _stroke(const Color(0xFFC9CDD2), 2.5));
    final spoke = _stroke(const Color(0xFFC9CDD2), 1.5);
    for (var i = 0; i < 3; i++) {
      final a = wheelRot + i * math.pi / 3;
      final d = Offset(math.cos(a), math.sin(a)) * 11;
      canvas.drawLine(c - d, c + d, spoke);
    }
    canvas.drawCircle(c, 3.5, Paint()..color = const Color(0xFF555A61));
  }

  void _drawBike(Canvas canvas, double sx, double sy, bool rider) {
    canvas.save();
    canvas.translate(sx, sy);
    canvas.rotate(ang);

    // Rodas
    _wheel(canvas, const Offset(-32, 14));
    _wheel(canvas, const Offset(32, 14));

    // Balança traseira, mola e garfo dianteiro
    canvas.drawLine(const Offset(-32, 14), const Offset(-2, 6),
        _stroke(const Color(0xFF3A3F47), 5));
    canvas.drawLine(const Offset(-18, -4), const Offset(-10, 8),
        _stroke(const Color(0xFFFFD54F), 4));
    canvas.drawLine(const Offset(18, -12), const Offset(32, 14),
        _stroke(const Color(0xFFC9CDD2), 5));

    // Escapamento
    final exhaust = Path()
      ..moveTo(4, 10)
      ..quadraticBezierTo(-14, 16, -36, 4);
    canvas.drawPath(exhaust, _stroke(const Color(0xFF9EA3AA), 5));

    // Motor
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(-12, -2, 26, 18), const Radius.circular(4)),
      Paint()..color = const Color(0xFF4A4F57),
    );

    // Tanque e carenagem
    final tank = Path()
      ..moveTo(-8, -8)
      ..lineTo(14, -12)
      ..lineTo(22, -4)
      ..lineTo(14, 2)
      ..lineTo(-6, 0)
      ..close();
    canvas.drawPath(tank, Paint()..color = const Color(0xFFFF6D00));

    // Banco e paralamas
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(-34, -12, 28, 6), const Radius.circular(3)),
      Paint()..color = const Color(0xFF212121),
    );
    canvas.drawLine(const Offset(-30, -8), const Offset(-42, 0),
        _stroke(const Color(0xFFFF6D00), 5));
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(32, 14), radius: 22),
      -math.pi * 0.85,
      math.pi * 0.55,
      false,
      _stroke(const Color(0xFFFF6D00), 4),
    );

    // Placa numerada e guidão
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

    if (rider) {
      final pants = _stroke(const Color(0xFF263859), 8);
      final jersey = _stroke(const Color(0xFFE53935), 10);
      final arm = _stroke(const Color(0xFFE53935), 6);
      canvas.drawLine(const Offset(-8, -12), const Offset(8, -8), pants);
      canvas.drawLine(const Offset(8, -8), const Offset(3, 9), pants);
      canvas.drawLine(const Offset(-8, -14), const Offset(2, -31), jersey);
      canvas.drawLine(const Offset(2, -30), const Offset(13, -24), arm);
      canvas.drawLine(const Offset(13, -24), const Offset(13, -17), arm);
      canvas.drawCircle(
          const Offset(13, -17), 3.5, Paint()..color = const Color(0xFF212121));
      // Capacete
      canvas.drawCircle(const Offset(6, -39), 9, Paint()..color = Colors.white);
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(6, -39), radius: 9),
        -math.pi * 0.95,
        math.pi * 0.7,
        false,
        _stroke(const Color(0xFFE53935), 3),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(7, -42, 9, 6), const Radius.circular(3)),
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

    // Barra de combustível
    final bar = RRect.fromRectAndRadius(
        Rect.fromLTWH(16, 100, 150, 16), const Radius.circular(8));
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
            Rect.fromLTWH(16, 100, 150 * f, 16), const Radius.circular(8)),
        Paint()..color = col,
      );
    }
    canvas.drawRRect(bar, _stroke(Colors.white, 1.5));
    _text(canvas, 'COMBUSTÍVEL', const Offset(24, 102), fs: 10);

    // Velocímetro
    _text(canvas, '${(vx.abs() / 5).round()} km/h', const Offset(16, 124),
        fs: 14);

    // Indicador das entradas (confere se o controle está respondendo)
    const names = ['ACEL', 'FREIO', 'EMP', 'ABX'];
    final on = [gas, brake, leanBack, leanFwd];
    for (var i = 0; i < 4; i++) {
      final x0 = 16 + i * 52.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x0, 146, 48, 20), const Radius.circular(6)),
        Paint()
          ..color =
              on[i] ? const Color(0xEEFFC107) : const Color(0x66000000),
      );
      _text(canvas, names[i], Offset(x0 + 24, 150),
          fs: 10, center: true, color: on[i] ? Colors.black : Colors.white);
    }

    // Mensagens (flip, combustível...)
    if (_popTimer > 0) {
      final a = math.min(1.0, _popTimer * 2);
      _text(
        canvas,
        _popText,
        Offset(size.x / 2, size.y * 0.22 - (1.4 - _popTimer) * 20),
        fs: 30,
        w: FontWeight.w900,
        color: Color.fromRGBO(255, 214, 0, a),
        center: true,
      );
    }
  }
}

// ============================================================
//  TELAS (overlays)
// ============================================================

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          constraints: const BoxConstraints(maxWidth: 440),
          decoration: BoxDecoration(
            color: const Color(0xDD14181F),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.deepOrange, width: 2),
          ),
          child: SingleChildScrollView(child: child),
        ),
      );
}

class _Menu extends StatefulWidget {
  final TrailGame game;
  const _Menu({required this.game});

  @override
  State<_Menu> createState() => _MenuState();
}

class _MenuState extends State<_Menu> {
  TrailGame get game => widget.game;

  @override
  Widget build(BuildContext context) => _Panel(
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
              'Junte moedas, pegue combustível e vá o mais longe que puder!',
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: game.level > 0
                      ? () => setState(() => game.level--)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                  color: Colors.white,
                  disabledColor: Colors.white24,
                ),
                Column(children: [
                  Text(
                    'FASE ${game.level + 1}: ${game.lv.name}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'Meta: ${game.lv.goal} m   •   Fases liberadas: ${game.unlocked + 1}/${kLevels.length}',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ]),
                IconButton(
                  onPressed: game.level < game.unlocked
                      ? () => setState(() => game.level++)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                  color: Colors.white,
                  disabledColor: Colors.white24,
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'TECLADO\n'
              'Direita / D: acelera   •   Esquerda / A: freia\n'
              'Cima / W: empina   •   Baixo / S: abaixa a frente\n\n'
              'CONTROLE: clique em CONFIGURAR CONTROLE e escolha\n'
              'o botão ou a direção de cada ação\n'
              '(acelerar, frear, empinar, abaixar a frente)\n\n'
              'No ar, gire a moto para dar FLIPS e ganhar moedas!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: game.startRun,
              icon: const Icon(Icons.play_arrow),
              label: const Text('JOGAR'),
            ),
            const SizedBox(height: 10),
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

class _GameOver extends StatelessWidget {
  final TrailGame game;
  const _GameOver({required this.game});

  @override
  Widget build(BuildContext context) => _Panel(
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
            FilledButton.icon(
              onPressed: game.startRun,
              icon: const Icon(Icons.replay),
              label: const Text('JOGAR DE NOVO'),
            ),
          ],
        ),
      );
}

// ============================================================
//  CONTROLES DE TOQUE
// ============================================================

class _PadButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final Color color;
  final ValueChanged<bool> onChange;
  const _PadButton({
    required this.icon,
    required this.onChange,
    this.size = 72,
    this.color = const Color(0x66000000),
  });

  @override
  State<_PadButton> createState() => _PadButtonState();
}

class _PadButtonState extends State<_PadButton> {
  bool down = false;

  void _set(bool v) {
    if (down == v) return;
    setState(() => down = v);
    widget.onChange(v);
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => _set(true),
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: widget.size,
          height: widget.size,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: down ? const Color(0x99FFFFFF) : widget.color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white54, width: 2),
          ),
          child: Icon(widget.icon, color: Colors.white, size: widget.size * 0.5),
        ),
      );
}

class _Controls extends StatelessWidget {
  final TrailGame game;
  const _Controls({required this.game});

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(children: [
                  _PadButton(
                      icon: Icons.rotate_left,
                      onChange: (v) => game.leanBack = v),
                  _PadButton(
                      icon: Icons.rotate_right,
                      onChange: (v) => game.leanFwd = v),
                ]),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  _PadButton(
                    icon: Icons.stop,
                    color: const Color(0x88D32F2F),
                    onChange: (v) => game.brake = v,
                  ),
                  _PadButton(
                    icon: Icons.keyboard_double_arrow_right,
                    size: 92,
                    color: const Color(0x88388E3C),
                    onChange: (v) => game.gas = v,
                  ),
                ]),
              ],
            ),
          ),
        ),
      );
}

class _LevelWon extends StatelessWidget {
  final TrailGame game;
  const _LevelWon({required this.game});

  @override
  Widget build(BuildContext context) {
    final last = game.level + 1 >= kLevels.length;
    return _Panel(
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
          FilledButton.icon(
            onPressed: game.nextLevel,
            icon: Icon(last ? Icons.replay : Icons.skip_next),
            label: Text(last ? 'JOGAR DE NOVO (FASE 1)' : 'PRÓXIMA FASE'),
          ),
        ],
      ),
    );
  }
}