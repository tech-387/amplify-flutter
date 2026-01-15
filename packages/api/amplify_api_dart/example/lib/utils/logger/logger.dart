// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:developer' as dev;
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:collection/collection.dart';
import 'package:example/utils/logger/enums/log_mode.dart';
import 'package:example/utils/logger/models/log_class.dart';
import 'package:example/utils/logger/models/stack_trace_call.dart';
import 'package:flutter/foundation.dart';

abstract class Logger {
  static final Set<LogClass> _logs = {};

  /// Method that logs to the console with specified configuration.
  /// It is used for every log type in order to provide consistent logging in the app.
  static void _log(
    dynamic className,
    String methodName,
    String log, {
    required LogMode logMode,
    String? methodStepName,
    int? methodStepExecutionTime,
  }) {
    final DateTime currentTimeStamp = DateTime.now();
    String logModeString;
    switch (logMode) {
      case LogMode.wait:
        logModeString = " ... 🕐";
        break;
      case LogMode.error:
        logModeString = " ❌";
        break;
      case LogMode.success:
        logModeString = " ✅";
      case LogMode.info:
        logModeString = "";
        break;
    }
    final String classNameTrimmed = className.toString().trim();
    final String methodNameTrimmed = methodName.trim();
    String logTrimmed = log.trim();
    if (logTrimmed.isNotEmpty) {
      logTrimmed = " $logTrimmed";
    }
    dev.log(
      "$classNameTrimmed: $methodNameTrimmed():$logTrimmed$logModeString",
      time: currentTimeStamp,
    );

    // Get stack trace calls.
    final stackTraceCalls = getCallerInfo();

    // Check whether there is class in hierarchy, for which logs should be persisted.
    final logClass = _logs.firstWhereOrNull((test) {
      return stackTraceCalls.any(
        (stackTraceCall) => test.className == stackTraceCall.className,
      );
    });

    // Logs are persisted for some class in the hierarchy.
    if (logClass != null) {
      logClass.insertMethodLog(
        className: classNameTrimmed,
        methodName: methodNameTrimmed,
        stackTraceCalls: stackTraceCalls,
        methodStepName: methodStepName,
        methodStepExecutionTime: methodStepExecutionTime,
        log: log,
      );
    }
  }

  /// Method that logs default log with the mode [LogMode.info].
  /// Example:
  /// ```dart
  /// Logger.log("custom log text");
  /// ```
  /// will output:
  ///
  /// ClassName: methodName(): custom log text
  static void log([String? log]) {
    final stackTraceCall = getCallerInfo().first;

    _log(
      stackTraceCall.className,
      stackTraceCall.methodName,
      log ?? "",
      logMode: LogMode.info,
    );
  }

  /// Method that logs waiting/loading log with the mode [LogMode.wait].
  /// Example:
  /// ```dart
  /// Logger.wait("custom log text");
  /// ```
  /// will output:
  ///
  /// ClassName: methodName(): custom log text ... 🕐
  static void wait([String? log]) {
    final stackTraceCall = getCallerInfo().first;

    _log(
      stackTraceCall.className,
      stackTraceCall.methodName,
      log ?? "",
      logMode: LogMode.wait,
    );
  }

  /// Method that logs log with the mode [LogMode.error].
  /// Example:
  /// ```dart
  /// Logger.error("custom error text");
  /// ```
  /// will output:
  ///
  /// ClassName: methodName(): custom error text ❌
  static void error({
    String? log,
    dynamic error,
    StackTrace? stacktrace,
    bool fatal = false,
    List<String> additionalInformation = const [],
  }) {
    final stackTraceCall = getCallerInfo().first;
    final className = stackTraceCall.className;
    final methodName = stackTraceCall.methodName;

    _log(className, methodName, log ?? "", logMode: LogMode.error);

    if (kDebugMode && stacktrace != null) {
      print(stacktrace);
    }
    List<String> information = [];
    if (log != null) {
      information.add(log);
    }
    information.addAll(additionalInformation);
    if (kReleaseMode) {
      _logCrashlytics(
        className: className,
        methodName: methodName,
        log: log,
        error: error,
        stacktrace: stacktrace,
        fatal: fatal,
        information: information,
      );
    }
  }

  /// Method that logs event to crashlytics.
  static void _logCrashlytics({
    required String className,
    required String methodName,
    String? log,
    dynamic error,
    StackTrace? stacktrace,
    bool fatal = false,
    List<String> information = const [],
  }) {
    // Do not log TimeoutException.
    // For example subscription disposal due to inactivity in the background:
    // TimeoutException after 0:05:00.000000: Web Socket Connection Timeout.
    if (error is TimeoutException) {
      Logger.log("Skipping TimeoutException logging to Crashlytics");
      return;
    }

    // Do not log SocketException from amplify graphql requests.
    // For example:
    // UnknownException {"message": "unable to send GraphQLRequest to client.",
    // "underlyingException": "POST https://5xwodmxe6zfrvgtydbkvwzz5cq.appsync-api.us-east-1.amazonaws.com/graphql failed: SocketException: Failed host lookup:
    // '5xwodmxe6zfrvgtydbkvwzz5cq.appsync-api.us-east-1.amazonaws.com' (OS Error: No address associated with hostname, errno = 7)" },
    if (error is UnknownException &&
        error.underlyingException.toString().contains("SocketException")) {
      Logger.log("Skipping SocketException logging to Crashlytics.");
      return;
    }

    // Do not log NetworkException from amplify graphql requests.
    // For example: UnknownException { "message": "unable to send GraphQLRequest to client.", "underlyingException": "NetworkException {\n \"message\": \"The request failed due to a network error.\",
    if (error is UnknownException &&
        error.underlyingException.toString().contains("NetworkException")) {
      Logger.log("Skipping NetworkException logging to Crashlytics.");
      return;
    }

    // Do not log HttpException from amplify graphql requests.
    // For example: UnknownException {"message": "unable to send GraphQLRequest to client.","underlyingException": "POST https://5xwodmxe6zfrvgtydbkvwzz5cq.appsync-api.us-east-1.amazonaws.com/graphql failed: HttpException: Bad file descriptor
    if (error is UnknownException &&
        error.underlyingException.toString().contains("HttpException")) {
      Logger.log("Skipping HttpException logging to Crashlytics.");
      return;
    }

    // Do not log NetworkException.
    // For example: Error: NetworkException {   "message": "Unable to recover network connection, web socket will close.",
    if (error is NetworkException) {
      Logger.log("Skipping NetworkException logging to Crashlytics.");
      return;
    }
  }

  /// Method that logs success log with the mode [LogMode.success].
  /// Example:
  /// ```dart
  /// Logger.success("custom log text");
  /// ```
  /// will output:
  ///
  /// ClassName: methodName(): custom log text ✅
  static void success([
    String? log,
    String? methodStepName,
    int? methodStepExecutionTime,
  ]) {
    final stackTraceCall = getCallerInfo().first;

    _log(
      stackTraceCall.className,
      stackTraceCall.methodName,
      log ?? "",
      logMode: LogMode.success,
      methodStepName: methodStepName,
      methodStepExecutionTime: methodStepExecutionTime,
    );
  }

  /// Method that prepares [Logger] class for persisting subsequent logs.
  /// Note: Call this method before the logs you want to persist.
  /// Both logs in the same class and logs from nested classes will be persisted.
  static void persist() {
    final List<StackTraceCall> stackTraceCalls = getCallerInfo();
    final logClass = LogClass(className: stackTraceCalls.first.className);
    logClass.insertMethod(methodName: stackTraceCalls.first.methodName);
    _logs.add(logClass);
  }

  /// Method that returns the class name and method name of the caller from the stack trace.
  static List<StackTraceCall> getCallerInfo() {
    final stackTrace = StackTrace.current.toString().split('\n');

    final List<StackTraceCall> stackTraceCalls = [];

    for (var frame in stackTrace) {
      if (frame.contains('package:espresso_chat_mobile/') &&
          !frame.contains("Logger") &&
          !frame.contains('FutureExecutionTimeLoggingExtensio')) {
        String className = "Unknown";
        String methodName = "unknown";

        // Special case for main.dart calls.
        // There is no class, just the method name.
        if (frame.contains("main.dart")) {
          className = "Main";
          methodName = "main";
        } else {
          // Handle closures like UserNotifier.initialize.<anonymous closure>
          // Extracts 'UserNotifier' as className and 'initialize' as methodName, from the frame.
          final closureMatch = RegExp(
            r'(\w+)\.(\w+)\.<anonymous closure>',
          ).firstMatch(frame);

          if (closureMatch != null) {
            className = closureMatch.group(1) ?? 'UnknownCaller';
            methodName =
                '${closureMatch.group(2) ?? 'unknownMethod'} (Closure)';
          } else {
            // Standard method calls.
            final match = RegExp(r'(\w+)\.(\w+)\s').firstMatch(frame);

            if (match != null) {
              className = match.group(1) ?? 'UnknownCaller';
              methodName = match.group(2) ?? 'unknownMethod';
            }
          }
        }

        stackTraceCalls.add(
          StackTraceCall(className: className, methodName: methodName),
        );
      }
    }

    if (stackTraceCalls.isEmpty) {
      return [StackTraceCall(className: "Unknown", methodName: "unknown")];
    }

    // If no match is found, return default values.
    return stackTraceCalls;
  }
}
