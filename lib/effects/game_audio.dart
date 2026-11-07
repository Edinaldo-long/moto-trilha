import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

class GameAudio {
  static bool _initialized = false;
  static bool enabled = true;
  static AudioPlayer? _enginePlayer;
  static final Map<String, int> _lastPlayedMs = {};

  static Future<void> init() async {
    if (_initialized) return;
    try {
      await FlameAudio.audioCache.loadAll([
        'jump.wav',
        'land.wav',
        'crash.wav',
        'coin.wav',
        'fuel.wav',
        'boost.wav',
        'trick.wav',
        'engine_loop.wav',
      ]);
      _initialized = true;
    } catch (e) {
      debugPrint('Aviso ao carregar áudios: $e');
    }
  }

  static void play(String file, {double volume = 1.0}) {
    if (!enabled) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastPlayedMs[file] ?? 0;
    if (now - last < 110) return; // Evita sobrecarga e micro-travamentos de áudio
    _lastPlayedMs[file] = now;
    try {
      FlameAudio.play(file, volume: volume.clamp(0.0, 1.0));
    } catch (e) {
      debugPrint('Erro ao reproduzir $file: $e');
    }
  }

  static void playJump() => play('jump.wav', volume: 0.6);

  static void playLand(double impact) {
    final v = (impact / 600.0).clamp(0.4, 1.0);
    play('land.wav', volume: v);
  }

  static void playCrash() => play('crash.wav', volume: 1.0);
  static void playCoin() => play('coin.wav', volume: 0.7);
  static void playFuel() => play('fuel.wav', volume: 0.85);
  static void playBoost() => play('boost.wav', volume: 0.9);
  static void playTrick() => play('trick.wav', volume: 0.95);

  // Motor contínuo com RPM dinâmico
  static Future<void> startEngine() async {
    if (!enabled) return;
    try {
      if (_enginePlayer == null) {
        _enginePlayer = AudioPlayer();
        await _enginePlayer!.setSource(AssetSource('audio/engine_loop.wav'));
        await _enginePlayer!.setReleaseMode(ReleaseMode.loop);
      }
      await _enginePlayer!.setVolume(0.35);
      await _enginePlayer!.setPlaybackRate(0.85);
      await _enginePlayer!.resume();
    } catch (e) {
      debugPrint('Aviso motor: $e');
    }
  }

  static void updateEngineRpm({
    required bool gas,
    required double speedRatio,
    required bool isTurbo,
  }) {
    if (_enginePlayer == null || !enabled) return;
    try {
      final targetRate = 0.75 + (gas ? 0.35 : 0.0) + (speedRatio * 0.55) + (isTurbo ? 0.35 : 0.0);
      final targetVol = (gas ? 0.50 : 0.22) + (isTurbo ? 0.15 : 0.0);
      _enginePlayer!.setPlaybackRate(targetRate.clamp(0.6, 2.0));
      _enginePlayer!.setVolume(targetVol.clamp(0.1, 0.75));
    } catch (_) {}
  }

  static void stopEngine() {
    try {
      _enginePlayer?.pause();
    } catch (_) {}
  }
}
