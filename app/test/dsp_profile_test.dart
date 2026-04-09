import 'package:flutter_test/flutter_test.dart';

import 'package:neuroamp_app/features/audio/domain/dsp_profile.dart';
import 'package:neuroamp_app/features/audio/domain/eq_band.dart';

void main() {
  test('profile encode/decode should preserve fields', () {
    final initial = DspProfile.defaultProfile().copyWith(
      bassBoost: 2.0,
      spatialWidth: 0.6,
      peakLimiterDb: -0.5,
    );

    final decoded = DspProfile.decode(initial.encode());

    expect(decoded.name, initial.name);
    expect(decoded.bassBoost, initial.bassBoost);
    expect(decoded.spatialWidth, initial.spatialWidth);
    expect(decoded.peakLimiterDb, initial.peakLimiterDb);
    expect(decoded.eqBands.length, initial.eqBands.length);
  });

  test('decode supports legacy payload missing newer fields', () {
    const raw =
        '{"name":"Legacy","eqBands":[{"frequencyHz":1000,"gainDb":1.5,"q":1.0}],"spatialWidth":0.4,"bassBoost":2.0,"convolverEnabled":false}';

    final decoded = DspProfile.decode(raw);

    expect(decoded.name, 'Legacy');
    expect(decoded.eqBands, isA<List<EqBand>>());
    expect(decoded.eqBands.length, 1);
    expect(decoded.aiAdaptiveEnabled, isTrue);
    expect(decoded.headTrackingEnabled, isFalse);
    expect(decoded.peakLimiterDb, -1.0);
  });
}
