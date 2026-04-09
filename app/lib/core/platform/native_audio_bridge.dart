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

  /// Process audio frame through native DSP engine.
  /// Returns true if processing succeeded, false otherwise.
  Future<bool> processAudioFrame(List<double> inputSamples) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'processAudioFrame',
        {'samples': inputSamples},
      );
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Initialize native DSP engine with sample rate.
  Future<bool> initializeDsp(int sampleRate) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'initializeDsp',
        {'sampleRate': sampleRate},
      );
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Release native DSP engine resources.
  Future<bool> releaseDsp() async {
    try {
      final result = await _channel.invokeMethod<bool>('releaseDsp');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
}