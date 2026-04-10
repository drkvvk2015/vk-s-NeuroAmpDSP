import 'dart:developer' as dev;

import 'package:flutter/services.dart';

class NativeAudioBridge {
  NativeAudioBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'com.neuroamp/dsp';
  final MethodChannel _channel;

  void _logFailure(String operation, Object error, [StackTrace? stackTrace]) {
    dev.log(
      'Native bridge call failed: $operation | $error',
      name: 'NeuroAmp.NativeAudioBridge',
      error: error,
      stackTrace: stackTrace,
    );
  }

  Future<double?> getHeadTrackingYawDegrees() async {
    try {
      final value = await _channel.invokeMethod<double>('getHeadTrackingYaw');
      return value;
    } catch (error, stackTrace) {
      _logFailure('getHeadTrackingYaw', error, stackTrace);
      return null;
    }
  }

  Future<String> getDspEngineVersion() async {
    try {
      final value = await _channel.invokeMethod<String>('getDspEngineVersion');
      return value ?? 'unknown';
    } catch (error, stackTrace) {
      _logFailure('getDspEngineVersion', error, stackTrace);
      return 'unknown';
    }
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
    } catch (error, stackTrace) {
      _logFailure('processAudioFrame', error, stackTrace);
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
    } catch (error, stackTrace) {
      _logFailure('setDspConfig', error, stackTrace);
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
    } catch (error, stackTrace) {
      _logFailure('initializeDsp', error, stackTrace);
      return false;
    }
  }

  /// Release native DSP engine resources.
  Future<bool> releaseDsp() async {
    try {
      final result = await _channel.invokeMethod<bool>('releaseDsp');
      return result ?? false;
    } catch (error, stackTrace) {
      _logFailure('releaseDsp', error, stackTrace);
      return false;
    }
  }

  /// Starts realtime native DSP demo playback on Android.
  Future<bool> startRealtimeDspDemo() async {
    try {
      final result = await _channel.invokeMethod<bool>('startRealtimeDspDemo');
      return result ?? false;
    } catch (error, stackTrace) {
      _logFailure('startRealtimeDspDemo', error, stackTrace);
      return false;
    }
  }

  /// Stops realtime native DSP demo playback on Android.
  Future<bool> stopRealtimeDspDemo() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopRealtimeDspDemo');
      return result ?? false;
    } catch (error, stackTrace) {
      _logFailure('stopRealtimeDspDemo', error, stackTrace);
      return false;
    }
  }

  /// Queries whether realtime DSP demo playback is currently active.
  Future<bool> isRealtimeDspDemoRunning() async {
    try {
      final result = await _channel.invokeMethod<bool>('isRealtimeDspDemoRunning');
      return result ?? false;
    } catch (error, stackTrace) {
      _logFailure('isRealtimeDspDemoRunning', error, stackTrace);
      return false;
    }
  }

  Future<bool> requestRecordAudioPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestRecordAudioPermission');
      return result ?? false;
    } catch (error, stackTrace) {
      _logFailure('requestRecordAudioPermission', error, stackTrace);
      return false;
    }
  }

  Future<bool> hasRecordAudioPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasRecordAudioPermission');
      return result ?? false;
    } catch (error, stackTrace) {
      _logFailure('hasRecordAudioPermission', error, stackTrace);
      return false;
    }
  }

  Future<bool> startMicrophoneDspMonitor() async {
    try {
      final result = await _channel.invokeMethod<bool>('startMicrophoneDspMonitor');
      return result ?? false;
    } catch (error, stackTrace) {
      _logFailure('startMicrophoneDspMonitor', error, stackTrace);
      return false;
    }
  }

  Future<bool> stopMicrophoneDspMonitor() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopMicrophoneDspMonitor');
      return result ?? false;
    } catch (error, stackTrace) {
      _logFailure('stopMicrophoneDspMonitor', error, stackTrace);
      return false;
    }
  }

  Future<bool> isMicrophoneDspMonitorRunning() async {
    try {
      final result = await _channel.invokeMethod<bool>('isMicrophoneDspMonitorRunning');
      return result ?? false;
    } catch (error, stackTrace) {
      _logFailure('isMicrophoneDspMonitorRunning', error, stackTrace);
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
    } catch (error, stackTrace) {
      _logFailure('startFileDspPlayback', error, stackTrace);
      return false;
    }
  }

  /// Stops local WAV file playback routed through native DSP.
  Future<bool> stopFileDspPlayback() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopFileDspPlayback');
      return result ?? false;
    } catch (error, stackTrace) {
      _logFailure('stopFileDspPlayback', error, stackTrace);
      return false;
    }
  }

  /// Returns true when local WAV file DSP playback is active.
  Future<bool> isFileDspPlaybackRunning() async {
    try {
      final result = await _channel.invokeMethod<bool>('isFileDspPlaybackRunning');
      return result ?? false;
    } catch (error, stackTrace) {
      _logFailure('isFileDspPlaybackRunning', error, stackTrace);
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
    } catch (error, stackTrace) {
      _logFailure('setOutputGainDb', error, stackTrace);
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
    } catch (error, stackTrace) {
      _logFailure('getPlaybackStatus', error, stackTrace);
      return null;
    }
  }
}