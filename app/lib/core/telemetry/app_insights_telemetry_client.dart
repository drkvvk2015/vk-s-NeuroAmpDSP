import 'dart:convert';
import 'dart:io';

import '../logging/app_logger.dart';
import 'telemetry_client.dart';

class AppInsightsTelemetryClient implements TelemetryClient {
  AppInsightsTelemetryClient({
    required this.instrumentationKey,
    required AppLogger logger,
    HttpClient? httpClient,
    this.ingestionUri = 'https://dc.services.visualstudio.com/v2/track',
  }) : _logger = logger,
       _httpClient = httpClient ?? HttpClient();

  final String instrumentationKey;
  final String ingestionUri;
  final AppLogger _logger;
  final HttpClient _httpClient;

  @override
  Future<void> trackException({
    required Object error,
    required StackTrace stackTrace,
    required String reason,
    Map<String, String>? properties,
  }) {
    final data = {
      'ver': 2,
      'severityLevel': 3,
      'exceptions': [
        {
          'id': 1,
          'typeName': error.runtimeType.toString(),
          'message': error.toString(),
          'hasFullStack': true,
          'stack': stackTrace.toString(),
        },
      ],
      'properties': {
        'reason': reason,
        if (properties != null) ...properties,
      },
    };

    return _sendEnvelope(
      name: 'Microsoft.ApplicationInsights.Exception',
      baseType: 'ExceptionData',
      baseData: data,
    );
  }

  @override
  Future<void> trackEvent({
    required String name,
    Map<String, String>? properties,
    Map<String, double>? measurements,
  }) {
    final data = {
      'ver': 2,
      'name': name,
      'properties': properties ?? const <String, String>{},
      'measurements': measurements ?? const <String, double>{},
    };

    return _sendEnvelope(
      name: 'Microsoft.ApplicationInsights.Event',
      baseType: 'EventData',
      baseData: data,
    );
  }

  Future<void> _sendEnvelope({
    required String name,
    required String baseType,
    required Map<String, Object?> baseData,
  }) async {
    if (instrumentationKey.isEmpty) {
      return;
    }

    final payload = [
      {
        'name': name,
        'time': DateTime.now().toUtc().toIso8601String(),
        'iKey': instrumentationKey,
        'tags': {
          'ai.cloud.role': 'neuroamp_app',
          'ai.internal.sdkVersion': 'neuroamp-flutter:1.0.0',
        },
        'data': {
          'baseType': baseType,
          'baseData': baseData,
        },
      },
    ];

    try {
      final uri = Uri.parse(ingestionUri);
      final request = await _httpClient.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.write(jsonEncode(payload));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode > 299) {
        _logger.warning(
          'Telemetry submission failed',
          data: {'statusCode': response.statusCode},
        );
      }
    } catch (error, stackTrace) {
      _logger.warning(
        'Telemetry submission threw exception',
        data: error,
      );
      _logger.error(
        'Telemetry failure stack trace',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
