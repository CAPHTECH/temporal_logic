import 'package:flutter/material.dart';
import 'package:temporal_logic_mtl/temporal_logic_mtl.dart';

import 'checker_widget_state_base.dart';
import 'stream_mtl_checker.dart';
import 'stream_evaluation_start.dart';

/// A widget that observes a [stream] of timed states [TimedValue<S>] and displays
/// whether a temporal logic [formula] (LTL or MTL) holds true based on the
/// timed sequence of states observed from the [stream].
///
/// This widget utilizes a [StreamMtlChecker] internally to perform the evaluation.
/// It subscribes to the checker's stream of [EvaluationResult]s and rebuilds
/// its UI whenever a new result is emitted.
///
/// An optional [initialValue] ([TimedValue]) can be provided to represent the
/// state at time zero, before any events from the [stream] arrive.
/// The widget displays an initial result based on evaluating the [formula]
/// against this initial state (or an empty trace if [initialValue] is null).
///
/// If the input [stream], [formula], or [initialValue] changes, the internal
/// checker is automatically updated via `didUpdateWidget`.
///
/// The visual representation is determined by the [builder] function. The builder
/// receives the context, the boolean `holds` value from the latest
/// [EvaluationResult], and the full [EvaluationResult] object for more details.
/// The default builder displays a green check icon ([Icons.check_circle]) if the
/// formula holds, a red cancel icon ([Icons.cancel]) otherwise, and shows the
/// result's reason (if any) in a [Tooltip].
///
/// Type parameter [S] defines the type of the state values within the [TimedValue]s.
class MtlCheckerWidget<S> extends StatefulWidget {
  /// The stream of timed states to observe.
  ///
  /// Each event in the stream should be a [TimedValue] containing the state
  /// and its timestamp.
  final Stream<TimedValue<S>> stream;

  /// The LTL or MTL formula to check against the trace derived from the stream.
  ///
  /// This can include both LTL operators (like `Always`, `Eventually`) and
  /// MTL operators with time bounds (like `Always(..., interval: ...)`).
  final Formula<S> formula;

  /// An optional initial value for the state, used before the stream emits its first event.
  ///
  /// This [TimedValue] represents the state at `t=0` (or the timestamp specified
  /// within it). If `null`, evaluation starts with an empty trace.
  final TimedValue<S>? initialValue;

  /// Controls where formula evaluation begins on the accumulated trace.
  final StreamEvaluationStart evaluationStart;

  /// A builder function to customize the widget displayed based on the evaluation result.
  ///
  /// Provides the build context, the boolean evaluation result (`holds`), and the
  /// full [EvaluationResult] object which may contain more details (like a reason
  /// for failure).
  ///
  /// Defaults to displaying a simple [Icon] (check_circle for true, cancel for false) wrapped in a [Tooltip].
  final Widget Function(
      BuildContext context, bool result, EvaluationResult details)? builder;

  /// Creates an [MtlCheckerWidget].
  ///
  /// Requires a [stream] of [TimedValue] states and the temporal logic [formula]
  /// (LTL or MTL) to evaluate.
  /// Optionally accepts an [initialValue] and a custom [builder] function.
  const MtlCheckerWidget({
    super.key,
    required this.stream,
    required this.formula,
    this.initialValue,
    this.evaluationStart = StreamEvaluationStart.beginning,
    this.builder,
  });

  @override
  State<MtlCheckerWidget<S>> createState() => _MtlCheckerWidgetState<S>();
}

class _MtlCheckerWidgetState<S>
    extends CheckerWidgetStateBase<MtlCheckerWidget<S>, EvaluationResult> {
  late StreamMtlChecker<S> _checker;

  @override
  EvaluationResult calculateInitialResult() {
    final initialValue = widget.initialValue;
    final trace = initialValue == null
        ? Trace<S>.empty()
        : Trace<S>([
            TraceEvent(
              timestamp: initialValue.timestamp,
              value: initialValue.value,
            ),
          ]);

    return evaluateMtlTrace(
      trace,
      widget.formula,
      startIndex: widget.evaluationStart.resolveStartIndex(trace.length),
    );
  }

  @override
  void initializeChecker() {
    _checker = StreamMtlChecker<S>(
      widget.stream,
      formula: widget.formula,
      initialValue: widget.initialValue,
      evaluationStart: widget.evaluationStart,
    );
  }

  @override
  bool shouldRecreateChecker(covariant MtlCheckerWidget<S> oldWidget) {
    return widget.stream != oldWidget.stream ||
        widget.formula != oldWidget.formula ||
        widget.initialValue != oldWidget.initialValue ||
        widget.evaluationStart != oldWidget.evaluationStart;
  }

  @override
  void disposeChecker() {
    _checker.dispose();
  }

  /// The default builder used if [MtlCheckerWidget.builder] is not provided.
  /// Displays an icon (check or cancel) with a tooltip showing details.
  Widget _defaultBuilder(
      BuildContext context, bool result, EvaluationResult details) {
    return Tooltip(
      // Provide more details on hover (e.g., failure reason).
      message: details.reason ??
          (result ? 'Formula holds' : 'Formula does not hold'),
      child: Icon(
        result ? Icons.check_circle : Icons.cancel,
        color: result ? Colors.green : Colors.red,
        // Optional: Add semantic label for accessibility.
        semanticLabel: result ? 'Check passed' : 'Check failed',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildResultStream(
      key: ObjectKey(_checker),
      stream: _checker.resultStream,
      builder: (context, evalResult) {
        final builder = widget.builder ?? _defaultBuilder;
        return builder(context, evalResult.holds, evalResult);
      },
    );
  }
}
