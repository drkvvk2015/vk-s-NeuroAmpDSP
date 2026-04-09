import 'package:flutter_test/flutter_test.dart';

import 'package:neuroamp_app/core/logging/app_logger.dart';
import 'package:neuroamp_app/core/platform/native_audio_bridge.dart';
import 'package:neuroamp_app/features/audio/application/adaptive_tuning_service.dart';
import 'package:neuroamp_app/features/audio/application/audio_controller.dart';
import 'package:neuroamp_app/features/audio/application/head_tracking_service.dart';
import 'package:neuroamp_app/features/audio/data/profile_repository.dart';
import 'package:neuroamp_app/features/audio/domain/dsp_profile.dart';

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository(this.profile);

  DspProfile profile;
  int saveCount = 0;

  @override
  Future<DspProfile> load() async => profile;

  @override
  Future<void> save(DspProfile profile) async {
    this.profile = profile;
    saveCount++;
  }
}

class _FakeNativeAudioBridge extends NativeAudioBridge {
  _FakeNativeAudioBridge() : super();

  int initializeCalls = 0;
  int releaseCalls = 0;
  int setConfigCalls = 0;
  int startRealtimeCalls = 0;
  int stopRealtimeCalls = 0;
  int startFileCalls = 0;
  int stopFileCalls = 0;
  Map<String, dynamic>? lastConfig;
  List<double>? processFrameResponse;

  @override
  Future<bool> initializeDsp(int sampleRate) async {
    initializeCalls++;
    return true;
  }

  @override
  Future<bool> releaseDsp() async {
    releaseCalls++;
    return true;
  }

  @override
  Future<bool> setDspConfig(Map<String, dynamic> config) async {
    setConfigCalls++;
    lastConfig = config;
    return true;
  }

  @override
  Future<List<double>?> processAudioFrame(List<double> inputSamples) async {
    return processFrameResponse ?? inputSamples;
  }

  @override
  Future<bool> startRealtimeDspDemo() async {
    startRealtimeCalls++;
    return true;
  }

  @override
  Future<bool> stopRealtimeDspDemo() async {
    stopRealtimeCalls++;
    return true;
  }

  @override
  Future<bool> startFileDspPlayback(String filePath) async {
    startFileCalls++;
    return true;
  }

  @override
  Future<bool> stopFileDspPlayback() async {
    stopFileCalls++;
    return true;
  }
}

void main() {
  test('initialize loads profile and syncs native config', () async {
    final repo = _FakeProfileRepository(DspProfile.defaultProfile());
    final bridge = _FakeNativeAudioBridge();
    final controller = AudioController(
      repo,
      const AdaptiveTuningService(),
      HeadTrackingService(bridge),
      bridge,
      const AppLogger(),
    );

    await controller.initialize();

    expect(bridge.initializeCalls, 1);
    expect(bridge.setConfigCalls, 1);
    expect(controller.state.value, isNotNull);
  });

  test('update persists profile and syncs native config', () async {
    final repo = _FakeProfileRepository(DspProfile.defaultProfile());
    final bridge = _FakeNativeAudioBridge();
    final controller = AudioController(
      repo,
      const AdaptiveTuningService(),
      HeadTrackingService(bridge),
      bridge,
      const AppLogger(),
    );

    await controller.initialize();
    final updated = DspProfile.defaultProfile().copyWith(
      bassBoost: 3.0,
      spatialWidth: 0.5,
    );
    await controller.update(updated);

    expect(repo.saveCount, 1);
    expect(bridge.setConfigCalls, 2);
    expect((bridge.lastConfig?['bassBoost'] as num).toDouble(), 3.0);
    expect((bridge.lastConfig?['spatialWidth'] as num).toDouble(), 0.5);
  });

  test('dispose releases native dsp resources', () async {
    final repo = _FakeProfileRepository(DspProfile.defaultProfile());
    final bridge = _FakeNativeAudioBridge();
    final controller = AudioController(
      repo,
      const AdaptiveTuningService(),
      HeadTrackingService(bridge),
      bridge,
      const AppLogger(),
    );

    controller.dispose();

    expect(bridge.releaseCalls, 1);
  });

  test('runDspProbe reports changed=true when output differs', () async {
    final repo = _FakeProfileRepository(DspProfile.defaultProfile());
    final bridge = _FakeNativeAudioBridge();
    bridge.processFrameResponse = List<double>.filled(512, 0.0);
    final controller = AudioController(
      repo,
      const AdaptiveTuningService(),
      HeadTrackingService(bridge),
      bridge,
      const AppLogger(),
    );

    final result = await controller.runDspProbe();

    expect(result.succeeded, isTrue);
    expect(result.changed, isTrue);
    expect(result.meanAbsDelta, isNotNull);
  });

  test('startFilePlayback delegates to native bridge', () async {
    final repo = _FakeProfileRepository(DspProfile.defaultProfile());
    final bridge = _FakeNativeAudioBridge();
    final controller = AudioController(
      repo,
      const AdaptiveTuningService(),
      HeadTrackingService(bridge),
      bridge,
      const AppLogger(),
    );

    await controller.initialize();
    final started = await controller.startFilePlayback('C:/music/demo.wav');

    expect(started, isTrue);
    expect(bridge.startFileCalls, 1);
  });
}
