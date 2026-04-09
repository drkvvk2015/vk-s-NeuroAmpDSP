enum BuildFlavor { dev, staging, prod }

class AppEnv {
  AppEnv._();

  static const String _flavorValue = String.fromEnvironment(
    'APP_FLAVOR',
    defaultValue: 'dev',
  );

  static const String telemetryKey = String.fromEnvironment(
    'TELEMETRY_KEY',
    defaultValue: '',
  );

  static BuildFlavor get flavor {
    switch (_flavorValue) {
      case 'staging':
        return BuildFlavor.staging;
      case 'prod':
        return BuildFlavor.prod;
      case 'dev':
      default:
        return BuildFlavor.dev;
    }
  }

  static bool get isProd => flavor == BuildFlavor.prod;
}
