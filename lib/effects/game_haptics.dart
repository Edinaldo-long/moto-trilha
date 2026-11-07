import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class GameHaptics {
  static bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static void impact(double intensity) {
    if (!_isMobile) return;
    try {
      if (intensity > 400) {
        HapticFeedback.heavyImpact();
      } else if (intensity > 200) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    } catch (_) {}
  }

  static void crash() {
    if (!_isMobile) return;
    try {
      HapticFeedback.heavyImpact();
      HapticFeedback.vibrate();
    } catch (_) {}
  }

  static void boost() {
    if (!_isMobile) return;
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  static void coin() {
    if (!_isMobile) return;
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }
}
