import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_env.dart';
import 'core/error/error_reporter.dart';
import 'core/logging/app_logger.dart';
import 'core/telemetry/app_insights_telemetry_client.dart';
import 'features/audio/presentation/audio_home_page.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  const logger = AppLogger();
  final telemetryClient = AppEnv.isProd && AppEnv.telemetryKey.isNotEmpty
      ? AppInsightsTelemetryClient(
          instrumentationKey: AppEnv.telemetryKey,
          logger: logger,
        )
      : null;
  final reporter = ErrorReporter(logger, telemetryClient: telemetryClient);

  await reporter.trackEvent(
    'app_bootstrap_start',
    properties: {
      'flavor': AppEnv.flavor.name,
      'telemetryEnabled': (telemetryClient != null).toString(),
    },
  );

  FlutterError.onError = (details) {
    reporter.recordError(details.exception, details.stack ?? StackTrace.current);
  };

  await runZonedGuarded(
    () async {
      runApp(const ProviderScope(child: NeuroAmpApp()));
      await reporter.trackEvent(
        'app_bootstrap_complete',
        properties: {'flavor': AppEnv.flavor.name},
      );
    },
    (error, stackTrace) {
      reporter.recordError(error, stackTrace);
    },
  );
}

class NeuroAmpApp extends StatelessWidget {
  const NeuroAmpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeuroAmp DSP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A7A5C)),
        useMaterial3: true,
      ),
      home: const AudioHomePage(),
    );
  }
}
