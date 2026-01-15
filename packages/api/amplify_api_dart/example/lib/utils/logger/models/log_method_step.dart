class LogMethodStep {
  final String className;
  final String methodName;
  final String? stepName;
  final int? executionMs;
  final String? log;

  const LogMethodStep({
    required this.className,
    required this.methodName,
    this.stepName,
    this.executionMs,
    this.log,
  });

  Map<String, dynamic> toJson() {
    return {
      'className': className,
      'methodName': methodName,
      'stepName': stepName,
      'executionMs': executionMs,
      'log': log,
    };
  }
}
