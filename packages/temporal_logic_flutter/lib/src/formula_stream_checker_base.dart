import 'dart:async';

import 'package:meta/meta.dart';

/// Shared stream-checker lifecycle for temporal logic checkers.
///
/// Subclasses own the trace representation and evaluation logic. This base class
/// centralizes initial evaluation, event subscription, error forwarding, and
/// disposal so LTL and MTL checkers keep the same runtime behavior.
@internal
abstract class FormulaStreamCheckerBase<I, R> {
  FormulaStreamCheckerBase(this._stream);

  final Stream<I> _stream;
  final _resultController = StreamController<R>.broadcast();
  StreamSubscription<I>? _subscription;

  Stream<R> get resultStream => _resultController.stream;

  @protected
  void initializeWithInitialEvaluation(R Function() evaluateInitial) {
    Object? initialError;
    StackTrace? initialStackTrace;
    late final R initialResult;
    var hasInitialResult = false;

    try {
      initialResult = evaluateInitial();
      hasInitialResult = true;
    } catch (error, stackTrace) {
      initialError = error;
      initialStackTrace = stackTrace;
    }

    _startListening();
    scheduleMicrotask(() {
      if (_resultController.isClosed) {
        return;
      }
      final error = initialError;
      if (error != null) {
        publishErrorAndClose(error, initialStackTrace);
        return;
      }
      if (hasInitialResult) {
        _resultController.add(initialResult);
      }
    });
  }

  void _startListening() {
    _subscription?.cancel();
    _subscription = _stream.listen(
      (input) {
        try {
          onInput(input);
          emitResult(evaluateCurrent());
        } catch (error, stackTrace) {
          publishErrorAndClose(error, stackTrace);
        }
      },
      onDone: onSourceDone,
      onError: (Object error, StackTrace stackTrace) {
        publishErrorAndClose(error, stackTrace);
      },
    );
  }

  @protected
  void onInput(I input);

  @protected
  R evaluateCurrent();

  @protected
  void onSourceDone() {
    closeResultStream();
  }

  @protected
  void emitResult(R result) {
    if (!_resultController.isClosed) {
      _resultController.add(result);
    }
  }

  @protected
  void closeResultStream() {
    if (!_resultController.isClosed) {
      _resultController.close();
    }
  }

  @protected
  void publishErrorAndClose(Object error, [StackTrace? stackTrace]) {
    _subscription?.cancel();
    if (_resultController.isClosed) {
      return;
    }
    _resultController.addError(error, stackTrace);
    _resultController.close();
  }

  @mustCallSuper
  void dispose() {
    _subscription?.cancel();
    closeResultStream();
  }
}
