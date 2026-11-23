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

    test('parses explicit vibration and pause tokens (v300, p150, v1200)', () {
      final steps = CustomVibration.parseSequenceString('v300, p150, v1200, p400');
      expect(steps.length, 4);
      expect(steps[0].type, VibrationStepType.vibrate);
      expect(steps[0].durationMs, 300);
      expect(steps[1].type, VibrationStepType.pause);
      expect(steps[1].durationMs, 150);
      expect(steps[2].type, VibrationStepType.vibrate);
      expect(steps[2].durationMs, 1200);
      expect(steps[3].type, VibrationStepType.pause);
      expect(steps[3].durationMs, 400);
    });

    test('calculates total duration in ms accurately', () {
      const v = CustomVibration(
        id: 'c1',
        name: 'custom',
        steps: [
          VibrationStep.vibrate(300),
          VibrationStep.pause(200),
          VibrationStep.vibrate(600),
        ],
      );
      expect(v.totalDurationMs, 1100);
    });

    test('serializes to and from JSON', () {
      const v = CustomVibration(
        id: '123',
        name: 'banca',
        steps: [
          VibrationStep.vibrate(350),
          VibrationStep.pause(150),
          VibrationStep.vibrate(700),
        ],
      );

      final json = v.toJson();
      final restored = CustomVibration.fromJson(json);

      expect(restored.id, '123');
      expect(restored.name, 'banca');
      expect(restored.steps.length, 3);
      expect(restored.steps[0].type, VibrationStepType.vibrate);
      expect(restored.steps[0].durationMs, 350);
      expect(restored.steps[1].type, VibrationStepType.pause);
      expect(restored.steps[1].durationMs, 150);
      expect(restored.steps[2].type, VibrationStepType.vibrate);
      expect(restored.steps[2].durationMs, 700);
    });
  });
}
