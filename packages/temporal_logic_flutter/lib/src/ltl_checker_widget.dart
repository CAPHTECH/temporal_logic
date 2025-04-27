import 'dart:async'; // Keep for Stream type

import 'package:flutter/material.dart';
import 'package:temporal_logic_core/temporal_logic_core.dart';

import 'stream_ltl_checker.dart'; // Assuming this exists and is updated

/// A widget that observes a [stream] of state [S] and displays
/// whether a Linear Temporal Logic (LTL) [formula] holds true based on the
/// sequence of states observed from the [stream].
///
/// This widget uses a [StreamLtlChecker] internally to perform the LTL evaluation.
/// It subscribes to the checker's result stream and rebuilds its UI whenever
/// the boolean truth value of the [formula] changes.
///
/// An initial state can be provided via [initialValue], which is considered
/// the first state in the trace before any events from the [stream] arrive.
/// The widget displays an initial result based on evaluating the [formula]
/// against this initial state (or an empty trace if [initialValue] is null).
///
/// If the input [stream] or [formula] changes, the internal checker is updated
/// automatically.
///
/// The visual representation is determined by the [builder] function, which defaults
/// to displaying a green check icon ([Icons.check_circle]) if the formula holds,
/// and a red cancel icon ([Icons.cancel]) otherwise.
///
/// Type parameter [S] defines the type of the state values from the stream.
class LtlCheckerWidget<S> extends StatefulWidget {
  /// The stream of states to observe.
  ///
  /// The LTL [formula] will be evaluated against the sequence of states
  /// emitted by this stream.
  final Stream<S> stream;

  /// The LTL formula to check against the trace derived from the stream.
  ///
  /// This formula defines the temporal property to be monitored.
  final Formula<S> formula; // Use Formula<S> instead of Ltl<S>

  /// An optional initial value for the state, used before the stream emits its first event.
  ///
  /// If provided, this value is considered the state at time 0. If `null`,
  /// the evaluation starts with an empty trace.
  final S? initialValue;

  /// A builder function to customize the widget displayed based on the result.
  ///
  /// The builder receives the current [BuildContext] and the latest boolean
  /// evaluation [result] of the LTL formula.
  ///
  /// Defaults to displaying a simple [Icon] (check_circle for true, cancel for false).
  final Widget Function(BuildContext context, bool result)? builder;

  /// Creates an [LtlCheckerWidget].
  ///
  /// Requires a [stream] of states and the LTL [formula] to evaluate.
  /// Optionally accepts an [initialValue] and a custom [builder] function.
  const LtlCheckerWidget({
    super.key,
    required this.stream,
    required this.formula,
    this.initialValue, // Added initialValue
    this.builder,
  });

  @override
  // Update the State type
  State<LtlCheckerWidget<S>> createState() => _LtlCheckerWidgetState<S>();
}

// Changed to State
class _LtlCheckerWidgetState<S> extends State<LtlCheckerWidget<S>> {
  late StreamLtlChecker<S> _checker;
  late bool _initialResult;

  @override
  void initState() {
    super.initState();
    _initialResult = _calculateInitialResult();
    _initializeChecker();
  }

  bool _calculateInitialResult() {
    if (widget.initialValue == null) {
      final emptyTrace = Trace<S>.empty();
      return evaluateTrace(emptyTrace, widget.formula).holds;
    } else {
      final initialTrace = Trace<S>.fromList([widget.initialValue as S]);
      return evaluateTrace(initialTrace, widget.formula, startIndex: 0).holds;
    }
  }

  void _initializeChecker() {
    _checker = StreamLtlChecker<S>(
      stream: widget.stream,
      formula: widget.formula,
      initialValue: widget.initialValue,
    );
  }

  @override
  void didUpdateWidget(covariant LtlCheckerWidget<S> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stream != oldWidget.stream ||
        widget.formula != oldWidget.formula ||
        widget.initialValue != oldWidget.initialValue) {
      _checker.dispose();
      // Recalculate initial result for the new checker setup,
      // used if the stream rebuilds before emitting.
      _initialResult = _calculateInitialResult();
      _initializeChecker();
    }
  }

  @override
  void dispose() {
    _checker.dispose();
    super.dispose();
  }

  Widget _defaultBuilder(BuildContext context, bool result) {
    return Icon(
      result ? Icons.check_circle : Icons.cancel,
      color: result ? Colors.green : Colors.red,
      semanticLabel: result ? 'Formula holds' : 'Formula does not hold',
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      initialData: _initialResult,
      stream: _checker.resultStream,
      builder: (context, snapshot) {
        final bool result = snapshot.hasData ? snapshot.data! : _initialResult;
        final builder = widget.builder ?? _defaultBuilder;
        return builder(context, result);
      },
    );
  }
}
