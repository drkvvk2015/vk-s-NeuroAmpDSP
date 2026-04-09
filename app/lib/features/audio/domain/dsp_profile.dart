import 'dart:convert';

import 'eq_band.dart';

class DspProfile {
  const DspProfile({
    required this.name,
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
  final List<EqBand> eqBands;
  final double spatialWidth;
  final double bassBoost;
  final bool convolverEnabled;
  final bool aiAdaptiveEnabled;
  final bool headTrackingEnabled;
  final double peakLimiterDb;

  DspProfile copyWith({
    String? name,
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
    return DspProfile(
      name: json['name'] as String,
      eqBands: (json['eqBands'] as List<dynamic>)
          .map((x) => EqBand.fromJson(x as Map<String, dynamic>))
          .toList(growable: false),
      spatialWidth: (json['spatialWidth'] as num).toDouble(),
      bassBoost: (json['bassBoost'] as num).toDouble(),
      convolverEnabled: json['convolverEnabled'] as bool,
      aiAdaptiveEnabled: json['aiAdaptiveEnabled'] as bool,
      headTrackingEnabled: json['headTrackingEnabled'] as bool,
      peakLimiterDb: (json['peakLimiterDb'] as num).toDouble(),
    );
  }
}
