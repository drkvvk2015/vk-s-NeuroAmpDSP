# NeuroAmp App

Production-ready Flutter control app for NeuroAmp DSP engine.

## Highlights
- Multi-band EQ controls
- Spatial width and limiter controls
- AI adaptive tuning heuristics
- Android sensor-backed head-tracking sync
- Native method-channel bridge for DSP runtime info
- Persistent local profile storage
- App flavors via dart-define
- Structured logging + crash reporting extension point
- JNI/C++ DSP stub integration

## Local development

```bash
cd app
flutter pub get
flutter run --dart-define=APP_FLAVOR=dev
```

## Staging build

```bash
cd app
flutter run --release --dart-define=APP_FLAVOR=staging
```

## Production build

```bash
cd app
flutter build apk --release --dart-define=APP_FLAVOR=prod --dart-define=TELEMETRY_KEY=<your-key>
```

## Android release signing

```bash
cd app/android
copy key.properties.example key.properties
```

Fill signing values in `key.properties` and ensure keystore path exists.

## Native channel contract
- `getHeadTrackingYaw`
- `getDspEngineVersion`
