import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';

import '../application/audio_controller.dart';
import '../domain/dsp_profile.dart';

class AudioHomePage extends ConsumerWidget {
  const AudioHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('NeuroAmp DSP Console'),
      ),
      body: state.when(
        data: (profile) => _ProfileView(profile: profile),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load profile: $error'),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await ref.read(audioControllerProvider.notifier).applyAdaptiveTuning(
            ambientNoiseDb: 74,
            vehicleSpeedKph: 90,
          );
        },
        icon: const Icon(Icons.auto_awesome),
        label: const Text('AI Tune'),
      ),
    );
  }
}

class _ProfileView extends ConsumerStatefulWidget {
  const _ProfileView({required this.profile});

  final DspProfile profile;

  @override
  ConsumerState<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<_ProfileView> {
  Timer? _statusTimer;
  Map<String, dynamic>? _status;
  double _ampGainDb = 0.0;
  bool _autoStartAttempted = false;

  @override
  void initState() {
    super.initState();
    _statusTimer = Timer.periodic(const Duration(milliseconds: 600), (_) async {
      final controller = ref.read(audioControllerProvider.notifier);
      final status = await controller.getPlaybackStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attemptAutoStartMicDsp();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _attemptAutoStartMicDsp() async {
    if (_autoStartAttempted || !mounted) {
      return;
    }
    _autoStartAttempted = true;

    final controller = ref.read(audioControllerProvider.notifier);
    final alreadyRunning = await controller.isMicrophoneMonitorRunning();
    if (alreadyRunning || !mounted) {
      return;
    }

    final granted = await controller.hasRecordAudioPermission() ||
        await controller.requestRecordAudioPermission();
    if (!mounted || !granted) {
      return;
    }

    final started = await controller.startMicrophoneMonitor();
    if (!mounted || !started) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Live microphone DSP auto-started.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final controller = ref.read(audioControllerProvider.notifier);
    final dspVersion = ref.watch(dspVersionProvider);
    final inputRms = ((_status?['inputRms'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);
    final outputRms = ((_status?['outputRms'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          profile.name,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Native DSP: ${dspVersion.valueOrNull ?? 'loading...'}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'Live DSP demo is available in-app (Android). System-wide processing for other apps is not supported in standard Android sandbox.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        Text('Presets', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Reference'),
              onPressed: () => controller.applyPreset('Reference'),
            ),
            ActionChip(
              label: const Text('Warm'),
              onPressed: () => controller.applyPreset('Warm'),
            ),
            ActionChip(
              label: const Text('Bright'),
              onPressed: () => controller.applyPreset('Bright'),
            ),
            ActionChip(
              label: const Text('Bass Heavy'),
              onPressed: () => controller.applyPreset('Bass Heavy'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('A/B Bypass'),
          subtitle: const Text('Instantly compare processed vs flat signal'),
          value: controller.bypassEnabled,
          onChanged: (enabled) async {
            await controller.setBypassEnabled(enabled);
            if (!mounted) return;
            setState(() {});
          },
        ),
        const SizedBox(height: 8),
        Text('Amplifier Gain: ${_ampGainDb.toStringAsFixed(1)} dB'),
        Slider(
          min: -18,
          max: 18,
          divisions: 72,
          value: _ampGainDb,
          onChanged: (value) {
            setState(() {
              _ampGainDb = value;
            });
          },
          onChangeEnd: (value) async {
            await controller.setOutputGainDb(value);
          },
        ),
        const SizedBox(height: 8),
        Text('Realtime RMS Meters', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text('Input RMS ${(inputRms * 100).toStringAsFixed(1)}%'),
        LinearProgressIndicator(value: inputRms),
        const SizedBox(height: 6),
        Text('Output RMS ${(outputRms * 100).toStringAsFixed(1)}%'),
        LinearProgressIndicator(value: outputRms),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: () async {
                final started = await controller.startRealtimeDemo();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      started
                          ? 'Realtime DSP demo started. Adjust EQ/Bass/Width now to hear changes.'
                          : 'Failed to start realtime DSP demo on this platform/device.',
                    ),
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Live DSP Demo'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final granted = await controller.hasRecordAudioPermission() ||
                    await controller.requestRecordAudioPermission();
                if (!context.mounted) return;
                if (!granted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Microphone permission is required for live input DSP.'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                  return;
                }

                final started = await controller.startMicrophoneMonitor();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      started
                          ? 'Live microphone DSP started. Headphones are recommended to avoid speaker feedback.'
                          : 'Failed to start live microphone DSP path.',
                    ),
                    duration: const Duration(seconds: 4),
                  ),
                );
              },
              icon: const Icon(Icons.mic),
              label: const Text('Start Live Mic DSP'),
            ),
            FilledButton.tonalIcon(
              onPressed: () async {
                final stopped = await controller.stopRealtimeDemo();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      stopped
                          ? 'Realtime DSP demo stopped.'
                          : 'Realtime DSP demo stop request failed.',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.stop),
              label: const Text('Stop Live DSP Demo'),
            ),
            FilledButton.tonalIcon(
              onPressed: () async {
                final stopped = await controller.stopMicrophoneMonitor();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      stopped
                          ? 'Live microphone DSP stopped.'
                          : 'Live microphone DSP stop request failed.',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.mic_off),
              label: const Text('Stop Live Mic DSP'),
            ),
            FilledButton.tonalIcon(
              onPressed: () async {
                _ampGainDb = 6.0;
                await controller.setOutputGainDb(_ampGainDb);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Amplifier gain set to +6 dB.')),
                );
                setState(() {});
              },
              icon: const Icon(Icons.volume_up),
              label: const Text('Amp +6 dB'),
            ),
            FilledButton.tonalIcon(
              onPressed: () async {
                _ampGainDb = 0.0;
                await controller.setOutputGainDb(_ampGainDb);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Amplifier gain reset to 0 dB.')),
                );
                setState(() {});
              },
              icon: const Icon(Icons.volume_mute),
              label: const Text('Amp 0 dB'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final picked = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: const ['wav', 'mp3', 'm4a', 'aac', 'flac', 'ogg'],
                );
                final path = picked?.files.single.path;
                if (path == null || path.isEmpty) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No WAV file selected.')),
                  );
                  return;
                }

                final started = await controller.startFilePlayback(path);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      started
                          ? 'Playing file through DSP. Adjust controls live to hear effect.'
                          : 'Could not start file DSP playback (best support: PCM16 WAV, MP3, AAC/M4A).',
                    ),
                    duration: const Duration(seconds: 4),
                  ),
                );
              },
              icon: const Icon(Icons.library_music),
              label: const Text('Play WAV Through DSP'),
            ),
            FilledButton.tonalIcon(
              onPressed: () async {
                final stopped = await controller.stopFilePlayback();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      stopped
                          ? 'File DSP playback stopped.'
                          : 'File DSP playback stop request failed.',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Stop File Playback'),
            ),
            FilledButton.tonalIcon(
              onPressed: () async {
                final status = await controller.getPlaybackStatus();
                if (!context.mounted) return;
                final text = status == null
                    ? 'No playback diagnostics available.'
                    : 'RT=${status['realtimeRunning']} FILE=${status['fileRunning']} MIC=${status['microphoneRunning']} DSP=${status['dspReady']}\nperm=${status['hasRecordAudioPermission']} safety=${status['safetyAttenuationActive']} lastError=${status['lastError']} gain=${status['outputGainLinear']}';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(text),
                    duration: const Duration(seconds: 5),
                  ),
                );
              },
              icon: const Icon(Icons.bug_report_outlined),
              label: const Text('DSP Diagnostics'),
            ),
            FilledButton.tonalIcon(
              onPressed: () async {
                final diagnostic = await controller.runBridgeDiagnostic();
                if (!context.mounted) return;

                final status = diagnostic.playbackStatus;
                final details = [
                  diagnostic.summary,
                  'init=${diagnostic.initialized} version=${diagnostic.version}',
                  'yaw=${diagnostic.yawDegrees?.toStringAsFixed(2) ?? 'null'}',
                  if (status != null)
                    'dspReady=${status['dspReady']} realtime=${status['realtimeRunning']} file=${status['fileRunning']} mic=${status['microphoneRunning']}',
                  if (status?['lastError'] != null) 'lastError=${status!['lastError']}',
                ].join('\n');

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(details),
                    duration: const Duration(seconds: 6),
                  ),
                );
              },
              icon: const Icon(Icons.memory_outlined),
              label: const Text('Bridge Self-Test'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: () async {
              final probe = await controller.runDspProbe();
              if (!context.mounted) return;

              final details = probe.succeeded
                  ? '${probe.message}\nmeanAbsDelta=${probe.meanAbsDelta?.toStringAsExponential(3)}\ninRms=${probe.inputRms?.toStringAsFixed(4)}, outRms=${probe.outputRms?.toStringAsFixed(4)}'
                  : probe.message;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(details),
                  duration: const Duration(seconds: 4),
                ),
              );
            },
            icon: const Icon(Icons.graphic_eq),
            label: const Text('Run DSP Probe'),
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Enable FIR Convolution'),
          value: profile.convolverEnabled,
          onChanged: (value) {
            controller.update(profile.copyWith(convolverEnabled: value));
          },
        ),
        SwitchListTile(
          title: const Text('AI Adaptive Tuning'),
          value: profile.aiAdaptiveEnabled,
          onChanged: (value) {
            controller.update(profile.copyWith(aiAdaptiveEnabled: value));
          },
        ),
        SwitchListTile(
          title: const Text('Head Tracking'),
          value: profile.headTrackingEnabled,
          onChanged: (value) {
            controller.update(profile.copyWith(headTrackingEnabled: value));
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Sync head tracking from device sensors'),
          trailing: FilledButton(
            onPressed: profile.headTrackingEnabled
                ? () async {
                    await controller.syncHeadTrackingFromDevice();
                  }
                : null,
            child: const Text('Sync'),
          ),
        ),
        const SizedBox(height: 8),
        Text('Spatial Width: ${(profile.spatialWidth * 100).round()}%'),
        Slider(
          min: 0,
          max: 1,
          value: profile.spatialWidth,
          onChanged: (value) {
            controller.update(profile.copyWith(spatialWidth: value));
          },
        ),
        const SizedBox(height: 8),
        Text('Bass Boost: ${profile.bassBoost.toStringAsFixed(1)} dB'),
        Slider(
          min: 0,
          max: 6,
          divisions: 24,
          value: profile.bassBoost,
          onChanged: (value) {
            controller.update(profile.copyWith(bassBoost: value));
          },
        ),
        const SizedBox(height: 8),
        Text('Peak Limiter: ${profile.peakLimiterDb.toStringAsFixed(1)} dBFS'),
        Slider(
          min: -6,
          max: 0,
          divisions: 24,
          value: profile.peakLimiterDb,
          onChanged: (value) {
            controller.update(profile.copyWith(peakLimiterDb: value));
          },
        ),
        const SizedBox(height: 16),
        Text('Parametric EQ', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ...profile.eqBands.asMap().entries.map(
          (entry) {
            final index = entry.key;
            final band = entry.value;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Band ${index + 1} - ${band.frequencyHz.toStringAsFixed(0)} Hz'),
                    Text('Gain: ${band.gainDb.toStringAsFixed(1)} dB'),
                    Slider(
                      min: -12,
                      max: 12,
                      divisions: 48,
                      value: band.gainDb,
                      onChanged: (value) {
                        final updatedBands = profile.eqBands.toList();
                        updatedBands[index] = band.copyWith(gainDb: value);
                        controller.update(profile.copyWith(eqBands: updatedBands));
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
