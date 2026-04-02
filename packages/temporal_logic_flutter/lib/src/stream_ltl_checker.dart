import 'package:temporal_logic_core/temporal_logic_core.dart';

import 'stream_evaluation_start.dart';
import 'stream_trace_checker_base.dart';

/// Provides evaluation of a Linear Temporal Logic (LTL) [Formula]<S>
/// against a stream of state values.
///
/// Incoming states from the [stream] are accumulated into an internal trace.
/// An optional [initialValue] can be provided to seed the trace before any
/// stream events are processed.
///
/// The LTL [formula] is evaluated against the current trace whenever a new state
/// arrives. The boolean result of the evaluation is emitted on the [resultStream].
/// An initial evaluation result (based on the trace containing only the
/// [initialValue], if provided, or an empty trace otherwise) is emitted shortly
/// after the checker is created.
///
/// Type parameter [S] defines the type of the state values.
class StreamLtlChecker<S> extends StreamTraceCheckerBase<S, S, Trace<S>, bool> {
  final Formula<S> _formula;

  /// Creates an [StreamLtlChecker] that listens to the specified [stream] of
  /// states and evaluates the given LTL [formula].
  ///
  /// - [stream]: The source of state values.
  /// - [formula]: The LTL formula to evaluate against the trace formed by
  ///   states from the [stream].
  /// - [initialValue]: An optional state value to be treated as the first element
  ///   in the trace, before any events from the [stream] are processed. If `null`,
  ///   the initial trace is empty.
  /// - [evaluationStart]: Whether to evaluate from the beginning of the
  ///   accumulated trace or from the most recent state.
  StreamLtlChecker({
    required Stream<S> stream,
    required Formula<S> formula,
    S? initialValue,
    StreamEvaluationStart evaluationStart = StreamEvaluationStart.beginning,
  })  : _formula = formula,
        super(
          stream,
          evaluationStart: evaluationStart,
          buildTraceSnapshot: (entries) => Trace<S>.fromList(entries),
          initialEntry: initialValue,
        ) {
    initializeWithInitialEvaluation(check);
  }

  @override
  void onInput(S input) {
    appendTraceEntry(input);
  }

  @override
  bool evaluateCurrent() {
    return check();
  }

  /// Evaluates the LTL [formula] on the accumulated trace.
  ///
  /// This method performs the LTL evaluation based on the current internal trace.
  /// It uses [evaluateTrace] from `temporal_logic_core`, starting the evaluation
  /// from the position configured by [StreamEvaluationStart].
  ///
  /// Returns the boolean result of the evaluation. If the internal trace is
  /// empty, it evaluates the formula on an empty trace (using index 0).
  bool check() {
    final currentTrace = buildCurrentTrace();
    final result = evaluateTrace(
      currentTrace,
      _formula,
      startIndex: resolveStartIndex(),
    );
    return result.holds;
  }
}
