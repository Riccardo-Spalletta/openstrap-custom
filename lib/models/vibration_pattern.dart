// vibration_pattern.dart — model for custom haptic vibration patterns.
// Supports multi-step sequences of pulses and pauses, serialization to JSON,
// and presets.

enum VibrationStepType {
  single,    // pattern 0: short pulse (~400ms)
  doubleTap, // pattern 2: two rapid pulses (~950ms)
  alarm,     // pattern 1: long/continuous alarm pulse (~2000ms)
  vibrate,   // custom vibration with explicit durationMs
  pause,     // silence delay in milliseconds
}

class VibrationStep {
  final VibrationStepType type;
  final int durationMs; // used for pause, or custom vibrate duration in ms

  const VibrationStep(this.type, [this.durationMs = 250]);

  const VibrationStep.vibrate(int durationMs)
      : type = VibrationStepType.vibrate,
        durationMs = durationMs;

  const VibrationStep.pause(int durationMs)
      : type = VibrationStepType.pause,
        durationMs = durationMs;

  bool get isPause => type == VibrationStepType.pause;
  bool get isVibration => type != VibrationStepType.pause;

  int get effectiveDurationMs {
    switch (type) {
      case VibrationStepType.single:
        return 400;
      case VibrationStepType.doubleTap:
        return 950;
      case VibrationStepType.alarm:
        return 2000;
      case VibrationStepType.vibrate:
      case VibrationStepType.pause:
        return durationMs;
    }
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'durationMs': durationMs,
      };

  factory VibrationStep.fromJson(Map<String, dynamic> j) {
    final typeName = j['type'] as String? ?? 'single';
    final type = VibrationStepType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => VibrationStepType.single,
    );
    final duration = (j['durationMs'] as num?)?.toInt() ?? 250;
    return VibrationStep(type, duration);
  }

  String get label {
    switch (type) {
      case VibrationStepType.single:
        return 'Tocco Singolo (400ms)';
      case VibrationStepType.doubleTap:
        return 'Doppio Tocco (950ms)';
      case VibrationStepType.alarm:
        return 'Allarme Continuo (2s)';
      case VibrationStepType.vibrate:
        return durationMs >= 1000 && durationMs % 100 == 0
            ? 'Vibrazione ${(durationMs / 1000).toStringAsFixed(1)}s'
            : 'Vibrazione ${durationMs}ms';
      case VibrationStepType.pause:
        return durationMs >= 1000 && durationMs % 100 == 0
            ? 'Pausa ${(durationMs / 1000).toStringAsFixed(1)}s'
            : 'Pausa ${durationMs}ms';
    }
  }
}

class CustomVibration {
  final String id;
  final String name;
  final List<VibrationStep> steps;

  const CustomVibration({
    required this.id,
    required this.name,
    required this.steps,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'steps': steps.map((s) => s.toJson()).toList(),
      };

  factory CustomVibration.fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String? ?? '';
    final name = j['name'] as String? ?? '';
    final rawSteps = (j['steps'] as List?) ?? [];
    final steps = rawSteps
        .whereType<Map>()
        .map((m) => VibrationStep.fromJson(m.cast<String, dynamic>()))
        .toList();
    return CustomVibration(id: id, name: name, steps: steps);
  }

  static const List<VibrationStep> presetSingle = [
    VibrationStep(VibrationStepType.single),
  ];

  static const List<VibrationStep> presetDouble = [
    VibrationStep(VibrationStepType.doubleTap),
  ];

  static const List<VibrationStep> presetTriple = [
    VibrationStep(VibrationStepType.single),
    VibrationStep(VibrationStepType.pause, 200),
    VibrationStep(VibrationStepType.single),
    VibrationStep(VibrationStepType.pause, 200),
    VibrationStep(VibrationStepType.single),
  ];

  static const List<VibrationStep> presetAlarm = [
    VibrationStep(VibrationStepType.alarm),
  ];

  static const List<VibrationStep> presetSos = [
    VibrationStep(VibrationStepType.single),
    VibrationStep(VibrationStepType.pause, 150),
    VibrationStep(VibrationStepType.single),
    VibrationStep(VibrationStepType.pause, 150),
    VibrationStep(VibrationStepType.single),
    VibrationStep(VibrationStepType.pause, 400),
    VibrationStep(VibrationStepType.alarm),
    VibrationStep(VibrationStepType.pause, 400),
    VibrationStep(VibrationStepType.single),
    VibrationStep(VibrationStepType.pause, 150),
    VibrationStep(VibrationStepType.single),
  ];

  /// Resolve a preset by name (case-insensitive).
  static List<VibrationStep>? resolvePreset(String name) {
    switch (name.trim().toLowerCase()) {
      case 'single':
      case 'singola':
        return presetSingle;
      case 'double':
      case 'doppia':
        return presetDouble;
      case 'triple':
      case 'tripla':
        return presetTriple;
      case 'alarm':
      case 'allarme':
        return presetAlarm;
      case 'sos':
      case 'emergenza':
        return presetSos;
      default:
        return null;
    }
  }

  /// Total effective duration in milliseconds of this custom vibration.
  int get totalDurationMs {
    var total = 0;
    for (final s in steps) {
      total += s.effectiveDurationMs;
    }
    return total;
  }

  /// Parse a sequence string e.g.:
  /// - "v300, p200, v500" (explicit vibration and pause durations in ms)
  /// - "0, 200, 2" (legacy pattern 0=single, 1=alarm, 2=double, >=10=pause)
  /// - "single, 200, double" (named tokens)
  static List<VibrationStep> parseSequenceString(String seq) {
    final tokens = seq.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty);
    final result = <VibrationStep>[];
    for (final token in tokens) {
      final lower = token.toLowerCase();

      // Check for v<ms> / vib<ms> / buzz<ms>
      if (lower.startsWith('v') || lower.startsWith('buzz') || lower.endsWith('v')) {
        final digits = lower.replaceAll(RegExp(r'[^0-9]'), '');
        final ms = int.tryParse(digits) ?? 400;
        result.add(VibrationStep(VibrationStepType.vibrate, ms.clamp(50, 10000)));
        continue;
      }

      // Check for p<ms> / pause<ms>
      if (lower.startsWith('p') || lower.endsWith('p')) {
        final digits = lower.replaceAll(RegExp(r'[^0-9]'), '');
        final ms = int.tryParse(digits) ?? 200;
        result.add(VibrationStep(VibrationStepType.pause, ms.clamp(50, 10000)));
        continue;
      }

      // Direct integer
      final numVal = int.tryParse(token);
      if (numVal != null) {
        if (numVal == 0) {
          result.add(const VibrationStep(VibrationStepType.single));
        } else if (numVal == 1) {
          result.add(const VibrationStep(VibrationStepType.alarm));
        } else if (numVal == 2) {
          result.add(const VibrationStep(VibrationStepType.doubleTap));
        } else if (numVal >= 10) {
          result.add(VibrationStep(VibrationStepType.pause, numVal.clamp(50, 10000)));
        }
      } else {
        if (lower == 'single' || lower == 's') {
          result.add(const VibrationStep(VibrationStepType.single));
        } else if (lower == 'double' || lower == 'd') {
          result.add(const VibrationStep(VibrationStepType.doubleTap));
        } else if (lower == 'alarm' || lower == 'a') {
          result.add(const VibrationStep(VibrationStepType.alarm));
        }
      }
    }
    return result.isNotEmpty ? result : presetDouble;
  }
}
