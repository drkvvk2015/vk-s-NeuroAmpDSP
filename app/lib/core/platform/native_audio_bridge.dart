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

  /// Starts realtime native DSP demo playback on Android.
  Future<bool> startRealtimeDspDemo() async {
    try {
      final result = await _channel.invokeMethod<bool>('startRealtimeDspDemo');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Stops realtime native DSP demo playback on Android.
  Future<bool> stopRealtimeDspDemo() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopRealtimeDspDemo');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Queries whether realtime DSP demo playback is currently active.
  Future<bool> isRealtimeDspDemoRunning() async {
    try {
      final result = await _channel.invokeMethod<bool>('isRealtimeDspDemoRunning');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Starts local WAV file playback routed through native DSP.
  Future<bool> startFileDspPlayback(String filePath) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'startFileDspPlayback',
        {'filePath': filePath},
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Stops local WAV file playback routed through native DSP.
  Future<bool> stopFileDspPlayback() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopFileDspPlayback');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Returns true when local WAV file DSP playback is active.
  Future<bool> isFileDspPlaybackRunning() async {
    try {
      final result = await _channel.invokeMethod<bool>('isFileDspPlaybackRunning');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Sets post-DSP output amplifier gain in dB on Android (-18..+18 suggested).
  Future<bool> setOutputGainDb(double gainDb) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'setOutputGainDb',
        {'gainDb': gainDb},
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Returns runtime playback diagnostics from Android host.
  Future<Map<String, dynamic>?> getPlaybackStatus() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getPlaybackStatus');
      if (result == null) {
        return null;
      }

      return result.map((key, value) => MapEntry(key.toString(), value));
    } catch (_) {
      return null;
    }
  }
}