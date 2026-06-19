import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/services/audio_haptic_pattern.dart';

void main() {
  group('AudioHapticPatternGenerator', () {
    test('returns no events for silence', () {
      const generator = AudioHapticPatternGenerator();
      final events = generator.generate(
        const AudioHapticAnalysis(
          frameMs: 50,
          energies: [0, 0, 0, 0, 0, 0, 0, 0],
        ),
      );

      expect(events, isEmpty);
    });

    test('detects transient spikes and respects minimum spacing', () {
      const generator = AudioHapticPatternGenerator();
      final events = generator.generate(
        const AudioHapticAnalysis(
          frameMs: 50,
          energies: [
            0.01,
            0.01,
            0.02,
            0.86,
            0.12,
            0.08,
            0.02,
            0.9,
            0.13,
            0.02,
          ],
        ),
      );

      expect(events, isNotEmpty);
      for (var i = 1; i < events.length; i++) {
        expect(
          events[i].timeMs - events[i - 1].timeMs,
          greaterThanOrEqualTo(AudioHapticPatternGenerator.minEventIntervalMs),
        );
      }
    });
  });

  group('StreamingAudioHapticPatternGenerator', () {
    test('appends new frames without replaying overlapping chunks', () {
      final generator = StreamingAudioHapticPatternGenerator(
        frameMs: 50,
        userIntensity: 1,
      );

      final first = generator.append(
        startFrame: 0,
        energies: const [0.01, 0.01, 0.02, 0.9, 0.08, 0.02],
      );
      final second = generator.append(
        startFrame: 3,
        energies: const [0.9, 0.08, 0.02, 0.88, 0.09, 0.02],
      );

      final combined = [...first, ...second];
      expect(
          combined.map((event) => event.timeMs).toSet(),
          hasLength(
            combined.length,
          ));
      expect(combined.every((event) => event.timeMs >= 0), isTrue);
    });

    test('scales event intensity with user intensity', () {
      final low = StreamingAudioHapticPatternGenerator(
        frameMs: 50,
        userIntensity: 0.4,
      );
      final high = StreamingAudioHapticPatternGenerator(
        frameMs: 50,
        userIntensity: 1.0,
      );
      const energies = [0.01, 0.01, 0.02, 0.92, 0.08, 0.02, 0.9, 0.08];

      final lowEvents = low.append(startFrame: 0, energies: energies);
      final highEvents = high.append(startFrame: 0, energies: energies);

      expect(lowEvents, isNotEmpty);
      expect(highEvents, isNotEmpty);
      expect(
          highEvents.first.intensity, greaterThan(lowEvents.first.intensity));
    });
  });
}
