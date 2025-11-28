import 'package:logger/logger.dart';

class TavusLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
    level: Level.debug,
  );

  static bool _enabled = true;
  
  static void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    if (!_enabled) return;
    _logger.d('[TavusAvatar] $message', error: error, stackTrace: stackTrace);
  }

  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    if (!_enabled) return;
    _logger.i('[TavusAvatar] $message', error: error, stackTrace: stackTrace);
  }

  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    if (!_enabled) return;
    _logger.w('[TavusAvatar] $message', error: error, stackTrace: stackTrace);
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (!_enabled) return;
    _logger.e('[TavusAvatar] $message', error: error, stackTrace: stackTrace);
  }
}