import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:vibration/vibration.dart';

import 'audio_manager.dart';
import 'progress_manager.dart';

/// Birleşim, kombo, Anne Terliği şaplağı, F16 bombardımanı ve seviye tamamlama
/// anları için `vibrationEnabled` ayarına duyarlı dokunsal geri bildirim servisi.
class HapticService {
  HapticService._();
  static final HapticService instance = HapticService._();
  factory HapticService() => instance;

  bool? _hasCustomVibrator;
  DateTime _lastHapticAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _minGap = Duration(milliseconds: 18);

  /// Hem `ProgressManager.instance.vibrationEnabled` hem `AudioManager().vibrationEnabled`
  /// bayraklarını dikkate alır.
  bool get isEnabled =>
      ProgressManager.instance.vibrationEnabled &&
      AudioManager().vibrationEnabled;

  /// Titreşim ayarını hem `ProgressManager` hem `AudioManager` üzerinde senkronize eder.
  Future<void> setEnabled(bool enabled) async {
    AudioManager().setVibrationEnabled(enabled);
    await ProgressManager.instance.setVibrationEnabled(enabled);
  }

  bool get _isTestEnvironment {
    try {
      if (Zone.current[#test.declarer] != null) return true;
      final bindingType = WidgetsBinding.instance.runtimeType.toString();
      if (bindingType.contains('TestWidgetsFlutterBinding') ||
          bindingType.contains('AutomatedTestWidgetsFlutterBinding') ||
          bindingType.contains('LiveTestWidgetsFlutterBinding')) {
        return true;
      }
    } catch (_) {
      return true;
    }
    return false;
  }

  bool _canTrigger() {
    if (!isEnabled || _isTestEnvironment) return false;
    final now = DateTime.now();
    if (now.difference(_lastHapticAt) < _minGap) return false;
    _lastHapticAt = now;
    return true;
  }

  Future<bool> _supportsCustomVibration() async {
    if (_isTestEnvironment) return false;
    if (_hasCustomVibrator != null) return _hasCustomVibrator!;
    try {
      _hasCustomVibrator = (await Vibration.hasVibrator()) == true;
    } catch (_) {
      _hasCustomVibrator = false;
    }
    return _hasCustomVibrator!;
  }

  /// Hafif dokunuş / böcek bırakma geri bildirimi.
  Future<void> lightImpact() async {
    if (!_canTrigger()) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Orta şiddette dokunuş geri bildirimi.
  Future<void> mediumImpact() async {
    if (!_canTrigger()) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Güçlü darbe geri bildirimi.
  Future<void> heavyImpact() async {
    if (!_canTrigger()) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Seçim / UI tık geri bildirimi.
  Future<void> selectionClick() async {
    if (!_canTrigger()) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Böcek birleşimi (`tier` 1..13 ve `combo` çarpanına göre ölçeklenen titreşim).
  Future<void> onMerge({required int tier, int combo = 1}) async {
    if (!_canTrigger()) return;
    final clampedTier = tier.clamp(1, 13);
    final clampedCombo = combo.clamp(1, 20);

    try {
      if (await _supportsCustomVibration()) {
        final primaryMs =
            math.min(120, 24 + clampedCombo * 16 + clampedTier * 5);
        await Vibration.vibrate(duration: primaryMs);
        if (clampedCombo >= 3 || clampedTier >= 6) {
          await Future<void>.delayed(const Duration(milliseconds: 55));
          if (!isEnabled || _isTestEnvironment) return;
          final secondaryMs = math.min(85, 18 + clampedCombo * 8 + clampedTier * 3);
          await Vibration.vibrate(duration: secondaryMs);
        }
        return;
      }
    } catch (_) {}

    if (clampedCombo >= 3 || clampedTier >= 6) {
      await HapticFeedback.heavyImpact();
    } else if (clampedTier >= 3 || clampedCombo == 2) {
      await HapticFeedback.mediumImpact();
    } else {
      await HapticFeedback.lightImpact();
    }
  }

  /// Zincirleme kombo (`x2`, `x4`, `x8+`) vurgu titreşimi.
  Future<void> onCombo(int combo) async {
    if (combo <= 1 || !_canTrigger()) return;
    try {
      if (await _supportsCustomVibration()) {
        final pulses = combo >= 5 ? 3 : 2;
        for (var i = 0; i < pulses; i++) {
          if (!isEnabled || _isTestEnvironment) return;
          await Vibration.vibrate(duration: math.min(90, 26 + combo * 9));
          if (i + 1 < pulses) {
            await Future<void>.delayed(const Duration(milliseconds: 45));
          }
        }
        return;
      }
    } catch (_) {}

    await HapticFeedback.heavyImpact();
  }

  /// Anne Terliği şaplağı (`ŞAK!`) — keskin darbe hissi.
  Future<void> onSlipperSlap({int combo = 1, bool golden = false}) async {
    if (!_canTrigger()) return;
    try {
      if (await _supportsCustomVibration()) {
        final duration = golden
            ? 85
            : math.min(75, 38 + combo.clamp(1, 10) * 6);
        await Vibration.vibrate(duration: duration);
        return;
      }
    } catch (_) {}

    if (golden || combo >= 3) {
      await HapticFeedback.heavyImpact();
    } else {
      await HapticFeedback.mediumImpact();
    }
  }

  /// Raid Sprey püskürtme geri bildirimi.
  Future<void> onRaidSpray() async {
    if (!_canTrigger()) return;
    try {
      if (await _supportsCustomVibration()) {
        await Vibration.vibrate(duration: 32);
        await Future<void>.delayed(const Duration(milliseconds: 40));
        if (!isEnabled || _isTestEnvironment) return;
        await Vibration.vibrate(duration: 24);
        return;
      }
    } catch (_) {}
    await HapticFeedback.mediumImpact();
  }

  /// F16 Bombardımanı ("Aydınlat Hele!") — 3 ardışık bomba şok dalgası.
  Future<void> onF16Bombardment() async {
    if (!_canTrigger()) return;
    try {
      if (await _supportsCustomVibration()) {
        for (var i = 0; i < 3; i++) {
          if (!isEnabled || _isTestEnvironment) return;
          await Vibration.vibrate(duration: 55 + i * 15);
          if (i < 2) {
            await Future<void>.delayed(const Duration(milliseconds: 65));
          }
        }
        return;
      }
    } catch (_) {}

    await HapticFeedback.heavyImpact();
  }

  /// Osmantuş ritim halkası vuruş titreşimi (`perfect` ve `combo` duyarlı).
  Future<void> onOsmantusBeat({bool perfect = false, int combo = 1}) async {
    if (!_canTrigger()) return;
    try {
      if (await _supportsCustomVibration()) {
        final duration = perfect
            ? 60
            : math.min(65, 28 + combo.clamp(1, 10) * 4);
        await Vibration.vibrate(duration: duration);
        return;
      }
    } catch (_) {}

    if (perfect || combo >= 3) {
      await HapticFeedback.heavyImpact();
    } else {
      await HapticFeedback.mediumImpact();
    }
  }

  /// Makarayız makara/nota vuruş titreşimi (`combo` duyarlı).
  Future<void> onMakaraSpin({int combo = 1}) async {
    if (!_canTrigger()) return;
    try {
      if (await _supportsCustomVibration()) {
        final duration = math.min(58, 22 + combo.clamp(1, 10) * 4);
        await Vibration.vibrate(duration: duration);
        return;
      }
    } catch (_) {}

    if (combo >= 3) {
      await HapticFeedback.mediumImpact();
    } else {
      await HapticFeedback.lightImpact();
    }
  }

  /// Çığlık Böcek zıplama / desibel darbesi titreşimi (`power` 0.0..1.0 duyarlı).
  Future<void> onScreamRoach({double power = 1.0}) async {
    if (!_canTrigger()) return;
    final p = power.clamp(0.0, 1.0);
    try {
      if (await _supportsCustomVibration()) {
        final duration = (24 + p * 46).round().clamp(24, 70);
        await Vibration.vibrate(duration: duration);
        return;
      }
    } catch (_) {}

    if (p >= 0.75) {
      await HapticFeedback.heavyImpact();
    } else if (p >= 0.4) {
      await HapticFeedback.mediumImpact();
    } else {
      await HapticFeedback.lightImpact();
    }
  }

  /// Seviye tamamlama / zafer kutlama titreşimi.
  Future<void> onLevelComplete({int stars = 3}) async {
    if (!_canTrigger()) return;
    final count = stars.clamp(1, 3);
    try {
      if (await _supportsCustomVibration()) {
        for (var i = 0; i < count; i++) {
          if (!isEnabled || _isTestEnvironment) return;
          await Vibration.vibrate(duration: 42 + i * 20);
          if (i + 1 < count) {
            await Future<void>.delayed(const Duration(milliseconds: 60));
          }
        }
        return;
      }
    } catch (_) {}

    await HapticFeedback.heavyImpact();
  }

  /// Oyun bitti / taşma darbesi.
  Future<void> onGameOver() async {
    if (!_canTrigger()) return;
    try {
      if (await _supportsCustomVibration()) {
        await Vibration.vibrate(duration: 110);
        return;
      }
    } catch (_) {}
    await HapticFeedback.heavyImpact();
  }
}
