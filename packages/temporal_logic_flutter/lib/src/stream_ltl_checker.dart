import 'dart:async';
import 'package:temporal_logic_core/temporal_logic_core.dart'; // Import core
import 'package:flutter/foundation.dart' show ValueNotifier, ValueListenable;

/// Periodically checks an LTL formula against a stream of states.
class StreamLtlChecker<S> {
  final Stream<S> _stream;
  final Formula<S> _formula; // Use Formula<S>
  final Duration _checkInterval;
  final _trace = <S>[]; // Stores the history of states
  StreamSubscription<S>? _subscription;
  Timer? _timer;
  final _resultController = StreamController<bool>.broadcast();
  bool _lastResult = false; // Cache the last result
  bool _initialCheckDone = false; // Flag for initial emission

  /// Stream that emits the boolean result of the LTL check periodically.
  Stream<bool> get resultStream => _resultController.stream;

  /// Creates a checker for the given [stream] and LTL [formula].
  ///
  /// [checkInterval] determines how often the formula is evaluated against
  /// the accumulated trace.
  StreamLtlChecker({
    required Stream<S> stream,
    required Formula<S> formula, // Use Formula<S>
    Duration checkInterval = const Duration(milliseconds: 100),
  })  : _stream = stream,
        _formula = formula,
        _checkInterval = checkInterval {
    _startListening();
  }

  /// Starts listening to the stream.
  void _startListening() {
    _subscription?.cancel(); // Cancel previous subscription if any
    _subscription = _stream.listen(
      (newState) {
        _trace.add(newState);
        _evaluateAndNotify();
      },
      onDone: () {
        // Handle stream completion if needed
      },
      onError: (error) {
        // Handle stream error if needed
      },
    );
    _timer = Timer.periodic(_checkInterval, (_) {
      _evaluateAndNotify();
    });
  }

  // Helper function to evaluate and emit result if necessary
  void _evaluateAndNotify() {
    final newResult = check();
    if (!_initialCheckDone) {
      _lastResult = newResult;
      _resultController.add(newResult);
      _initialCheckDone = true;
    } else if (_lastResult != newResult) {
      _lastResult = newResult;
      _resultController.add(newResult);
    }
  }

  /// Evaluates the LTL formula on the current trace.
  ///
  /// Returns `false` if the trace is empty.
  bool check() {
    // Use the dedicated LTL evaluation function from core
    return evaluateLtl(_formula, _trace);
  }

  /// Cancels the stream subscription and disposes the notifier.
  /// Call this when the checker is no longer needed to prevent memory leaks.
  void dispose() {
    _subscription?.cancel();
    _timer?.cancel();
    _resultController.close(); // Close the controller
    _trace.clear();
  }
} 
