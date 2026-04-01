import 'dart:async';

import 'package:temporal_logic_mtl/temporal_logic_mtl.dart';

import 'stream_evaluation_start.dart';

/// Provides periodic evaluation of a temporal logic [Formula]<S> (LTL/MTL)
/// against a stream of time-stamped values. Incoming events are accumulated
/// into an internal trace and evaluated on every new event.
///
/// Type parameter [S] defines the type of the state values in the trace.
class StreamMtlChecker<S> {
  final Stream<TimedValue<S>> _stream;
  // Accept a full Formula<S> which can contain LTL and MTL operators
  final Formula<S> _formula;
  final List<TraceEvent<S>> _internalTraceEvents =
      []; // Store TraceEvents directly
  final TimedValue<S>? _initialValue;
  final StreamEvaluationStart _evaluationStart;

  StreamSubscription<TimedValue<S>>? _subscription;
  // Use EvaluationResult to potentially provide more info later
  final _resultController = StreamController<EvaluationResult>.broadcast();

  /// A broadcast [Stream] emitting the [EvaluationResult] whenever
  /// the temporal logic [formula] is evaluated against the current trace,
  /// including an initial evaluation and on each new incoming event.
  Stream<EvaluationResult> get resultStream => _resultController.stream;

  /// Creates a [StreamMtlChecker] that listens to the specified [stream] of
  /// timed states and evaluates the given [formula]. If [initialValue] is
  /// provided, it is used as the first trace event before any stream emissions.
  /// Evaluation occurs on each new event and immediately for the initial value.
  StreamMtlChecker(
    this._stream, {
    required Formula<S> formula,
    TimedValue<S>? initialValue,
    StreamEvaluationStart evaluationStart = StreamEvaluationStart.beginning,
  })  : _formula = formula,
        _initialValue = initialValue,
        _evaluationStart = evaluationStart {
    if (_initialValue != null) {
      // Convert initial TimedValue to TraceEvent
      _internalTraceEvents.add(TraceEvent(
          timestamp: _initialValue.timestamp, value: _initialValue.value));
    }
    Object? initialError;
    StackTrace? initialStackTrace;
    EvaluationResult? initialResult;

    try {
      initialResult = _evaluate();
    } catch (error, stackTrace) {
      initialError = error;
      initialStackTrace = stackTrace;
    }

    // Start listening *after* initial state is determined
    _startListening();
    // Schedule the emission of the initial result for the next event loop cycle
    scheduleMicrotask(() {
      if (!_resultController.isClosed) {
        if (initialError != null) {
          _publishErrorAndClose(initialError!, initialStackTrace);
          return;
        }
        _resultController.add(initialResult!);
      }
    });
  }

  void _startListening() {
    _subscription?.cancel();
    _subscription = _stream.listen(
      (timedValue) {
        // Convert TimedValue to TraceEvent
        _internalTraceEvents.add(TraceEvent(
            timestamp: timedValue.timestamp, value: timedValue.value));
        try {
          _evaluateAndNotify();
        } catch (error, stackTrace) {
          _publishErrorAndClose(error, stackTrace);
        }
      },
      onDone: () {
        if (!_resultController.isClosed) {
          _resultController.close(); // Close after potential last emit
        }
      },
      onError: (error, stackTrace) {
        _publishErrorAndClose(error, stackTrace);
      },
    );
  }

  void _publishErrorAndClose(Object error, [StackTrace? stackTrace]) {
    _subscription?.cancel();
    if (_resultController.isClosed) {
      return;
    }
    _resultController.addError(error, stackTrace);
    _resultController.close();
  }

  void _evaluateAndNotify() {
    // Evaluate the formula against the current trace
    final currentResult = _evaluate();
    // Always emit the current result
    if (!_resultController.isClosed) {
      _resultController.add(currentResult);
    }
  }

  /// Performs the actual LTL/MTL check using the integrated evaluator.
  EvaluationResult _evaluate() {
    // Create Trace from the list of TraceEvents
    final currentTrace = Trace(_internalTraceEvents);
    // Use the unified evaluator from the mtl package
    return evaluateMtlTrace(
      currentTrace,
      _formula,
      startIndex: _evaluationStart.resolveStartIndex(currentTrace.length),
    );
  }

  /// Disposes the checker by cancelling the stream subscription, closing
  /// the [resultStream], and clearing all internal trace events.
  /// After disposal, no further results will be emitted.
  void dispose() {
    _subscription?.cancel();
    if (!_resultController.isClosed) {
      _resultController.close();
    }
    _internalTraceEvents.clear();
  }
}
