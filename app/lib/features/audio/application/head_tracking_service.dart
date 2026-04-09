import '../../../core/platform/native_audio_bridge.dart';

class HeadTrackingService {
  HeadTrackingService(
    this._nativeBridge, {
    this.smoothingFactor = 0.15,
  });

  final NativeAudioBridge _nativeBridge;
  final double smoothingFactor;
  double? _smoothedYawDegrees;

  Future<double?> readYawDegrees() async {
    return _nativeBridge.getHeadTrackingYawDegrees();
  }

  Future<double?> readSmoothedYawDegrees() async {
    final yaw = await readYawDegrees();
    if (yaw == null) {
      return _smoothedYawDegrees;
    }

    final current = _smoothedYawDegrees;
    if (current == null) {
      _smoothedYawDegrees = yaw;
      return yaw;
    }

    _smoothedYawDegrees = current + (smoothingFactor * (yaw - current));
    return _smoothedYawDegrees;
  }

  void resetSmoothing() {
    _smoothedYawDegrees = null;
  }

  Future<double> computeSpatialOffset(double yawDegrees) async {
    final normalized = yawDegrees.clamp(-60.0, 60.0) / 60.0;
    return normalized;
  }
}
