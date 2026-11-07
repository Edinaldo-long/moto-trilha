import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

void main() {
  final dir = Directory('assets/audio');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  // 1. Jump: whoosh ascendente
  saveWav('assets/audio/jump.wav', synth(0.25, (t) {
    final f = 150.0 + 400.0 * t;
    final env = math.sin(math.pi * t);
    return math.sin(2 * math.pi * f * t) * env * 0.7;
  }));

  // 2. Land: impacto pesado e grave com ruído de suspensão
  final rnd = math.Random(42);
  saveWav('assets/audio/land.wav', synth(0.35, (t) {
    final env = math.exp(-t * 12.0);
    final bass = math.sin(2 * math.pi * 65.0 * (1.0 - t * 0.5) * t);
    final crunch = (rnd.nextDouble() * 2.0 - 1.0) * math.exp(-t * 25.0) * 0.5;
    return (bass * 0.8 + crunch) * env;
  }));

  // 3. Crash: explosão e metal colidindo
  saveWav('assets/audio/crash.wav', synth(0.7, (t) {
    final env = math.exp(-t * 5.0);
    final noise = (rnd.nextDouble() * 2.0 - 1.0);
    final rumble = math.sin(2 * math.pi * 45.0 * t);
    return (noise * 0.7 + rumble * 0.3) * env;
  }));

  // 4. Coin: dois tons cristalinos rápidos (B5 -> E6)
  saveWav('assets/audio/coin.wav', synth(0.2, (t) {
    final f = t < 0.08 ? 987.77 : 1318.51;
    final env = math.exp(-((t % 0.08) * 20.0));
    return math.sin(2 * math.pi * f * t) * env * 0.8;
  }));

  // 5. Fuel: recarga power-up
  saveWav('assets/audio/fuel.wav', synth(0.35, (t) {
    final f = 300.0 + 800.0 * (t / 0.35);
    final env = math.sin(math.pi * (t / 0.35));
    final mod = math.sin(2 * math.pi * 30.0 * t);
    return (math.sin(2 * math.pi * f * t) + 0.3 * mod) * env * 0.75;
  }));

  // 6. Boost: rugido de turbo e pós-combustão
  saveWav('assets/audio/boost.wav', synth(0.6, (t) {
    final env = math.sin(math.pi * (t / 0.6));
    final jet = (rnd.nextDouble() * 2.0 - 1.0) * 0.6;
    final tone = math.sin(2 * math.pi * (180.0 + 350.0 * t) * t) * 0.4;
    return (jet + tone) * env;
  }));

  // 7. Trick: fanfare de manobra completada
  saveWav('assets/audio/trick.wav', synth(0.4, (t) {
    final f = t < 0.12 ? 523.25 : (t < 0.24 ? 659.25 : 783.99); // C - E - G
    final env = math.exp(-((t % 0.12) * 15.0));
    return math.sin(2 * math.pi * f * t) * env * 0.8;
  }));

  // 8. Engine Loop: motor 2 tempos roncando em loop perfeito
  saveWav('assets/audio/engine_loop.wav', synth(0.5, (t) {
    const f0 = 66.0; // 33 ciclos exatos em 0.5s para loop contínuo sem estalo
    final p1 = math.sin(2 * math.pi * f0 * t);
    final p2 = math.sin(2 * math.pi * f0 * 2 * t) * 0.55;
    final p3 = math.sin(2 * math.pi * f0 * 3 * t) * 0.35;
    final p4 = math.sin(2 * math.pi * f0 * 4 * t) * 0.2;
    final pulse = (p1 + p2 + p3 + p4);
    // Leve raspagem do escapamento
    final rasp = (rnd.nextDouble() * 2.0 - 1.0) * 0.12;
    return (pulse * 0.7 + rasp).clamp(-1.0, 1.0) * 0.65;
  }));

  // Sintetização concluída
}

List<double> synth(double duration, double Function(double t) generator, [int sampleRate = 22050]) {
  final count = (duration * sampleRate).toInt();
  final samples = <double>[];
  for (var i = 0; i < count; i++) {
    final t = i / sampleRate;
    samples.add(generator(t).clamp(-1.0, 1.0));
  }
  return samples;
}

void saveWav(String path, List<double> samples, [int sampleRate = 22050]) {
  final numSamples = samples.length;
  final numBytes = numSamples * 2; // 16-bit
  final byteData = ByteData(44 + numBytes);

  // RIFF chunk descriptor
  byteData.setUint8(0, 0x52); // R
  byteData.setUint8(1, 0x49); // I
  byteData.setUint8(2, 0x46); // F
  byteData.setUint8(3, 0x46); // F
  byteData.setUint32(4, 36 + numBytes, Endian.little);
  byteData.setUint8(8, 0x57);  // W
  byteData.setUint8(9, 0x41);  // A
  byteData.setUint8(10, 0x56); // V
  byteData.setUint8(11, 0x45); // E

  // "fmt " sub-chunk
  byteData.setUint8(12, 0x66); // f
  byteData.setUint8(13, 0x6D); // m
  byteData.setUint8(14, 0x74); // t
  byteData.setUint8(15, 0x20); // ' '
  byteData.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
  byteData.setUint16(20, 1, Endian.little);  // AudioFormat (1 = PCM)
  byteData.setUint16(22, 1, Endian.little);  // NumChannels (1 = Mono)
  byteData.setUint32(24, sampleRate, Endian.little); // SampleRate
  byteData.setUint32(28, sampleRate * 2, Endian.little); // ByteRate (SampleRate * 1 * 16/8)
  byteData.setUint16(32, 2, Endian.little);  // BlockAlign (1 * 16/8)
  byteData.setUint16(34, 16, Endian.little); // BitsPerSample (16 bits)

  // "data" sub-chunk
  byteData.setUint8(36, 0x64); // d
  byteData.setUint8(37, 0x61); // a
  byteData.setUint8(38, 0x74); // t
  byteData.setUint8(39, 0x61); // a
  byteData.setUint32(40, numBytes, Endian.little);

  // Write 16-bit PCM samples
  var offset = 44;
  for (var i = 0; i < numSamples; i++) {
    final s = (samples[i] * 32767).toInt().clamp(-32768, 32767);
    byteData.setInt16(offset, s, Endian.little);
    offset += 2;
  }

  File(path).writeAsBytesSync(byteData.buffer.asUint8List());
}
