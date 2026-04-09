abstract class TelemetryClient {
  Future<void> trackException({
    required Object error,
    required StackTrace stackTrace,
    required String reason,
    Map<String, String>? properties,
  });

  Future<void> trackEvent({
    required String name,
    Map<String, String>? properties,
    Map<String, double>? measurements,
  });
}
