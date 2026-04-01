/// Defines where a stream checker evaluates a formula on the accumulated trace.
enum StreamEvaluationStart {
  /// Evaluate from the beginning of the accumulated trace.
  beginning,

  /// Evaluate from the most recent event in the accumulated trace.
  current,
}

extension StreamEvaluationStartIndex on StreamEvaluationStart {
  /// Resolves the start index for a trace with the given [traceLength].
  int resolveStartIndex(int traceLength) {
    if (traceLength <= 0) {
      return 0;
    }

    return switch (this) {
      StreamEvaluationStart.beginning => 0,
      StreamEvaluationStart.current => traceLength - 1,
    };
  }
}
