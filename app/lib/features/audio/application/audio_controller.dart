import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    state = AsyncValue.data(profile);
    await _repository.save(profile);
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

  @override
  void dispose() {
    _nativeAudioBridge.releaseDsp();
    super.dispose();
  }
}
