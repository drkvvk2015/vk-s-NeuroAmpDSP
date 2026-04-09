import '../config/app_env.dart';
import '../logging/app_logger.dart';

class ErrorReporter {
  ErrorReporter(this._logger);

  final AppLogger _logger;

  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    String reason = 'Unhandled exception',
  }) async {
    _logger.error(reason, error: error, stackTrace: stackTrace);

    if (AppEnv.telemetryKey.isNotEmpty && AppEnv.isProd) {
      // Integrate with Sentry/Crashlytics/AppInsights in production.
    }
  }
}
