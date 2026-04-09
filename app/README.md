# NeuroAmp App

Flutter application layer for the NeuroAmp DSP mobile platform. This module owns UI, state management, profile persistence, telemetry hooks, and the MethodChannel bridge into Android/Kotlin and native C++ DSP processing.

For full platform architecture and deployment details, see the root [README.md](../README.md).

## What this app includes
- Riverpod-managed DSP state and profile workflows
- Advanced DSP controls (EQ, bass boost, spatial width, limiter)
- Adaptive tuning integration (noise/speed heuristics)
- Head-tracking sync via Android sensor bridge with smoothing
- Native bridge calls for DSP init/process/release/version
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

## Android Signing (Release)

```bash
cd app/android
copy key.properties.example key.properties
```

Then configure `key.properties` and ensure the keystore exists at the configured path.
