import 'dart:async';

import 'package:flutter/material.dart';
import 'package:temporal_logic_core/temporal_logic_core.dart';
import 'package:temporal_logic_mtl/temporal_logic_mtl.dart';

import 'stream_mtl_checker.dart'; // Import the redesigned checker

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

  /// A builder function to customize the widget displayed based on the evaluation result.
  ///
  /// Provides the build context, the boolean evaluation result (`holds`), and the
  /// full [EvaluationResult] object which may contain more details (like a reason
  /// for failure).
  ///
  /// Defaults to displaying a simple [Icon] (check_circle for true, cancel for false) wrapped in a [Tooltip].
  final Widget Function(BuildContext context, bool result, EvaluationResult details)? builder;

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
    this.builder,
  });

  @override
  State<MtlCheckerWidget<S>> createState() => _MtlCheckerWidgetState<S>();
}

class _MtlCheckerWidgetState<S> extends State<MtlCheckerWidget<S>> {
  late StreamMtlChecker<S> _checker;
  // Initialize with a placeholder state until the stream provides the first result.
  EvaluationResult? _lastKnownResult = const EvaluationResult(false, reason: 'Initializing...');
  StreamSubscription<EvaluationResult>? _resultSubscription;

  @override
  void initState() {
    super.initState();
    _initializeChecker();
    // The initial result will come from the stream shortly after initialization.
  }

  // Initializes or re-initializes the underlying StreamMtlChecker and its subscription.
  void _initializeChecker() {
    _checker = StreamMtlChecker<S>(
      widget.stream,
      formula: widget.formula,
      initialValue: widget.initialValue,
    );
    // Cancel any existing subscription before creating a new one.
    _resultSubscription?.cancel();
    _resultSubscription = _checker.resultStream.listen(
      (result) {
        if (mounted) {
          // Update the state only if the widget is still mounted.
          setState(() {
            _lastKnownResult = result;
          });
        }
      },
      onError: (e) {
        // Handle potential errors from the stream.
        if (mounted) {
          setState(() {
            // Update the result to reflect the error state.
            _lastKnownResult = EvaluationResult(false, reason: 'Stream Error: $e');
          });
        }
      },
      // Optionally handle stream completion if needed, e.g., update UI
      // onDone: () { ... }
    );
  }

  @override
  void didUpdateWidget(covariant MtlCheckerWidget<S> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-initialize the checker if the stream, formula, or initialValue changes.
    if (widget.stream != oldWidget.stream ||
        widget.formula != oldWidget.formula ||
        widget.initialValue != oldWidget.initialValue) {
      // Dispose the old checker resources before creating a new one.
      _checker.dispose();
      // The subscription is implicitly cancelled by dispose, but explicit cancel is safe.
      // _resultSubscription?.cancel();
      _initializeChecker();
      // No setState needed here; the new stream will provide updates.
    }
  }

  @override
  void dispose() {
    // Ensure resources are cleaned up when the widget is removed.
    _resultSubscription?.cancel();
    _checker.dispose();
    super.dispose();
  }

  /// The default builder used if [MtlCheckerWidget.builder] is not provided.
  /// Displays an icon (check or cancel) with a tooltip showing details.
  Widget _defaultBuilder(BuildContext context, bool result, EvaluationResult details) {
    return Tooltip(
      // Provide more details on hover (e.g., failure reason).
      message: details.reason ?? (result ? 'Formula holds' : 'Formula does not hold'),
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
    // StreamBuilder listens to the checker's results and rebuilds the UI.
    return StreamBuilder<EvaluationResult>(
      stream: _checker.resultStream,
      // Provide the last known result as initial data to avoid flicker.
      initialData: _lastKnownResult,
      builder: (context, snapshot) {
        // Prioritize fresh data from the stream snapshot if available.
        final evalResult = snapshot.hasData ? snapshot.data! : _lastKnownResult;

        // Extract the boolean result, defaulting to false if no result yet.
        final bool holds = evalResult?.holds ?? false;
        // Ensure we always have a non-null EvaluationResult for the builder.
        final EvaluationResult details = evalResult ?? const EvaluationResult(false, reason: 'Waiting for stream...');

        // Use the user-provided builder, or the default one.
        final builder = widget.builder ?? _defaultBuilder;
        return builder(context, holds, details);
      },
    );
  }
}
