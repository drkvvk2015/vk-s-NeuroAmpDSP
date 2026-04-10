# NeuroAmp App

Flutter application layer for the NeuroAmp DSP mobile platform. This module owns UI, state management, profile persistence, telemetry hooks, and the MethodChannel bridge into Android/Kotlin and native C++ DSP processing.

For full platform architecture and deployment details, see the root [README.md](../README.md).

## What this app includes
- Riverpod-managed DSP state and profile workflows
- Advanced DSP controls (EQ, bass boost, spatial width, limiter)
- Adaptive tuning integration (noise/speed heuristics)
- Head-tracking sync via Android sensor bridge with smoothing
- Native bridge calls for DSP init/process/release/version
- Live microphone DSP monitoring path (Android, RECORD_AUDIO permission)
- Local file playback routed through DSP processing
- Automatic live mic DSP startup on first launch frame (after permission grant)
- Native feedback safety attenuation during mic monitoring
- App Insights startup + unhandled exception telemetry (prod only)

## Contributor Quickstart

### Prerequisites
- Flutter SDK (stable)
- Android SDK + NDK
- Java 17

### Development run
```bash
cd app
flutter pub get
flutter run --dart-define=APP_FLAVOR=dev
```

### Staging run
```bash
cd app
flutter run --release --dart-define=APP_FLAVOR=staging
```

### Production APK
```bash
cd app
flutter build apk --release \
	--dart-define=APP_FLAVOR=prod \
	--dart-define=TELEMETRY_KEY=<your-key>
```

## Validation

```bash
cd app
flutter test
flutter analyze
```

## Native Bridge API
- `initializeDsp`
- `processAudioFrame`
- `releaseDsp`
- `getHeadTrackingYaw`
- `getDspEngineVersion`
- `requestRecordAudioPermission`
- `hasRecordAudioPermission`
- `startMicrophoneDspMonitor`
- `stopMicrophoneDspMonitor`
- `isMicrophoneDspMonitorRunning`

## Operational Notes
- Live Mic DSP is the primary real-time validation mode for real-world input.
- Use headphones for mic monitoring to minimize acoustic feedback.
- Diagnostics include `safetyAttenuationActive` when protection is reducing output gain.

## Android Signing (Release)

```bash
cd app/android
copy key.properties.example key.properties
```

Then configure `key.properties` and ensure the keystore exists at the configured path.
