import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/models/vibration_pattern.dart';

void main() {
  group('VibrationPattern Model & Presets', () {
    test('resolves built-in presets by name', () {
      expect(CustomVibration.resolvePreset('single'), isNotNull);
      expect(CustomVibration.resolvePreset('SINGOLA'), isNotNull);
      expect(CustomVibration.resolvePreset('double'), isNotNull);
      expect(CustomVibration.resolvePreset('doppia'), isNotNull);
      expect(CustomVibration.resolvePreset('triple'), isNotNull);
      expect(CustomVibration.resolvePreset('tripla'), isNotNull);
      expect(CustomVibration.resolvePreset('alarm'), isNotNull);
      expect(CustomVibration.resolvePreset('allarme'), isNotNull);
      expect(CustomVibration.resolvePreset('sos'), isNotNull);
      expect(CustomVibration.resolvePreset('unknown_preset'), isNull);
    });

    test('parses comma-separated sequence string', () {
      final steps = CustomVibration.parseSequenceString('0, 200, 2, 400, 1');
      expect(steps.length, 5);
      expect(steps[0].type, VibrationStepType.single);
      expect(steps[1].type, VibrationStepType.pause);
      expect(steps[1].durationMs, 200);
      expect(steps[2].type, VibrationStepType.doubleTap);
      expect(steps[3].type, VibrationStepType.pause);
      expect(steps[3].durationMs, 400);
      expect(steps[4].type, VibrationStepType.alarm);
    });

    test('serializes to and from JSON', () {
      const v = CustomVibration(
        id: '123',
        name: 'banca',
        steps: [
          VibrationStep(VibrationStepType.single),
          VibrationStep(VibrationStepType.pause, 150),
          VibrationStep(VibrationStepType.doubleTap),
        ],
      );

      final json = v.toJson();
      final restored = CustomVibration.fromJson(json);

      expect(restored.id, '123');
      expect(restored.name, 'banca');
      expect(restored.steps.length, 3);
      expect(restored.steps[0].type, VibrationStepType.single);
      expect(restored.steps[1].type, VibrationStepType.pause);
      expect(restored.steps[1].durationMs, 150);
      expect(restored.steps[2].type, VibrationStepType.doubleTap);
    });
  });
}
