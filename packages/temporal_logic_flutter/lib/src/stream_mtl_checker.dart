import 'package:temporal_logic_mtl/temporal_logic_mtl.dart';

import 'formula_stream_checker_base.dart';
import 'stream_evaluation_start.dart';

/// Provides periodic evaluation of a temporal logic [Formula]<S> (LTL/MTL)
/// against a stream of time-stamped values. Incoming events are accumulated
/// into an internal trace and evaluated on every new event.
///
/// Type parameter [S] defines the type of the state values in the trace.
class StreamMtlChecker<S>
    extends FormulaStreamCheckerBase<TimedValue<S>, EvaluationResult> {
  final Formula<S> _formula;
  final List<TraceEvent<S>> _internalTraceEvents = [];
  final TimedValue<S>? _initialValue;
  final StreamEvaluationStart _evaluationStart;

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
        _initialValue = initialValue,
        _evaluationStart = evaluationStart,
        super(stream) {
    final initialTimedValue = _initialValue;
    if (initialTimedValue != null) {
      _internalTraceEvents.add(TraceEvent(
          timestamp: initialTimedValue.timestamp,
          value: initialTimedValue.value));
    }
    initializeWithInitialEvaluation(_evaluate);
  }

  @override
  void onInput(TimedValue<S> input) {
    _internalTraceEvents
        .add(TraceEvent(timestamp: input.timestamp, value: input.value));
  }

  @override
  EvaluationResult evaluateCurrent() {
    return _evaluate();
  }

  /// Performs the actual LTL/MTL check using the integrated evaluator.
  EvaluationResult _evaluate() {
    // Create Trace from the list of TraceEvents
    final currentTrace = Trace(_internalTraceEvents);
    // Use the unified evaluator from the mtl package
    return evaluateMtlTrace(
      currentTrace,
      _formula,
      startIndex: _evaluationStart.resolveStartIndex(currentTrace.length),
    );
  }

  /// Disposes the checker by cancelling the stream subscription, closing
  /// the [resultStream], and clearing all internal trace events.
  /// After disposal, no further results will be emitted.
  @override
  void dispose() {
    _internalTraceEvents.clear();
    super.dispose();
  }
}
