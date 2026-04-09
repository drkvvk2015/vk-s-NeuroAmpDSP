import '../domain/dsp_profile.dart';

class AdaptiveTuningService {
  const AdaptiveTuningService();

  // Applies lightweight contextual tuning based on noise and speed heuristics.
  DspProfile tune({
    required DspProfile profile,
    required double ambientNoiseDb,
    required double vehicleSpeedKph,
  }) {
    double bassDelta = 0;
    double widthDelta = 0;

    if (ambientNoiseDb > 70) {
      bassDelta += 1.25;
      widthDelta -= 0.1;
    }

    if (vehicleSpeedKph > 80) {
      bassDelta += 0.75;
      widthDelta -= 0.05;
    }

    return profile.copyWith(
      bassBoost: (profile.bassBoost + bassDelta).clamp(0, 6),
      spatialWidth: (profile.spatialWidth + widthDelta).clamp(0.0, 1.0),
    );
  }
}
