// vibration_pattern.dart — model for custom haptic vibration patterns.
// Supports multi-step sequences of pulses and pauses, serialization to JSON,
// and presets.

enum VibrationStepType {
  single,    // pattern 0: short crisp tap (~120ms)
  doubleTap, // pattern 2: two rapid pulses
  alarm,     // pattern 1: long/continuous alarm pulse
  pause,     // silence delay in milliseconds
}

class VibrationStep {
  final VibrationStepType type;
  final int durationMs; // used for pause, or display delay

  const VibrationStep(this.type, [this.durationMs = 250]);

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
        return 'Tocco Singolo';
      case VibrationStepType.doubleTap:
        return 'Doppio Tocco';
      case VibrationStepType.alarm:
        return 'Vibrazione Lunga';
      case VibrationStepType.pause:
        return 'Pausa (${durationMs}ms)';
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

  /// Parse a comma-separated sequence string e.g. "0,200,0,200,2".
  /// Numbers 0, 1, 2 represent patterns; numbers >= 10 represent pause durations.
  static List<VibrationStep> parseSequenceString(String seq) {
    final tokens = seq.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty);
    final result = <VibrationStep>[];
    for (final token in tokens) {
      final numVal = int.tryParse(token);
      if (numVal != null) {
        if (numVal == 0) {
          result.add(const VibrationStep(VibrationStepType.single));
        } else if (numVal == 1) {
          result.add(const VibrationStep(VibrationStepType.alarm));
        } else if (numVal == 2) {
          result.add(const VibrationStep(VibrationStepType.doubleTap));
        } else if (numVal >= 10) {
          result.add(VibrationStep(VibrationStepType.pause, numVal.clamp(50, 3000)));
        }
      } else {
        final lower = token.toLowerCase();
        if (lower == 'single' || lower == 's') {
          result.add(const VibrationStep(VibrationStepType.single));
        } else if (lower == 'double' || lower == 'd') {
          result.add(const VibrationStep(VibrationStepType.doubleTap));
        } else if (lower == 'alarm' || lower == 'a') {
          result.add(const VibrationStep(VibrationStepType.alarm));
        } else if (lower.startsWith('p') || lower.startsWith('pause')) {
          final ms = int.tryParse(lower.replaceAll(RegExp(r'[^0-9]'), '')) ?? 250;
          result.add(VibrationStep(VibrationStepType.pause, ms));
        }
      }
    }
    return result.isNotEmpty ? result : presetDouble;
  }
}
