import 'package:flutter/foundation.dart';

/// Simple logging service for the application
/// Provides structured logging for development and production
class LoggingService {
  LoggingService._();
  static final LoggingService instance = LoggingService._();

  /// Log info level messages
  void info(String message) {
    if (kDebugMode) {
      debugPrint('ℹ️  [INFO] $message');
    }
  }

  /// Log debug level messages
  void debug(String message) {
    if (kDebugMode) {
      debugPrint('🔍 [DEBUG] $message');
    }
  }

  /// Log success messages
  void success(String message) {
    if (kDebugMode) {
      debugPrint('✅ [SUCCESS] $message');
    }
  }

  /// Log warning level messages
  void warning(String message) {
    if (kDebugMode) {
      debugPrint('⚠️  [WARNING] $message');
    } else {
      debugPrint('⚠️  [WARNING] $message');
    }
  }

  /// Log error level messages
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('❌ [ERROR] $message');
      if (error != null) {
        debugPrint('   Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('   Stack trace: $stackTrace');
      }
    } else {
      debugPrint('❌ [ERROR] $message');
    }
  }
}

final logger = LoggingService.instance;
