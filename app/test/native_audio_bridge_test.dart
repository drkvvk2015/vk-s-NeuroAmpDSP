import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:neuroamp_app/core/platform/native_audio_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.neuroamp/dsp');
  final bridge = NativeAudioBridge(channel: channel);

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getHeadTrackingYawDegrees returns method result', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getHeadTrackingYaw') {
        return 12.5;
      }
      return null;
    });

    final yaw = await bridge.getHeadTrackingYawDegrees();
    expect(yaw, 12.5);
  });

  test('getDspEngineVersion falls back to unknown on null', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getDspEngineVersion') {
        return null;
      }
      return null;
    });

    final version = await bridge.getDspEngineVersion();
    expect(version, 'unknown');
  });

  test('initializeDsp returns false on channel exception', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'error');
    });

    final ok = await bridge.initializeDsp(48000);
    expect(ok, isFalse);
  });

  test('processAudioFrame sends samples and returns processed list', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'processAudioFrame');
      final args = call.arguments as Map<dynamic, dynamic>;
      final samples = args['samples'] as List<dynamic>;
      expect(samples.length, 3);
      return [0.05, -0.1, 0.2];
    });

    final processed = await bridge.processAudioFrame([0.1, -0.2, 0.3]);
    expect(processed, isNotNull);
    expect(processed, [0.05, -0.1, 0.2]);
  });

  test('setDspConfig sends config payload', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'setDspConfig');
      final args = call.arguments as Map<dynamic, dynamic>;
      final config = args['config'] as Map<dynamic, dynamic>;
      expect(config['bassBoost'], 2.5);
      return true;
    });

    final ok = await bridge.setDspConfig({
      'eqBands': const [],
      'bassBoost': 2.5,
      'spatialWidth': 0.4,
      'peakLimiterDb': -2.0,
      'convolverEnabled': false,
    });
    expect(ok, isTrue);
  });

  test('requestRecordAudioPermission returns method result', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'requestRecordAudioPermission') {
        return true;
      }
      return null;
    });

    final ok = await bridge.requestRecordAudioPermission();
    expect(ok, isTrue);
  });

  test('startMicrophoneDspMonitor returns false on channel exception', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'error');
    });

    final ok = await bridge.startMicrophoneDspMonitor();
    expect(ok, isFalse);
  });

  test('setDspMode sends mode payload', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'setDspMode');
      final args = call.arguments as Map<dynamic, dynamic>;
      expect(args['mode'], 'enhanced');
      return true;
    });

    final ok = await bridge.setDspMode('enhanced');
    expect(ok, isTrue);
  });

  test('getDspModeStatus maps dynamic keys to strings', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getDspModeStatus') {
        return {
          'selectedMode': 'standard',
          'enhancedModeSupported': true,
        };
      }
      return null;
    });

    final status = await bridge.getDspModeStatus();
    expect(status?['selectedMode'], 'standard');
    expect(status?['enhancedModeSupported'], isTrue);
  });

  test('releaseDsp returns false when native returns null', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'releaseDsp') {
        return null;
      }
      return null;
    });

    final ok = await bridge.releaseDsp();
    expect(ok, isFalse);
  });
}
