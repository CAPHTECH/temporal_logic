import 'dart:async';

import 'package:temporal_logic_mtl/temporal_logic_mtl.dart';
// import 'mtl_check_type.dart'; // No longer needed

/// Observes a stream of timed states and evaluates an LTL/MTL formula.
class StreamMtlChecker<S> {
  final Stream<TimedValue<S>> _stream;
  // Accept a full Formula<S> which can contain LTL and MTL operators
  final Formula<S> _formula;
  final List<TraceEvent<S>> _internalTraceEvents = []; // Store TraceEvents directly
  final TimedValue<S>? _initialValue;

  StreamSubscription<TimedValue<S>>? _subscription;
  // Use EvaluationResult to potentially provide more info later
  final _resultController = StreamController<EvaluationResult>.broadcast();
  // Remove _lastResult tracking for emission logic, maybe keep for optimization later
  // EvaluationResult _lastResult = const EvaluationResult(false, reason: 'Initial'); // Initial state

  /// Stream that emits the EvaluationResult of the LTL/MTL check.
  Stream<EvaluationResult> get resultStream => _resultController.stream;

  /// Creates a checker for a specific LTL/MTL [formula] on the [stream].
  StreamMtlChecker(
    this._stream, {
    required Formula<S> formula,
    TimedValue<S>? initialValue,
  })  : _formula = formula,
        _initialValue = initialValue {
    if (_initialValue != null) {
      // Convert initial TimedValue to TraceEvent
      _internalTraceEvents.add(TraceEvent(timestamp: _initialValue.timestamp, value: _initialValue.value));
    }
    // Evaluate the initial state based on _initialValue (if any)
    final initialResult = _evaluate();
    // Start listening *after* initial state is determined
    _startListening();
    // Schedule the emission of the initial result for the next event loop cycle
    scheduleMicrotask(() {
      if (!_resultController.isClosed) {
        _resultController.add(initialResult);
      }
    });
  }

  void _startListening() {
    _subscription?.cancel();
    _subscription = _stream.listen(
      (timedValue) {
        // Convert TimedValue to TraceEvent
        _internalTraceEvents.add(TraceEvent(timestamp: timedValue.timestamp, value: timedValue.value));
        // Simple approach: re-evaluate on every new event.
        _evaluateAndNotify();
      },
      onDone: () {
        // Optional: Final evaluation if needed, though last event should trigger it.
        // _evaluateAndNotify();
        if (!_resultController.isClosed) {
          _resultController.close(); // Close after potential last emit
        }
      },
      onError: (error) {
        if (!_resultController.isClosed) {
          _resultController.addError(error);
          _resultController.close();
        }
      },
    );
  }

  void _evaluateAndNotify() {
    // Evaluate the formula against the current trace
    final currentResult = _evaluate();
    // Always emit the current result
    if (!_resultController.isClosed) {
      _resultController.add(currentResult);
    }
    // Note: _lastResult is no longer used for emission logic.
  }

  /// Performs the actual LTL/MTL check using the integrated evaluator.
  EvaluationResult _evaluate() {
    // Create Trace from the list of TraceEvents
    final currentTrace = Trace(_internalTraceEvents);
    // Use the unified evaluator from the mtl package
    return evaluateMtlTrace(currentTrace, _formula);
  }

  /// Disposes the checker, cancelling subscriptions and closing streams.
  void dispose() {
    _subscription?.cancel();
    if (!_resultController.isClosed) {
      _resultController.close();
    }
    _internalTraceEvents.clear();
  }
}
