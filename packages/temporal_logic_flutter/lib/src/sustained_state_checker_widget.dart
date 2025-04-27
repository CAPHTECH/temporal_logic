import 'package:flutter/material.dart';
import 'package:temporal_logic_core/temporal_logic_core.dart' show TimedValue;
import 'stream_sustained_state_checker.dart';
import 'check_status.dart';

/// A widget that observes a [stream] of timed states [TimedValue<S>] and
/// displays the result of checking if a [targetState] is sustained for a
/// given [sustainDuration] once entered.
///
/// Uses [StreamSustainedStateChecker] internally and rebuilds when the check's
/// truth value ([CheckStatus]) changes.
class SustainedStateCheckerWidget<S> extends StatefulWidget {
  final Stream<TimedValue<S>> stream;
  final S targetState;
  final Duration sustainDuration;
  final TimedValue<S>? initialValue;
  final Widget Function(BuildContext context, CheckStatus result)? builder;

  const SustainedStateCheckerWidget({
    super.key,
    required this.stream,
    required this.targetState,
    required this.sustainDuration,
    this.initialValue,
    this.builder,
  });

  @override
  State<SustainedStateCheckerWidget<S>> createState() =>
      _SustainedStateCheckerWidgetState<S>();
}

class _SustainedStateCheckerWidgetState<S>
    extends State<SustainedStateCheckerWidget<S>> {
  late StreamSustainedStateChecker<S> _checker;

  @override
  void initState() {
    super.initState();
    _initializeChecker();
  }

  void _initializeChecker() {
    _checker = StreamSustainedStateChecker<S>(
      widget.stream,
      targetState: widget.targetState,
      sustainDuration: widget.sustainDuration,
      initialValue: widget.initialValue,
    );
  }

  @override
  void didUpdateWidget(covariant SustainedStateCheckerWidget<S> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stream != oldWidget.stream ||
        widget.targetState != oldWidget.targetState ||
        widget.sustainDuration != oldWidget.sustainDuration ||
        widget.initialValue != oldWidget.initialValue) {
      _checker.dispose();
      _initializeChecker();
    }
  }

  @override
  void dispose() {
    _checker.dispose();
    super.dispose();
  }

  // Default builder updated to use CheckStatus
  Widget _defaultBuilder(BuildContext context, CheckStatus result) {
    IconData icon;
    Color color;
    String tooltip;
    switch (result) {
      case CheckStatus.success:
        icon = Icons.check_circle;
        color = Colors.green;
        tooltip = 'State Sustained';
        break;
      case CheckStatus.failure:
        icon = Icons.cancel;
        color = Colors.red;
        tooltip = 'State Not Sustained';
        break;
      case CheckStatus.pending:
      default: // Treat pending and unknown the same for icon
        icon = Icons.hourglass_empty;
        color = Colors.orange;
        tooltip = 'Sustained Check Pending';
        break;
    }
    return Tooltip(
      message: tooltip,
      child: Icon(icon, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Update ValueListenableBuilder type parameter
    return ValueListenableBuilder<CheckStatus>(
      valueListenable: _checker.resultListenable,
      builder: (context, result, _) {
        final builder = widget.builder ?? _defaultBuilder;
        return builder(context, result);
      },
    );
  }
}
