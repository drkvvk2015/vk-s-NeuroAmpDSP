import '../../../core/platform/native_audio_bridge.dart';

class HeadTrackingService {
  const HeadTrackingService(this._nativeBridge);

  final NativeAudioBridge _nativeBridge;

  Future<double?> readYawDegrees() async {
    return _nativeBridge.getHeadTrackingYawDegrees();
  }

  Future<double> computeSpatialOffset(double yawDegrees) async {
    final normalized = yawDegrees.clamp(-60.0, 60.0) / 60.0;
    return normalized;
  }
}
