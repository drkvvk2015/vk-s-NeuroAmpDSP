import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/error/error_reporter.dart';
import 'core/logging/app_logger.dart';
import 'features/audio/presentation/audio_home_page.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  const logger = AppLogger();
  final reporter = ErrorReporter(logger);

  FlutterError.onError = (details) {
    reporter.recordError(details.exception, details.stack ?? StackTrace.current);
  };

  await runZonedGuarded(
    () async {
      runApp(const ProviderScope(child: NeuroAmpApp()));
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
