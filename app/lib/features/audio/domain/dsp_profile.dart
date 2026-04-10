import 'dart:convert';

import 'dsp_mode.dart';
import 'eq_band.dart';

class DspProfile {
  const DspProfile({
    required this.name,
    required this.dspMode,
    required this.eqBands,
    required this.spatialWidth,
    required this.bassBoost,
    required this.convolverEnabled,
    required this.aiAdaptiveEnabled,
    required this.headTrackingEnabled,
    required this.peakLimiterDb,
  });

  factory DspProfile.defaultProfile() {
    return const DspProfile(
      name: 'Reference',
      dspMode: DspMode.standard,
      eqBands: [
        EqBand(frequencyHz: 60, gainDb: 0, q: 1.0),
        EqBand(frequencyHz: 250, gainDb: 0, q: 1.0),
        EqBand(frequencyHz: 1000, gainDb: 0, q: 1.0),
        EqBand(frequencyHz: 4000, gainDb: 0, q: 1.0),
        EqBand(frequencyHz: 12000, gainDb: 0, q: 1.0),
      ],
      spatialWidth: 0.25,
      bassBoost: 0.0,
      convolverEnabled: false,
      aiAdaptiveEnabled: true,
      headTrackingEnabled: false,
      peakLimiterDb: -1.0,
    );
  }

  final String name;
  final DspMode dspMode;
  final List<EqBand> eqBands;
  final double spatialWidth;
  final double bassBoost;
  final bool convolverEnabled;
  final bool aiAdaptiveEnabled;
  final bool headTrackingEnabled;
  final double peakLimiterDb;

  DspProfile copyWith({
    String? name,
    DspMode? dspMode,
    List<EqBand>? eqBands,
    double? spatialWidth,
    double? bassBoost,
    bool? convolverEnabled,
    bool? aiAdaptiveEnabled,
    bool? headTrackingEnabled,
    double? peakLimiterDb,
  }) {
    return DspProfile(
      name: name ?? this.name,
      dspMode: dspMode ?? this.dspMode,
      eqBands: eqBands ?? this.eqBands,
      spatialWidth: spatialWidth ?? this.spatialWidth,
      bassBoost: bassBoost ?? this.bassBoost,
      convolverEnabled: convolverEnabled ?? this.convolverEnabled,
      aiAdaptiveEnabled: aiAdaptiveEnabled ?? this.aiAdaptiveEnabled,
      headTrackingEnabled: headTrackingEnabled ?? this.headTrackingEnabled,
      peakLimiterDb: peakLimiterDb ?? this.peakLimiterDb,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dspMode': dspMode.wireName,
      'eqBands': eqBands.map((band) => band.toJson()).toList(),
      'spatialWidth': spatialWidth,
      'bassBoost': bassBoost,
      'convolverEnabled': convolverEnabled,
      'aiAdaptiveEnabled': aiAdaptiveEnabled,
      'headTrackingEnabled': headTrackingEnabled,
      'peakLimiterDb': peakLimiterDb,
    };
  }

  String encode() => jsonEncode(toJson());

  static DspProfile decode(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final defaults = DspProfile.defaultProfile();

    final rawBands = json['eqBands'];
    final eqBands = rawBands is List<dynamic>
      ? rawBands
          .map((x) => EqBand.fromJson(x as Map<String, dynamic>))
          .toList(growable: false)
      : defaults.eqBands;

    return DspProfile(
      name: json['name'] as String? ?? defaults.name,
      dspMode: DspModeX.fromWireName(json['dspMode'] as String?),
      eqBands: eqBands,
      spatialWidth:
        (json['spatialWidth'] as num?)?.toDouble() ?? defaults.spatialWidth,
      bassBoost: (json['bassBoost'] as num?)?.toDouble() ?? defaults.bassBoost,
      convolverEnabled:
        json['convolverEnabled'] as bool? ?? defaults.convolverEnabled,
      aiAdaptiveEnabled:
        json['aiAdaptiveEnabled'] as bool? ?? defaults.aiAdaptiveEnabled,
      headTrackingEnabled:
        json['headTrackingEnabled'] as bool? ?? defaults.headTrackingEnabled,
      peakLimiterDb:
        (json['peakLimiterDb'] as num?)?.toDouble() ?? defaults.peakLimiterDb,
    );
  }
}
