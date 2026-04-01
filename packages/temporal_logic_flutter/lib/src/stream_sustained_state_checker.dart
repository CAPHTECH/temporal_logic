import 'dart:async';

import 'package:flutter/foundation.dart' show ValueNotifier, ValueListenable;
import 'package:temporal_logic_core/temporal_logic_core.dart' show TimedValue;

import 'check_status.dart'; // Import the new enum

/// Observes a stream of timed states [TimedValue<S>] and checks if a specific
/// [targetState] is sustained for a given [sustainDuration] once entered.
///
/// Uses event timestamps for duration checks, not wall-clock time.
/// Provides a [ValueListenable] to notify listeners about changes
/// in the check's truth value ([CheckStatus]).
class StreamSustainedStateChecker<S> {
  final Stream<TimedValue<S>> _stream;
  final S _targetState;
  final Duration _sustainDuration;
  final TimedValue<S>? _initialValue;

  final _resultNotifier = ValueNotifier<CheckStatus>(CheckStatus.pending);
  StreamSubscription<TimedValue<S>>? _subscription;
  Duration? _targetStateEnteredTimestamp;

  ValueListenable<CheckStatus> get resultListenable => _resultNotifier;

  StreamSustainedStateChecker(
    this._stream, {
    required S targetState,
    required Duration sustainDuration,
    TimedValue<S>? initialValue,
  })  : _targetState = targetState,
        _sustainDuration = sustainDuration,
        _initialValue = initialValue {
    // Initialize state based on initialValue, then start listening
    if (_initialValue != null) {
      _handleStateChange(_initialValue, isInitial: true);
    } else {
      // No initial value, default to pending?
      _setResult(CheckStatus.pending); // Or failure? Let's try pending.
    }
    _listen(); // Start listening to the stream
  }

  void _listen() {
    _subscription?.cancel();
    _subscription = _stream.listen(
      // Pass isInitial: false for subsequent updates
      (timedValue) => _handleStateChange(timedValue, isInitial: false),
      onDone: () {
        if (_resultNotifier.value == CheckStatus.pending) {
          _setResult(CheckStatus.failure);
        }
      },
      onError: (e) {
        _handleError();
      },
    );
  }

  // Unified state handling logic
  void _handleStateChange(TimedValue<S> timedValue, {required bool isInitial}) {
    final newState = timedValue.value;
    final currentTimestamp = timedValue.timestamp;

    if (newState == _targetState) {
      if (_targetStateEnteredTimestamp == null ||
          _resultNotifier.value == CheckStatus.failure) {
        _targetStateEnteredTimestamp = currentTimestamp;
        _setResult(CheckStatus.pending);
      }

      if (_targetStateEnteredTimestamp != null &&
          currentTimestamp - _targetStateEnteredTimestamp! >=
              _sustainDuration) {
        _setResult(CheckStatus.success);
      }
      return;
    } else {
      if (_targetStateEnteredTimestamp != null) {
        _setResult(CheckStatus.failure);
        _targetStateEnteredTimestamp = null;
      } else {
        if (isInitial) {
          _setResult(CheckStatus.failure);
        }
      }
    }
  }

  // Helper to prevent redundant notifications
  void _setResult(CheckStatus newStatus) {
    if (_resultNotifier.value != newStatus) {
      _resultNotifier.value = newStatus;
    } else {}
  }

  void _handleError() {
    _setResult(CheckStatus.failure);
    _resetState();
  }

  void _resetState() {
    _targetStateEnteredTimestamp = null;
  }

  void dispose() {
    _subscription?.cancel();
    _resetState();
    _resultNotifier.dispose();
  }
}
