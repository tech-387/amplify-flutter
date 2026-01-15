import 'package:example/utils/logger/logger.dart';

extension FutureExecutionTimeLoggingExtensio<T> on Future<T> {
  /// Method that logs the execution time of a future.
  ///
  /// Example:
  /// ```dart
  /// Future.delayed(Duration(seconds: 2), () => 42).logExecutionTime('Delayed future');
  /// ```
  Future<T> logExecutionTime([String? operationName]) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await this;
    } finally {
      stopwatch.stop();
      final logMessage =
          '${operationName ?? 'Operation'} completed in ${stopwatch.elapsedMilliseconds} ms';
      Logger.success(logMessage, operationName, stopwatch.elapsedMilliseconds);
    }
  }
}
