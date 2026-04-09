import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class _ProfileView extends ConsumerWidget {
  const _ProfileView({required this.profile});

  final DspProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(audioControllerProvider.notifier);
    final dspVersion = ref.watch(dspVersionProvider);

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
