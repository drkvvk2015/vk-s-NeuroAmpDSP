import 'package:flutter/services.dart';

class NativeAudioBridge {
  NativeAudioBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'com.neuroamp/dsp';
  final MethodChannel _channel;

  Future<double?> getHeadTrackingYawDegrees() async {
    final value = await _channel.invokeMethod<double>('getHeadTrackingYaw');
    return value;
  }

  Future<String> getDspEngineVersion() async {
    final value = await _channel.invokeMethod<String>('getDspEngineVersion');
    return value ?? 'unknown';
  }
}