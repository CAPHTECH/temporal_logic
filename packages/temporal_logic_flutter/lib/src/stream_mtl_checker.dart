import 'package:temporal_logic_mtl/temporal_logic_mtl.dart';

import 'stream_evaluation_start.dart';
import 'stream_trace_checker_base.dart';

/// Provides periodic evaluation of a temporal logic [Formula]<S> (LTL/MTL)
/// against a stream of time-stamped values. Incoming events are accumulated
/// into an internal trace and evaluated on every new event.
///
/// Type parameter [S] defines the type of the state values in the trace.
class StreamMtlChecker<S> extends StreamTraceCheckerBase<TimedValue<S>,
    TraceEvent<S>, Trace<S>, EvaluationResult> {
  final Formula<S> _formula;

  /// Creates a [StreamMtlChecker] that listens to the specified [stream] of
  /// timed states and evaluates the given [formula]. If [initialValue] is
  /// provided, it is used as the first trace event before any stream emissions.
  /// Evaluation occurs on each new event and immediately for the initial value.
  StreamMtlChecker(
    Stream<TimedValue<S>> stream, {
    required Formula<S> formula,
    TimedValue<S>? initialValue,
    StreamEvaluationStart evaluationStart = StreamEvaluationStart.beginning,
  })  : _formula = formula,
        super(
          stream,
          evaluationStart: evaluationStart,
          buildTraceSnapshot: (entries) => Trace<S>(entries),
          initialEntry: initialValue == null
              ? null
              : TraceEvent(
                  timestamp: initialValue.timestamp,
                  value: initialValue.value,
                ),
        ) {
    initializeWithInitialEvaluation(_evaluate);
  }

  @override
  void onInput(TimedValue<S> input) {
    appendTraceEntry(
      TraceEvent(timestamp: input.timestamp, value: input.value),
    );
  }

  @override
  EvaluationResult evaluateCurrent() {
    return _evaluate();
  }

  /// Performs the actual LTL/MTL check using the integrated evaluator.
  EvaluationResult _evaluate() {
    final currentTrace = buildCurrentTrace();
    return evaluateMtlTrace(
      currentTrace,
      _formula,
      startIndex: resolveStartIndex(),
    );
  }
}
