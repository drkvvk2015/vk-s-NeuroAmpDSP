# NeuroAmp DSP

Production-ready mobile DSP controller with Flutter UI, Android sensor integration, and native DSP runtime stubs.

## Production features implemented
- Advanced Flutter DSP control console (EQ, limiter, spatial width, bass boost)
- AI adaptive tuning heuristics for road-noise and speed compensation
- Head-tracking integration through Android sensor method channel
- Native DSP bridge endpoint returning engine version from C++ JNI layer
- Profile persistence, structured logging, and global error capture
- Environment flavors (`dev`, `staging`, `prod`) using `--dart-define`
- CI pipelines for lint/test and Android release artifact generation

## Architecture

Flutter UI -> Riverpod Application Layer -> MethodChannel Bridge -> Kotlin MainActivity -> C++ DSP Runtime

## Repository layout
```text
.
|- app/
|  |- lib/
|  |  |- core/
|  |  |- features/audio/
|  |- android/
|  |  |- app/src/main/kotlin/com/neuroamp/app/MainActivity.kt
|  |  |- app/src/main/cpp/dsp_engine.cpp
|  |- test/
|- .github/workflows/flutter-ci.yml
|- .github/workflows/android-release.yml
```

## Local setup

### Prerequisites
- Flutter SDK (stable)
- Android SDK + NDK
- Java 17

### Run in development
```bash
cd app
flutter pub get
flutter run --dart-define=APP_FLAVOR=dev
```

### Run staging
```bash
cd app
flutter run --release --dart-define=APP_FLAVOR=staging
```

### Build production APK
```bash
cd app
flutter build apk --release --dart-define=APP_FLAVOR=prod --dart-define=TELEMETRY_KEY=<your-key>
```

## Android release signing

1. Copy `app/android/key.properties.example` to `app/android/key.properties`.
2. Create a keystore at `app/keystore/neuroamp-release.jks` (or update `storeFile` path).
3. Fill `storePassword`, `keyAlias`, and `keyPassword`.
4. Build release APK.

If `key.properties` is missing, the project falls back to debug signing to preserve local build usability.

## Native bridge methods
- `getHeadTrackingYaw`: returns device yaw from `TYPE_ROTATION_VECTOR` sensor
- `getDspEngineVersion`: returns JNI native runtime version string

## CI/CD
- `flutter-ci.yml`: analyze + unit/widget tests on push and PR
- `android-release.yml`: builds release APK on tags (`v*`) or manual workflow dispatch
- `playstore-release.yml`: builds signed AAB and uploads to Google Play on tag `release/v*`

## Play Store Release Pipeline

For production deployment to Google Play Store:
1. See [RELEASE_SETUP.md](RELEASE_SETUP.md) for complete setup instructions
2. Generate release keystore and configure GitHub Secrets
3. Create Google Play service account with API access
4. Push a tag: `git tag release/v1.0.0 && git push origin release/v1.0.0`
5. Workflow automatically builds signed AAB and uploads to internal testing track
6. Review and promote in Play Store Console

## Recommended next steps
1. Replace DSP JNI stub with real FIR/PEQ processing pipeline.
2. Add Kotlin service for continuous head-tracking updates and smoothing filters.
3. Add instrumentation (Crashlytics/App Insights/Sentry) and performance metrics.
4. Add integration tests for method-channel behavior and audio preset migration.
5. Set up Play Store beta and production release tracks.
