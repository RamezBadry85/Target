import 'dart:developer' as developer;

/// Log technical failures only. Never log customer records or credentials.
abstract final class AppLogger {
  static void error(String message, Object error, StackTrace? stackTrace) {
    developer.log(
      message,
      name: 'target',
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
