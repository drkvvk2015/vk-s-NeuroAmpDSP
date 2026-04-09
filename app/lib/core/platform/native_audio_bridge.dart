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

  /// Process an audio frame through native DSP engine.
  /// Returns processed samples when successful, otherwise null.
  Future<List<double>?> processAudioFrame(List<double> inputSamples) async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'processAudioFrame',
        {'samples': inputSamples},
      );
      if (result == null) {
        return null;
      }

      return result
          .map((sample) => (sample as num).toDouble())
          .toList(growable: false);
    } catch (e) {
      return null;
    }
  }

  /// Pushes latest DSP configuration values to native runtime.
  Future<bool> setDspConfig(Map<String, dynamic> config) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'setDspConfig',
        {'config': config},
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