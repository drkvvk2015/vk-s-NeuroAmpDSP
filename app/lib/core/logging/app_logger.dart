import 'dart:developer' as dev;

import '../config/app_env.dart';

class AppLogger {
  const AppLogger();

  void info(String message, {Object? data}) {
    _write('INFO', message, data: data);
  }

  void warning(String message, {Object? data}) {
    _write('WARN', message, data: data);
  }

  void error(String message, {Object? error, StackTrace? stackTrace}) {
    _write('ERROR', message, data: error, stackTrace: stackTrace);
  }

  void _write(String level, String message, {Object? data, StackTrace? stackTrace}) {
    final flavor = AppEnv.flavor.name.toUpperCase();
    dev.log(
      '[$flavor][$level] $message${data == null ? '' : ' | $data'}',
      name: 'NeuroAmp',
      stackTrace: stackTrace,
    );
  }
}
