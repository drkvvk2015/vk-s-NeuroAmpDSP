import 'package:flutter_test/flutter_test.dart';

import 'package:neuroamp_app/core/error/error_reporter.dart';
import 'package:neuroamp_app/core/logging/app_logger.dart';
import 'package:neuroamp_app/core/telemetry/telemetry_client.dart';

class _FakeTelemetryClient implements TelemetryClient {
  int exceptions = 0;
  int events = 0;
  String? lastReason;
  String? lastEventName;

  @override
  Future<void> trackException({
    required Object error,
    required StackTrace stackTrace,
    required String reason,
    Map<String, String>? properties,
  }) async {
    exceptions++;
    lastReason = reason;
  }

  @override
  Future<void> trackEvent({
    required String name,
    Map<String, String>? properties,
    Map<String, double>? measurements,
  }) async {
    events++;
    lastEventName = name;
  }
}

void main() {
  test('recordError forwards exception telemetry when client exists', () async {
    final telemetry = _FakeTelemetryClient();
    final reporter = ErrorReporter(const AppLogger(), telemetryClient: telemetry);

    await reporter.recordError(
      StateError('boom'),
      StackTrace.current,
      reason: 'Test failure path',
    );

    expect(telemetry.exceptions, 1);
    expect(telemetry.lastReason, 'Test failure path');
  });

  test('trackEvent forwards event telemetry when client exists', () async {
    final telemetry = _FakeTelemetryClient();
    final reporter = ErrorReporter(const AppLogger(), telemetryClient: telemetry);

    await reporter.trackEvent('app_ready', properties: {'flavor': 'prod'});

    expect(telemetry.events, 1);
    expect(telemetry.lastEventName, 'app_ready');
  });

  test('recordError does not throw without telemetry client', () async {
    final reporter = ErrorReporter(const AppLogger());

    await reporter.recordError(Exception('no telemetry'), StackTrace.current);

    expect(true, isTrue);
  });
}
