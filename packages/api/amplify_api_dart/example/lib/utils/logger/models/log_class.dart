import 'package:example/utils/logger/models/log_method.dart';
import 'package:example/utils/logger/models/stack_trace_call.dart';

/// Class that groups all logs belonging to a class.
class LogClass {
  /// The name of the class.
  final String className;

  /// The methods of the class.
  final Set<LogMethod> methods = {};

  LogClass({required this.className});

  @override
  int get hashCode => className.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is! LogClass) {
      return false;
    }
    return className == other.className;
  }

  void insertMethodLog({
    required String className,
    required String methodName,
    required List<StackTraceCall> stackTraceCalls,
    String? methodStepName,
    int? methodStepExecutionTime,
    String? log,
  }) {
    if (log == null || methods.isEmpty) {
      return;
    }

    final LogMethod logMethod = methods.firstWhere(
      (element) => element.methodName == methodName,
      orElse: () => methods.first,
    );

    logMethod.addLogMethodStep(
      methodName: methodName,
      className: className,
      methodStepName: methodStepName,
      methodStepExecutionTime: methodStepExecutionTime,
      log: log,
    );

    methods.add(logMethod);
  }

  /// Method that inserts a method log to the list of methods.
  /// TODO: Fix method adding by stacktrace calls.
  void insertMethod({required String methodName}) {
    methods.add(LogMethod(methodName: methodName));
  }

  Map<String, dynamic> toJson() {
    return {
      'className': className,
      'methods': methods.map((e) => e.toJson()).toList(),
    };
  }
}
