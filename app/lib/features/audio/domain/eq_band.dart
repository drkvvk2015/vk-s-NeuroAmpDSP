class EqBand {
  const EqBand({
    required this.frequencyHz,
    required this.gainDb,
    required this.q,
  });

  final double frequencyHz;
  final double gainDb;
  final double q;

  EqBand copyWith({double? frequencyHz, double? gainDb, double? q}) {
    return EqBand(
      frequencyHz: frequencyHz ?? this.frequencyHz,
      gainDb: gainDb ?? this.gainDb,
      q: q ?? this.q,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'frequencyHz': frequencyHz,
      'gainDb': gainDb,
      'q': q,
    };
  }

  static EqBand fromJson(Map<String, dynamic> json) {
    return EqBand(
      frequencyHz: (json['frequencyHz'] as num).toDouble(),
      gainDb: (json['gainDb'] as num).toDouble(),
      q: (json['q'] as num).toDouble(),
    );
  }
}
