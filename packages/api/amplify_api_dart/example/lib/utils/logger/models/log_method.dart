import 'package:example/utils/logger/models/log_method_step.dart';

class LogMethod {
  final String methodName;
  final List<LogMethodStep> steps = [];

  LogMethod({required this.methodName});

  @override
  int get hashCode => methodName.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is! LogMethod) {
      return false;
    }
    return methodName == other.methodName;
  }

  void addLogMethodStep({
    required String className,
    required String methodName,
    String? methodStepName,
    int? methodStepExecutionTime,
    String? log,
  }) {
    final LogMethodStep logMethodStep = LogMethodStep(
      className: className,
      methodName: methodName,
      stepName: methodStepName,
      executionMs: methodStepExecutionTime,
      log: log,
    );

    steps.add(logMethodStep);
  }

  Map<String, dynamic> toJson() {
    return {
      'methodName': methodName,
      'steps': steps.map((step) => step.toJson()).toList(),
    };
  }
}
