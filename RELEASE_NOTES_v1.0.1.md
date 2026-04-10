# NeuroAmp Live DSP v1.0.1

## Summary

This release turns the Android app into a usable live DSP monitor instead of a demo-only shell.

## What Changed

- Added live microphone input -> DSP -> speaker monitoring on Android.
- Added runtime microphone permission handling.
- Added file playback routed through the same DSP processing path.
- Added bridge self-test and richer playback diagnostics.
- Added native feedback safety attenuation for live monitoring.
- Added release QA automation and a manual release checklist.
- Fixed Android release build issues for R8/Play Core and Kotlin incremental compilation on Windows.

## User Notes

- Headphones are recommended during live microphone monitoring.
- The app processes microphone input and local file playback.
- Android sandbox rules prevent system-wide audio processing for other apps.

## Upgrade Notes

- Microphone permission is required for live input DSP.
- Existing DSP profile controls continue to work for demo, live mic, and file playback modes.