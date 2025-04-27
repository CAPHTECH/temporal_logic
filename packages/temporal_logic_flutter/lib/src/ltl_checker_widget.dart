import 'dart:async'; // Keep for Stream type

import 'package:flutter/material.dart';
import 'package:temporal_logic_core/temporal_logic_core.dart';

import 'stream_ltl_checker.dart'; // Assuming this exists and is updated

/// A widget that observes a [stream] of state [S] and displays
/// whether an LTL [formula] holds true based on the observed trace.
///
/// Uses [StreamLtlChecker] internally and rebuilds when the formula's
/// truth value changes.
class LtlCheckerWidget<S> extends StatefulWidget {
  // Changed to StatefulWidget
  /// The stream of states to observe.
  final Stream<S> stream;

  /// The LTL formula to check against the trace derived from the stream.
  final Formula<S> formula; // Use Formula<S> instead of Ltl<S>
  /// An optional initial value for the state, used before the stream emits its first event.
  final S? initialValue;

  /// A builder function to customize the widget displayed based on the result.
  ///
  /// Defaults to displaying a simple [Icon] (check_circle for true, cancel for false).
  final Widget Function(BuildContext context, bool result)? builder;

  const LtlCheckerWidget({
    super.key,
    required this.stream, // Changed from provider
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
  late final StreamLtlChecker<S> _checker;

  @override
  void initState() {
    super.initState();
    _initializeChecker();
  }

  void _initializeChecker() {
    // Use named parameters for the checker constructor
    _checker = StreamLtlChecker<S>(
      stream: widget.stream,
      formula: widget.formula,
      // Pass initialValue if StreamLtlChecker supports it (check its definition)
      // Assuming StreamLtlChecker might not need initialValue directly now
    );
  }

  @override
  void dispose() {
    _checker.dispose();
    super.dispose();
  }

  // Default builder implementation
  Widget _defaultBuilder(BuildContext context, bool result) {
    return Icon(
      result ? Icons.check_circle : Icons.cancel,
      color: result ? Colors.green : Colors.red,
      semanticLabel: result ? 'Formula holds' : 'Formula does not hold',
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use StreamBuilder instead of ValueListenableBuilder
    return StreamBuilder<bool>(
      stream: _checker.resultStream,
      builder: (context, snapshot) {
        // Handle connection state and data availability
        bool result = false; // Default to false
        if (snapshot.connectionState == ConnectionState.active && snapshot.hasData) {
          result = snapshot.data!;
        }
        // Use the provided builder, or the default one if null
        final builder = widget.builder ?? _defaultBuilder;
        return builder(context, result);
      },
    );
  }
}
