# NeuroAmp DSP

Production-Ready Mobile Audio DSP Engine with Flutter + Native C++ Runtime

NeuroAmp DSP is a high-performance mobile audio processing system that combines a modern Flutter UI with a real-time native DSP engine. It is designed for low-latency audio enhancement, adaptive tuning, and sensor-driven spatial audio experiences.

## Key Features

### Advanced DSP Control Panel
- Multi-band EQ
- Limiter (dynamic range control)
- Spatial width (stereo enhancement)
- Bass boost (low-frequency shaping)

### Adaptive Audio Tuning
- Dynamic adjustments based on motion/speed signals
- Heuristic-based noise compensation
- Real-time parameter updates

### Head Tracking Integration
- Uses Android `TYPE_ROTATION_VECTOR` sensor
- Smooth yaw tracking with filtering
- Enables spatial audio responsiveness

### Real-Time Native DSP Engine
- C++ audio processing pipeline
- JNI bridge for low-latency execution
- Frame-based audio processing
- Live microphone input -> DSP -> speaker monitoring mode (Android)
- Local file playback through DSP (WAV/MP3/AAC decode path)

### Multi-Mode DSP Control
- `Standard` mode for in-app playback and live input DSP
- `Enhanced` mode for experimental Android audio-effect attachment on supported apps/devices
- `Pro` mode with Shizuku-assisted capability checks and controls
- `Root` mode reserved for rooted/system builds

### Production-Grade Observability
- App lifecycle telemetry (App Insights)
- Global error capture (Flutter + Zone)
- Safe fallback on telemetry failure

### CI/CD and Deployment
- Automated testing and linting
- APK/AAB build pipelines
- Play Store release automation

## Architecture

```text
Flutter UI
	↓
Riverpod State Management
	↓
MethodChannel Bridge
	↓
Kotlin (Android Layer)
	↓
C++ DSP Runtime (JNI)
```

## Data Flow Example

User adjusts EQ ->
State updated via Riverpod ->
Parameters sent via MethodChannel ->
Kotlin forwards to JNI ->
C++ updates filter coefficients ->
Next audio frame processed in real-time

## DSP Processing Details
- Equalizer: Multi-band biquad filters for frequency shaping
- Limiter: Prevents clipping using dynamic gain control
- Spatial Width: Mid/Side (M/S) stereo processing
- Bass Boost: Low-shelf filter enhancement

## Real-Time Considerations
- Frame-based processing (low-latency pipeline)
- Native execution to avoid UI thread blocking
- Optimized for mobile CPU constraints

## Repository Structure

```text
.
├── app/
│   ├── lib/
│   │   ├── core/
│   │   ├── features/audio/
│   ├── android/
│   │   ├── app/src/main/kotlin/com/neuroamp/app/MainActivity.kt
│   │   ├── app/src/main/cpp/dsp_engine.cpp
│   ├── test/
├── .github/workflows/
│   ├── flutter-ci.yml
│   ├── android-release.yml
│   ├── playstore-release.yml
```

## Environment Configuration

Supports multiple environments using `--dart-define`:

| Flavor | Purpose |
| --- | --- |
| dev | Local development |
| staging | Pre-release testing |
| prod | Production release |

## Getting Started

### Prerequisites
- Flutter SDK (stable)
- Android SDK + NDK
- Java 17

### Run (Development)
```bash
cd app
flutter pub get
flutter run --dart-define=APP_FLAVOR=dev
```

### Run (Staging)
```bash
cd app
flutter run --release --dart-define=APP_FLAVOR=staging
```

### Build (Production APK)
```bash
cd app
flutter build apk --release \
  --dart-define=APP_FLAVOR=prod \
  --dart-define=TELEMETRY_KEY=<your-key>
```

## Telemetry (App Insights)

Enabled only in production builds.

Tracks:
- `app_bootstrap_start`
- `app_bootstrap_complete`
- Unhandled exceptions

Safe fallback:
- App continues even if telemetry fails

## Android Release Signing

1. Copy `app/android/key.properties.example` to `app/android/key.properties`.
2. Create keystore at `app/keystore/neuroamp-release.jks`.
3. Fill credentials in `key.properties`.
4. Build release.

Falls back to debug signing if not configured (dev-friendly).

## Native Bridge API

| Method | Description |
| --- | --- |
| `initializeDsp` | Initialize DSP engine |
| `processAudioFrame` | Process audio buffer |
| `releaseDsp` | Cleanup resources |
| `getHeadTrackingYaw` | Sensor-based yaw |
| `getDspEngineVersion` | Native version info |
| `requestRecordAudioPermission` | Request microphone permission |
| `hasRecordAudioPermission` | Check microphone permission state |
| `startMicrophoneDspMonitor` | Start live mic->DSP->speaker path |
| `stopMicrophoneDspMonitor` | Stop live mic DSP path |
| `isMicrophoneDspMonitorRunning` | Query mic DSP running state |
| `setDspMode` | Select standard/enhanced/pro/root mode |
| `getDspMode` | Query active DSP mode |
| `getDspModeStatus` | Query runtime capability state for enhanced/pro/root paths |
| `openNotificationAccessSettings` | Open Android notification listener settings |
| `requestShizukuPermission` | Request Shizuku permission for Pro mode |

## Runtime Modes
- Live Mic DSP: Processes microphone input in real-time with current DSP profile.
- File DSP Playback: Processes selected local audio files through the DSP chain.
- Realtime Demo DSP: Synthetic source for quick validation and profiling.

## DSP Product Modes
- Standard: Processes only audio generated inside NeuroAmp.
- Enhanced: Attempts Android audio-effect attachment for supported external players.
- Pro: Enhanced mode plus Shizuku-assisted advanced control.
- Root: Reserved for rooted/system builds; this repository still uses compatibility-based attachment rather than full audio-stack hooks.

Note: Android app sandbox rules do not allow guaranteed system-wide PCM interception from other apps without privileged OS-level integration. Enhanced and Pro modes are compatibility-based.

## CI/CD Pipelines

### `flutter-ci.yml`
Lint + unit/widget tests

### `android-release.yml`
Builds APK on version tags (`v*`)

### `playstore-release.yml`
- Builds signed AAB
- Uploads to Play Store (internal testing)

## Play Store Deployment

```bash
git tag release/v1.0.0
git push origin release/v1.0.0
```

Automated:
- Build signed AAB
- Upload to Play Console
- Ready for promotion

## Stability and Safety
- Graceful fallback if DSP initialization fails
- JNI error handling prevents crashes
- Sensor failure does not block audio processing

## Roadmap

### Completed
- Real-time DSP engine (C++)
- Head tracking integration
- CI/CD + Play Store automation
- Testing (method channel + decoding)

### Future Enhancements
- DSP performance metrics (CPU, latency)
- Continuous head-tracking service (Kotlin layer)
- Hardware-in-the-loop audio validation

## Real-World Use Cases
- In-car audio enhancement
- Headphone spatial audio
- Adaptive listening in noisy environments

## Why This Project Stands Out
- Combines Flutter + Native + C++ DSP
- Real-time audio processing on mobile
- Production-ready with CI/CD and telemetry
- Demonstrates systems thinking + performance engineering
