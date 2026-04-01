import 'dart:async';

import 'package:temporal_logic_core/temporal_logic_core.dart'; // Import core

import 'stream_evaluation_start.dart';

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
class StreamLtlChecker<S> {
  final Stream<S> _stream;
  final Formula<S> _formula; // Use Formula<S>
  final _trace = <S>[]; // Stores the history of states
  StreamSubscription<S>? _subscription;
  final _resultController = StreamController<bool>.broadcast();
  final S? _initialValue; // Optional initial state
  final StreamEvaluationStart _evaluationStart;

  /// A broadcast [Stream] emitting the boolean result of the LTL [formula]
  /// evaluation against the current trace.
  ///
  /// An initial result is emitted shortly after creation (based on the
  /// [initialValue] or empty trace). Subsequently, a new result is emitted
  /// every time a state arrives from the input [stream].
  Stream<bool> get resultStream => _resultController.stream;

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
  ///
  /// An initial evaluation is performed based on the trace containing only the
  /// [initialValue] (if provided) or an empty trace. This initial result is
  /// emitted on the [resultStream] via `scheduleMicrotask`.
  ///
  /// Subsequently, the [formula] is evaluated each time a new state arrives
  /// on the [stream], and the result is emitted on [resultStream].
  StreamLtlChecker({
    required Stream<S> stream,
    required Formula<S> formula, // Use Formula<S>
    S? initialValue,
    StreamEvaluationStart evaluationStart = StreamEvaluationStart.beginning,
  })  : _stream = stream,
        _formula = formula,
        _initialValue = initialValue,
        _evaluationStart = evaluationStart {
    if (_initialValue != null) {
      _trace.add(_initialValue);
    }
    // Evaluate the initial state (empty or with initialValue)
    final initialResult = check();
    // Start listening *after* initial state is determined
    _startListening();
    // Schedule the emission of the initial result for the next event loop cycle
    scheduleMicrotask(() {
      if (!_resultController.isClosed) {
        _resultController.add(initialResult);
      }
    });
  }

  /// Starts listening to the stream.
  ///
  /// Initializes the stream subscription and handles incoming events,
  /// completion, and errors.
  void _startListening() {
    _subscription?.cancel(); // Cancel previous subscription if any
    _subscription = _stream.listen(
      (newState) {
        _trace.add(newState);
        // Evaluate and emit on every new state.
        _evaluateAndNotify();
      },
      onDone: () {
        // Close the controller when the input stream is done.
        if (!_resultController.isClosed) {
          _resultController.close();
        }
      },
      onError: (error) {
        // Forward errors to the result stream and close it.
        if (!_resultController.isClosed) {
          _resultController.addError(error);
          _resultController.close();
        }
      },
    );
  }

  // Helper function to evaluate and emit result if necessary
  /// Evaluates the formula and emits the result on the stream controller.
  void _evaluateAndNotify() {
    // Evaluate the formula against the current trace
    final newResult = check();
    // Always emit the current result
    if (!_resultController.isClosed) {
      _resultController.add(newResult);
    }
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
    if (_trace.isEmpty) {
      final tempTrace = Trace<S>.empty();
      return evaluateTrace(tempTrace, _formula).holds;
    }
    final timedTrace = Trace<S>.fromList(_trace);
    final startIndex = _evaluationStart.resolveStartIndex(_trace.length);
    final result = evaluateTrace(timedTrace, _formula, startIndex: startIndex);
    return result.holds;
  }

  /// Cancels all subscriptions, timers, and closes the result stream.
  /// Clears the internal trace to free memory. After disposal, no further
  /// results will be emitted.
  void dispose() {
    _subscription?.cancel();
    if (!_resultController.isClosed) {
      _resultController.close();
    }
    _trace.clear();
  }
}
