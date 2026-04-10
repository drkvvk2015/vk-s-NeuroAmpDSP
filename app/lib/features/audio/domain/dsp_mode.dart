enum DspMode {
  standard,
  enhanced,
  pro,
  root;
}

extension DspModeX on DspMode {
  String get wireName {
    switch (this) {
      case DspMode.standard:
        return 'standard';
      case DspMode.enhanced:
        return 'enhanced';
      case DspMode.pro:
        return 'pro';
      case DspMode.root:
        return 'root';
    }
  }

  String get label {
    switch (this) {
      case DspMode.standard:
        return 'Standard';
      case DspMode.enhanced:
        return 'Enhanced';
      case DspMode.pro:
        return 'Pro';
      case DspMode.root:
        return 'Root';
    }
  }

  String get summary {
    switch (this) {
      case DspMode.standard:
        return 'Local playback and live input DSP inside NeuroAmp.';
      case DspMode.enhanced:
        return 'Experimental Android audio-effect attachment for supported external players.';
      case DspMode.pro:
        return 'Enhanced mode plus Shizuku-assisted control and diagnostics.';
      case DspMode.root:
        return 'Reserved for rooted/system builds with stronger device control.';
    }
  }

  static DspMode fromWireName(String? raw) {
    switch (raw) {
      case 'enhanced':
        return DspMode.enhanced;
      case 'pro':
        return DspMode.pro;
      case 'root':
        return DspMode.root;
      case 'standard':
      default:
        return DspMode.standard;
    }
  }
}