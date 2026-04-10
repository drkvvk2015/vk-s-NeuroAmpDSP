# Release QA Checklist

## Build and Static Validation
- Run `flutter pub get` in `app`.
- Run `flutter analyze` in `app`.
- Run `flutter test` in `app`.
- Build debug artifact: `flutter build apk --debug`.
- Build release artifact: `flutter build apk --release --dart-define=APP_FLAVOR=prod`.

## Core Runtime Validation
- Launch app on Android device.
- Verify `Bridge Self-Test` reports healthy status.
- Verify live status shows `DSP=true` and no persistent error.
- Verify DSP mode chips render `Standard`, `Enhanced`, `Pro`, and `Root`.

## Audio Path Validation
- Start `Live Mic DSP`.
- Grant microphone permission when prompted.
- Verify speech/music near mic changes output when EQ/Bass/Width sliders move.
- Verify `safety=true` appears only when feedback risk is present.
- Verify stopping live mic DSP fully silences capture path.

## File Playback Validation
- Start `Play WAV Through DSP` with a valid file.
- Confirm processing changes are audible while adjusting profile controls.
- Stop file playback and verify status reports not running.

## Head Tracking and Adaptive
- Enable `Head Tracking` and press `Sync`.
- Confirm spatial value updates without errors.
- Enable `AI Adaptive Tuning` and verify profile updates during active playback.

## Stability and Lifecycle
- Background and foreground the app.
- Verify playback paths stop safely on pause and can restart.
- Rotate device and confirm app remains functional.
- Verify no crash on startup, permission denial, or playback stop/start loops.

## Enhanced / Pro Validation
- Switch to `Enhanced` mode and verify capability text updates.
- Open notification access settings from the app and confirm the NeuroAmp notification listener can be enabled.
- Start playback in a supported external audio app and verify session/app status changes when Android exposes an effect session.
- Request Shizuku permission and verify `Pro` mode stays blocked until Shizuku is available and granted.

## Final Sign-off
- Confirm release notes include microphone permission requirement.
- Confirm known Android sandbox limitation is documented (no guaranteed system-wide PCM interception).
- Archive APK/AAB artifacts and test evidence.
