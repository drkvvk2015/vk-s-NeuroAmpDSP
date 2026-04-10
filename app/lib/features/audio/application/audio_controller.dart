import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;

import '../../../core/logging/app_logger.dart';
import '../../../core/platform/native_audio_bridge.dart';
import '../data/local_profile_repository.dart';
import '../data/profile_repository.dart';
import '../domain/dsp_profile.dart';
import 'adaptive_tuning_service.dart';
import 'head_tracking_service.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return LocalProfileRepository();
});

final adaptiveTuningServiceProvider = Provider<AdaptiveTuningService>((ref) {
  return const AdaptiveTuningService();
});

final nativeAudioBridgeProvider = Provider<NativeAudioBridge>((ref) {
  return NativeAudioBridge();
});

final dspVersionProvider = FutureProvider<String>((ref) async {
  final bridge = ref.read(nativeAudioBridgeProvider);
  return bridge.getDspEngineVersion();
});

final headTrackingServiceProvider = Provider<HeadTrackingService>((ref) {
  final nativeBridge = ref.read(nativeAudioBridgeProvider);
  return HeadTrackingService(nativeBridge);
});

final appLoggerProvider = Provider<AppLogger>((ref) => const AppLogger());

final audioControllerProvider =
    StateNotifierProvider<AudioController, AsyncValue<DspProfile>>((ref) {
      final repo = ref.read(profileRepositoryProvider);
      final tuning = ref.read(adaptiveTuningServiceProvider);
      final tracking = ref.read(headTrackingServiceProvider);
      final bridge = ref.read(nativeAudioBridgeProvider);
      final logger = ref.read(appLoggerProvider);
      return AudioController(repo, tuning, tracking, bridge, logger)..initialize();
    });

class AudioController extends StateNotifier<AsyncValue<DspProfile>> {
  AudioController(
    this._repository,
    this._adaptiveTuningService,
    this._headTrackingService,
    this._nativeAudioBridge,
    this._logger,
  ) : super(const AsyncValue.loading());

  final ProfileRepository _repository;
  final AdaptiveTuningService _adaptiveTuningService;
  final HeadTrackingService _headTrackingService;
  final NativeAudioBridge _nativeAudioBridge;
  final AppLogger _logger;
  Timer? _adaptiveLoopTimer;
  bool _realtimeDemoRunning = false;
  bool _filePlaybackRunning = false;
  bool _microphoneMonitorRunning = false;
  int _adaptiveTick = 0;
  DspProfile? _profileBeforeBypass;
  bool _bypassEnabled = false;
  double _outputGainDb = 0.0;

  Future<void> initialize() async {
    try {
      final initialized = await _nativeAudioBridge.initializeDsp(48000);
      if (!initialized) {
        _logger.warning('Native DSP initialization failed; app will continue in degraded mode');
      }

      final profile = await _repository.load();
      state = AsyncValue.data(profile);
      await _syncConfigToNative(profile);
    } catch (error, stackTrace) {
      _logger.error('Failed to initialize audio profile', error: error, stackTrace: stackTrace);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> update(DspProfile profile) async {
    await _applyProfile(profile, persist: true);

    if (_isAnyPlaybackRunning) {
      if (profile.aiAdaptiveEnabled) {
        _startAdaptiveLoop();
      } else {
        _stopAdaptiveLoop();
      }
    }
  }

  Future<void> _applyProfile(DspProfile profile, {required bool persist}) async {
    state = AsyncValue.data(profile);
    if (persist) {
      await _repository.save(profile);
    }
    await _syncConfigToNative(profile);
  }

  Future<void> applyAdaptiveTuning({
    required double ambientNoiseDb,
    required double vehicleSpeedKph,
  }) async {
    final current = state.value;
    if (current == null || !current.aiAdaptiveEnabled) {
      return;
    }

    final tuned = _adaptiveTuningService.tune(
      profile: current,
      ambientNoiseDb: ambientNoiseDb,
      vehicleSpeedKph: vehicleSpeedKph,
    );
    await update(tuned);
  }

  Future<void> applyHeadTracking(double yawDegrees) async {
    final current = state.value;
    if (current == null || !current.headTrackingEnabled) {
      return;
    }

    final offset = await _headTrackingService.computeSpatialOffset(yawDegrees);
    await update(
      current.copyWith(
        spatialWidth: (current.spatialWidth + (offset * 0.1)).clamp(0.0, 1.0),
      ),
    );
  }

  Future<void> syncHeadTrackingFromDevice() async {
    final yaw = await _headTrackingService.readSmoothedYawDegrees();
    if (yaw == null) {
      _logger.warning('No head-tracking yaw available from native bridge');
      return;
    }
    await applyHeadTracking(yaw);
  }

  Future<void> _syncConfigToNative(DspProfile profile) async {
    final success = await _nativeAudioBridge.setDspConfig({
      'eqBands': profile.eqBands.map((band) => band.toJson()).toList(growable: false),
      'bassBoost': profile.bassBoost,
      'spatialWidth': profile.spatialWidth,
      'peakLimiterDb': profile.peakLimiterDb,
      'convolverEnabled': profile.convolverEnabled,
    });

    if (!success) {
      _logger.warning('Failed to sync profile to native DSP engine');
    }
  }

  Future<DspBridgeDiagnostic> runBridgeDiagnostic() async {
    final initialized = await _nativeAudioBridge.initializeDsp(48000);
    final version = await _nativeAudioBridge.getDspEngineVersion();
    final yaw = await _nativeAudioBridge.getHeadTrackingYawDegrees();
    final playbackStatus = await _nativeAudioBridge.getPlaybackStatus();
    final dspReady = playbackStatus?['dspReady'] == true;
    final lastError = playbackStatus?['lastError']?.toString();

    final issues = <String>[];
    if (!initialized) {
      issues.add('initializeDsp returned false');
    }
    if (version == 'unknown' || version == 'dsp-native-unavailable') {
      issues.add('DSP version unavailable');
    }
    if (!dspReady) {
      issues.add('Native playback status reports DSP not ready');
    }
    if (lastError != null && lastError.isNotEmpty && lastError != 'none' && lastError != 'idle') {
      issues.add('Native lastError=$lastError');
    }

    final summary = issues.isEmpty
        ? 'Bridge OK: initialize/version/status calls succeeded.'
        : 'Bridge diagnostic found issues: ${issues.join('; ')}';

    _logger.info(
      'DSP bridge diagnostic completed',
      data: {
        'initialized': initialized,
        'version': version,
        'yaw': yaw,
        'dspReady': dspReady,
        'lastError': lastError,
        'issues': issues,
      },
    );

    return DspBridgeDiagnostic(
      initialized: initialized,
      version: version,
      yawDegrees: yaw,
      playbackStatus: playbackStatus,
      issues: issues,
      summary: summary,
    );
  }

  /// Sends a synthetic frame through native DSP and returns measurable deltas.
  Future<DspProbeResult> runDspProbe() async {
    const int frameSize = 512;
    const double sampleRate = 48000;
    const double frequencyHz = 440;

    final input = List<double>.generate(frameSize, (i) {
      final t = i / sampleRate;
      final sine = math.sin(2 * math.pi * frequencyHz * t) * 0.4;
      final transient = (i % 64 == 0) ? 0.35 : 0.0;
      return (sine + transient).clamp(-1.0, 1.0);
    }, growable: false);

    final output = await _nativeAudioBridge.processAudioFrame(input);
    if (output == null || output.length != input.length) {
      return const DspProbeResult(
        succeeded: false,
        message: 'Native DSP returned no frame (DSP unavailable or channel failure).',
      );
    }

    double diffSum = 0;
    double inRmsAccum = 0;
    double outRmsAccum = 0;
    for (var i = 0; i < input.length; i++) {
      final inSample = input[i];
      final outSample = output[i];
      diffSum += (outSample - inSample).abs();
      inRmsAccum += inSample * inSample;
      outRmsAccum += outSample * outSample;
    }

    final meanAbsDelta = diffSum / input.length;
    final inRms = math.sqrt(inRmsAccum / input.length);
    final outRms = math.sqrt(outRmsAccum / output.length);

    final changed = meanAbsDelta > 0.0005;
    return DspProbeResult(
      succeeded: true,
      changed: changed,
      meanAbsDelta: meanAbsDelta,
      inputRms: inRms,
      outputRms: outRms,
      message: changed
          ? 'DSP is actively modifying the frame.'
          : 'DSP response is near-identical (current settings may be subtle).',
    );
  }

  Future<bool> startRealtimeDemo() async {
    final profile = state.value;
    if (profile == null) {
      return false;
    }

    await _syncConfigToNative(profile);
    final started = await _nativeAudioBridge.startRealtimeDspDemo();
    _realtimeDemoRunning = started;
    if (started) {
      _filePlaybackRunning = false;
      _microphoneMonitorRunning = false;
    }

    if (started) {
      if (profile.aiAdaptiveEnabled) {
        _startAdaptiveLoop();
      }
      _logger.info('Realtime DSP demo started');
    } else {
      _logger.warning('Realtime DSP demo failed to start');
    }

    return started;
  }

  Future<bool> stopRealtimeDemo() async {
    _stopAdaptiveLoop();
    final stopped = await _nativeAudioBridge.stopRealtimeDspDemo();
    _realtimeDemoRunning = !stopped;

    if (stopped) {
      _logger.info('Realtime DSP demo stopped');
    }
    return stopped;
  }

  Future<bool> startFilePlayback(String filePath) async {
    final profile = state.value;
    if (profile == null || filePath.isEmpty) {
      return false;
    }

    await _syncConfigToNative(profile);
    final started = await _nativeAudioBridge.startFileDspPlayback(filePath);
    _filePlaybackRunning = started;
    if (started) {
      _realtimeDemoRunning = false;
      _microphoneMonitorRunning = false;
      if (profile.aiAdaptiveEnabled) {
        _startAdaptiveLoop();
      }
      _logger.info('File DSP playback started', data: {'path': filePath});
    } else {
      _logger.warning('File DSP playback failed to start', data: {'path': filePath});
    }
    return started;
  }

  Future<bool> stopFilePlayback() async {
    final stopped = await _nativeAudioBridge.stopFileDspPlayback();
    _filePlaybackRunning = !stopped;
    if (!_isAnyPlaybackRunning) {
      _stopAdaptiveLoop();
    }
    if (stopped) {
      _logger.info('File DSP playback stopped');
    }
    return stopped;
  }

  Future<bool> isFilePlaybackRunning() async {
    _filePlaybackRunning = await _nativeAudioBridge.isFileDspPlaybackRunning();
    return _filePlaybackRunning;
  }

  Future<bool> requestRecordAudioPermission() async {
    return _nativeAudioBridge.requestRecordAudioPermission();
  }

  Future<bool> hasRecordAudioPermission() async {
    return _nativeAudioBridge.hasRecordAudioPermission();
  }

  Future<bool> startMicrophoneMonitor() async {
    final profile = state.value;
    if (profile == null) {
      return false;
    }

    await _syncConfigToNative(profile);
    final started = await _nativeAudioBridge.startMicrophoneDspMonitor();
    _microphoneMonitorRunning = started;
    if (started) {
      _realtimeDemoRunning = false;
      _filePlaybackRunning = false;
      if (profile.aiAdaptiveEnabled) {
        _startAdaptiveLoop();
      }
      _logger.info('Microphone DSP monitor started');
    } else {
      _logger.warning('Microphone DSP monitor failed to start');
    }
    return started;
  }

  Future<bool> stopMicrophoneMonitor() async {
    final stopped = await _nativeAudioBridge.stopMicrophoneDspMonitor();
    _microphoneMonitorRunning = !stopped;
    if (!_isAnyPlaybackRunning) {
      _stopAdaptiveLoop();
    }
    if (stopped) {
      _logger.info('Microphone DSP monitor stopped');
    }
    return stopped;
  }

  Future<bool> isMicrophoneMonitorRunning() async {
    _microphoneMonitorRunning = await _nativeAudioBridge.isMicrophoneDspMonitorRunning();
    return _microphoneMonitorRunning;
  }

  Future<bool> setOutputGainDb(double gainDb) async {
    final clamped = gainDb.clamp(-18.0, 18.0);
    final success = await _nativeAudioBridge.setOutputGainDb(clamped);
    if (success) {
      _outputGainDb = clamped;
    }
    return success;
  }

  Future<Map<String, dynamic>?> getPlaybackStatus() async {
    return _nativeAudioBridge.getPlaybackStatus();
  }

  Future<void> setBypassEnabled(bool enabled) async {
    if (enabled == _bypassEnabled) {
      return;
    }

    final current = state.value;
    if (current == null) {
      return;
    }

    if (enabled) {
      _profileBeforeBypass = current;
      _bypassEnabled = true;
      await _applyProfile(_makeBypassProfile(current), persist: false);
    } else {
      _bypassEnabled = false;
      final restore = _profileBeforeBypass;
      if (restore != null) {
        await _applyProfile(restore, persist: false);
      }
      _profileBeforeBypass = null;
    }
  }

  Future<void> applyPreset(String preset) async {
    final current = state.value;
    if (current == null) {
      return;
    }

    final profile = _buildPresetProfile(current, preset);
    await _applyProfile(profile, persist: true);
  }

  DspProfile _buildPresetProfile(DspProfile base, String preset) {
    switch (preset) {
      case 'Warm':
        return base.copyWith(
          name: 'Warm',
          bassBoost: 3.0,
          spatialWidth: 0.35,
          peakLimiterDb: -1.5,
          eqBands: [
            base.eqBands[0].copyWith(gainDb: 3.0),
            base.eqBands[1].copyWith(gainDb: 2.0),
            base.eqBands[2].copyWith(gainDb: -1.0),
            base.eqBands[3].copyWith(gainDb: 0.0),
            base.eqBands[4].copyWith(gainDb: 0.0),
          ],
        );
      case 'Bright':
        return base.copyWith(
          name: 'Bright',
          bassBoost: 0.5,
          spatialWidth: 0.4,
          peakLimiterDb: -1.0,
          eqBands: [
            base.eqBands[0].copyWith(gainDb: 0.0),
            base.eqBands[1].copyWith(gainDb: 0.0),
            base.eqBands[2].copyWith(gainDb: 2.0),
            base.eqBands[3].copyWith(gainDb: 3.0),
            base.eqBands[4].copyWith(gainDb: 4.0),
          ],
        );
      case 'Bass Heavy':
        return base.copyWith(
          name: 'Bass Heavy',
          bassBoost: 6.0,
          spatialWidth: 0.5,
          peakLimiterDb: -4.0,
          eqBands: [
            base.eqBands[0].copyWith(gainDb: 6.0),
            base.eqBands[1].copyWith(gainDb: 4.0),
            base.eqBands[2].copyWith(gainDb: -1.0),
            base.eqBands[3].copyWith(gainDb: 0.0),
            base.eqBands[4].copyWith(gainDb: 0.0),
          ],
        );
      default:
        return DspProfile.defaultProfile();
    }
  }

  DspProfile _makeBypassProfile(DspProfile current) {
    return current.copyWith(
      name: '${current.name} (Bypass)',
      bassBoost: 0.0,
      spatialWidth: 0.0,
      peakLimiterDb: 0.0,
      convolverEnabled: false,
      eqBands: current.eqBands.map((band) => band.copyWith(gainDb: 0.0)).toList(growable: false),
    );
  }

  Future<bool> isRealtimeDemoRunning() async {
    _realtimeDemoRunning = await _nativeAudioBridge.isRealtimeDspDemoRunning();
    return _realtimeDemoRunning;
  }

  void _startAdaptiveLoop() {
    if (_adaptiveLoopTimer != null) {
      return;
    }

    _adaptiveLoopTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!_isAnyPlaybackRunning) {
        _stopAdaptiveLoop();
        return;
      }

      final current = state.value;
      if (current == null || !current.aiAdaptiveEnabled) {
        _stopAdaptiveLoop();
        return;
      }

      _adaptiveTick++;
      final phase = _adaptiveTick / 4.0;
      final ambientNoiseDb = 62.0 + (math.sin(phase) * 20.0);
      final vehicleSpeedKph = 55.0 + (math.cos(phase * 0.7) * 45.0);
      await applyAdaptiveTuning(
        ambientNoiseDb: ambientNoiseDb,
        vehicleSpeedKph: vehicleSpeedKph,
      );
    });
  }

  void _stopAdaptiveLoop() {
    _adaptiveLoopTimer?.cancel();
    _adaptiveLoopTimer = null;
  }

  @override
  void dispose() {
    _stopAdaptiveLoop();
    _nativeAudioBridge.stopRealtimeDspDemo();
    _nativeAudioBridge.stopFileDspPlayback();
    _nativeAudioBridge.stopMicrophoneDspMonitor();
    _nativeAudioBridge.releaseDsp();
    super.dispose();
  }

  bool get _isAnyPlaybackRunning => _realtimeDemoRunning || _filePlaybackRunning || _microphoneMonitorRunning;

  bool get bypassEnabled => _bypassEnabled;

  double get outputGainDb => _outputGainDb;
}

class DspProbeResult {
  const DspProbeResult({
    required this.succeeded,
    required this.message,
    this.changed = false,
    this.meanAbsDelta,
    this.inputRms,
    this.outputRms,
  });

  final bool succeeded;
  final bool changed;
  final double? meanAbsDelta;
  final double? inputRms;
  final double? outputRms;
  final String message;
}

class DspBridgeDiagnostic {
  const DspBridgeDiagnostic({
    required this.initialized,
    required this.version,
    required this.yawDegrees,
    required this.playbackStatus,
    required this.issues,
    required this.summary,
  });

  final bool initialized;
  final String version;
  final double? yawDegrees;
  final Map<String, dynamic>? playbackStatus;
  final List<String> issues;
  final String summary;

  bool get isHealthy => issues.isEmpty;
}
