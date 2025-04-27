import 'dart:async';

import 'package:flutter/material.dart';
import 'package:temporal_logic_core/temporal_logic_core.dart';
import 'package:temporal_logic_mtl/temporal_logic_mtl.dart';

import 'stream_mtl_checker.dart'; // Import the redesigned checker

/// A widget that observes a [stream] of timed states [TimedValue<S>] and displays
/// whether an LTL/MTL [formula] holds true based on the observed trace.
///
/// Uses [StreamMtlChecker] internally and rebuilds when the formula's
/// truth value changes.
class MtlCheckerWidget<S> extends StatefulWidget {
  /// The stream of timed states to observe.
  final Stream<TimedValue<S>> stream;

  /// The LTL or MTL formula to check against the trace derived from the stream.
  final Formula<S> formula;

  /// An optional initial value for the state, used before the stream emits its first event.
  final TimedValue<S>? initialValue;

  /// A builder function to customize the widget displayed based on the evaluation result.
  ///
  /// Defaults to displaying a simple [Icon] (check_circle for true, cancel for false).
  final Widget Function(BuildContext context, bool result, EvaluationResult details)? builder;

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
  // Initialize with a Pending state
  EvaluationResult? _lastKnownResult = const EvaluationResult(false, reason: 'Initializing...');
  StreamSubscription<EvaluationResult>? _resultSubscription;

  @override
  void initState() {
    super.initState();
    _initializeChecker();
    // No synchronous check possible here, rely on stream emission
  }

  void _initializeChecker() {
    _checker = StreamMtlChecker<S>(
      widget.stream,
      formula: widget.formula,
      initialValue: widget.initialValue,
    );
    // Subscribe to the result stream to store the last known value
    _resultSubscription = _checker.resultStream.listen((result) {
      if (mounted) {
        // Check if widget is still in the tree
        setState(() {
          _lastKnownResult = result;
        });
      }
    }, onError: (e) {
      // Optionally handle stream errors
      if (mounted) {
        setState(() {
          _lastKnownResult = EvaluationResult(false, reason: 'Stream Error: $e');
        });
      }
    });
    // Don't try to access checker's internal state here.
  }

  @override
  void didUpdateWidget(covariant MtlCheckerWidget<S> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stream != oldWidget.stream ||
        widget.formula != oldWidget.formula ||
        widget.initialValue != oldWidget.initialValue) {
      _checker.dispose();
      _resultSubscription?.cancel(); // Cancel old subscription
      _initializeChecker();
    }
  }

  @override
  void dispose() {
    _resultSubscription?.cancel();
    _checker.dispose();
    super.dispose();
  }

  // Default builder implementation
  Widget _defaultBuilder(BuildContext context, bool result, EvaluationResult details) {
    return Tooltip(
      // Provide more details on hover if available
      message: details.reason ?? (result ? 'Formula holds' : 'Formula does not hold'),
      child: Icon(
        result ? Icons.check_circle : Icons.cancel,
        color: result ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<EvaluationResult>(
      stream: _checker.resultStream,
      // Use the stored _lastKnownResult (initially Pending) for initial data
      initialData: _lastKnownResult,
      builder: (context, snapshot) {
        // Use latest data from snapshot if available, otherwise use last known
        final evalResult = snapshot.hasData ? snapshot.data! : _lastKnownResult;

        // Handle case where evalResult is still null (shouldn't happen with init)
        final bool holds = evalResult?.holds ?? false;
        // Provide a default reason if details are missing
        final EvaluationResult details = evalResult ?? const EvaluationResult(false, reason: 'Waiting for stream...');

        final builder = widget.builder ?? _defaultBuilder;
        return builder(context, holds, details);
      },
    );
  }
}
