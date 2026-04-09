# Advanced Audio Features Guide

## Quick Start

NeuroAmp DSP provides production-grade audio control with real-time DSP processing, head-tracking, and AI-powered adaptive tuning.

## Feature Highlights

### 1. Real-Time EQ (5-Band Parametric)

Full parametric equalizer with center-tuned controls for each frequency band:

```
60 Hz    - Sub-bass (±12 dB)    Set ↑ for more kick, ↓ for less boom
250 Hz   - Bass warmth (±12 dB)  Adjust thickness and fullness
1 kHz    - Midrange (±12 dB)     Controls presence and body
4 kHz    - Brightness (±12 dB)   Add clarity or reduce harshness
12 kHz   - Air (±12 dB)          Enhance detail and sparkle
```

**Use Cases:**
- **Vocals:** +3 dB @ 1 kHz, +2 dB @ 4 kHz
- **Bass Headphones:** +6 dB @ 60 Hz, +3 dB @ 250 Hz
- **Treble Recovery:** -2 dB @ 4 kHz, +1 dB @ 12 kHz

### 2. Bass Boost (0-6 dB)

Unified bass enhancement that boosts sub-250 Hz content globally:

- **0 dB:** No boost
- **3 dB:** +3 dB linear gain (typical boost)
- **6 dB:** Maximum bass enhancement

**When to use:**
- Small speaker systems with weak bass response
- Heavy/hip-hop music genres
- Road noise compensation (auto-enabled at 80+ kph)

### 3. Spatial Width (0% - 100%)

Creates perceived stereo width from mono source:

```
0%    - Full mono (no width)
25%   - Reference (subtle stereo illusion)
50%   - Moderate width (noticeable expansion)
100%  - Maximum width (aggressive MS expansion)
```

**Implementation Detail:** High-pass processes side channel at ~200 Hz, scales by width factor

**Head-Tracking Interaction:** Width automatically attenuates at extreme head angles (preserves localization CFs)

### 4. Peak Limiting (-6 to 0 dBFS)

Lookahead limiter prevents clipping with 2 ms attack window:

- **-1 dBFS (default):** Transparent, allows peaks to ±1.0 linear
- **-3 dBFS:** Moderate compression, headroom preservation
- **-6 dBFS:** Aggressive, acts as safety valve

**Algorithm:** Scans 2048-sample lookahead buffer for peaks, applies smooth gain reduction with exponential curves (0.5 ms attack, 100 ms release)

### 5. Head-Tracking Adaptive Processing

**Requires:** Device with `TYPE_ROTATION_VECTOR` sensor (most modern Android phones/tablets)

**What it does:**
- Continuously reads device orientation (yaw/pitch/roll)
- Applies binaural panning based on head angle
- Frequency-adaptive EQ (side angles → enhance 4-12 kHz)
- Spatial width modulation at extreme angles

**Example Flow:**
```
Head straight (0°)     → Normal spatial width, flat EQ
Head 45° left          → -45° pan, +2 dB @ 4kHz, +3 dB @ 12kHz
Head 45° right         → +45° pan, +2 dB @ 4kHz, +3 dB @ 12kHz
```

**Confidence Estimation:** Tracks sensor jitter; confidence drops if variance exceeds threshold

### 6. AI Adaptive Tuning (Auto-Compensation)

Background heuristics monitor environment and auto-adjust EQ + Bass:

```
Noise Level < 70 dB (quiet)
  → No adjustment (reference tuning)

Noise Level 70-80 dB (moderate)
  → +3 dB @ 1 kHz (presence), +2 dB @ 4 kHz (clarity)

Noise Level > 80 dB (loud)
  → +5 dB @ 1 kHz, +4 dB @ 4 kHz, +2 dB @ 12 kHz

Speed < 80 km/h
  → No adjustment

Speed 80-120 km/h (highway)
  → +2 dB bass boost, +0.2 spatial width

Speed > 120 km/h (very fast)
  → +3 dB bass boost, +0.3 spatial width, +1 dB @ 1 kHz
```

**Enable/Disable:** Toggle "AI Adaptive" switch on home screen

---

## Preset Profiles

Pre-built profiles optimized for common use cases:

### Default
- All EQ flat (neutral reference)
- Bass boost: 0 dB
- Spatial width: 25%
- Peak limiter: -1 dBFS

### Warm
- +3 dB @ 60 Hz, +2 dB @ 250 Hz
- -1 dB @ 1 kHz (reduce harshness)
- Bass boost: 3 dB
- Spatial width: 35%

### Bright
- Flat bass (0 dB @ 60, 250 Hz)
- +2 dB @ 1 kHz
- +3 dB @ 4 kHz
- +4 dB @ 12 kHz
- Spatial width: 40%

### Bass Heavy
- +6 dB @ 60 Hz, +4 dB @ 250 Hz
- -1 dB @ 1 kHz (reduce muddiness)
- Bass boost: 6 dB
- Peak limiter: -6 dBFS (prevent clipping)
- Spatial width: 50%

### Road Noise (Auto-enabled on highway)
- +3 dB @ 1 kHz (voice clarity)
- +4 dB @ 4 kHz (dialogue)
- Bass boost: 2 dB (low rumble masking)
- Peak limiter: -3 dBFS

---

## Technical Details

### Biquad Filter Topology

NeuroAmp uses **Direct Form II (Transposed)** for numerical stability:

```
Output:                    Input sample x
  |                            |
  ├─(b0)──(+)────────────→(y_out)
  |         ↑
  |        z1 ←──(z1)←──
  |         ↑            |
  |        z2 ←──(z2)←──┘
  |
  ├─(b1)──→(×)─→(+)
  |              ↑
  |  (a1)←──(×)──┘
  |
  └─(b2)──→(×)→(z2_next)
```

**Why?** Better numerical precision than Direct Form I, no instability with high-Q filters

### Lookahead Limiter Stages

1. **Ring Buffer:** Stores latest 2048 samples (42.7 ms @ 48 kHz)
2. **Peak Search:** Scan for max |sample| in lookahead window
3. **Gain Computation:** 
   - If peak > threshold: ramp down gain (attack)
   - Else: ramp up gain (release)
4. **Sample Scaling:** Apply computed gain to current sample
5. **Saturation:** Apply tanh() for soft clipping beyond ±1.0

**Typical Latency:** 42.7 ms (lookahead) + 256 samples (buffer line delay) = ~47 ms

### Head-Tracking Smoothing

**Algorithm:** Exponential moving average

```
y_smooth[n] = α × y_raw[n] + (1 - α) × y_smooth[n-1]

where α = 0.15 (smoothing factor)
```

**Effective window:** ~67 ms @ 60 Hz sensor rate
**Benefit:** Reduces jitter, maintains responsiveness

---

## Troubleshooting

### "Head-Tracking Disabled" Message

**Cause:** Device lacks `TYPE_ROTATION_VECTOR` sensor or permissions not granted

**Solution:**
- Check device sensor list: `adb shell dumpsys sensorservice`
- Grant location/motion permissions in Settings → Apps → NeuroAmp DSP

### Audio Processing Sounds Distorted

**Cause:** Peak limiter threshold too aggressive, or profile gains too high

**Solution:**
1. Lower peak limiter (move toward -6 dBFS)
2. Reduce individual EQ gains (max ±3 dB recommended)
3. Reset to Default profile and re-tune

### No Audio Processing Applied

**Cause:** Native library (libneuroamp_dsp.so) failed to load

**Solution:**
1. Rebuild Android release: `cd app && flutter build apk --release`
2. Verify build.gradle.kts includes CMake and NDK
3. Check Logcat: `adb logcat | grep NeuroAmpDSP`

---

## Advanced Usage

### Custom EQ Saving

1. Adjust all 5 EQ bands + bass boost to taste
2. Tap "Save Profile" 
3. Enter custom name (e.g., "My Headphones")
4. Profile persists across app restarts

### Export Current Settings

Settings are stored as JSON in SharedPreferences:

```bash
adb shell run-as com.neuroamp.app cat shared_prefs/dsp_profile_v1.xml
```

### Batch EQ Testing

Use `flutter test` to validate EQ coefficient generation:

```bash
cd app
flutter test test/dsp_audio_test.dart -v
```

---

## Performance Optimization Tips

1. **Disable head-tracking if not needed** — Saves ~1% CPU
2. **Lower spatial width if audio glitches** — Reduces filter complexity
3. **Use peak limiter sparingly** — Lookahead adds 42ms latency
4. **Profile often-used EQ setups** — Avoid real-time calculation

---

## Known Limitations

- **Mono processing only** — No stereo input/output (WAV stereo processing → mono blend)
- **Fixed 48 kHz sample rate** — Hardcoded in initialization
- **No convolver yet** — Custom IR loading planned for v1.1
- **Single-threaded DSP** — Audio thread not isolated from main thread

---

## What's Next?

- [ ] Real-time convolver with custom IR loading
- [ ] Multi-band dynamics (independent compressor per band)
- [ ] Binaural HRTF selection UI
- [ ] ML-based EQ optimization
- [ ] Cloud preset sync
