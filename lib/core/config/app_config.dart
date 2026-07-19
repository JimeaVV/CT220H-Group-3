class AppConfig {
  AppConfig._();

  static const String appName = 'FinTrack';

  /// Android Emulator truy cập máy tính host bằng 10.0.2.2.
  /// Có thể đổi lúc chạy:
  /// flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
}
