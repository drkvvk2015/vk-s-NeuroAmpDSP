import 'package:flutter_test/flutter_test.dart';

import 'package:neuroamp_app/features/audio/domain/dsp_profile.dart';

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
}
