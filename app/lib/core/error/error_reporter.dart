import '../logging/app_logger.dart';
import '../telemetry/telemetry_client.dart';

class ErrorReporter {
  ErrorReporter(this._logger, {TelemetryClient? telemetryClient})
    : _telemetryClient = telemetryClient;

  final AppLogger _logger;
  final TelemetryClient? _telemetryClient;

  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    String reason = 'Unhandled exception',
  }) async {
    _logger.error(reason, error: error, stackTrace: stackTrace);

    await _telemetryClient?.trackException(
      error: error,
      stackTrace: stackTrace,
      reason: reason,
    );
  }

  Future<void> trackEvent(
    String name, {
    Map<String, String>? properties,
    Map<String, double>? measurements,
  }) async {
    _logger.info('Telemetry event: $name', data: properties);
    await _telemetryClient?.trackEvent(
      name: name,
      properties: properties,
      measurements: measurements,
    );
  }
}
