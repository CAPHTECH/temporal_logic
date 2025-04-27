import 'dart:async';

import 'package:flutter/foundation.dart' show ValueNotifier, ValueListenable;
// Use EvaluationResult for detailed info, but CheckStatus for simple status
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
  Timer? _sustainTimer;
  DateTime? _targetStateEnteredTime; // Wall-clock time tracking

  ValueListenable<CheckStatus> get resultListenable => _resultNotifier;

  StreamSustainedStateChecker(
    this._stream, {
    required S targetState,
    required Duration sustainDuration,
    TimedValue<S>? initialValue,
  })  : _targetState = targetState,
        _sustainDuration = sustainDuration,
        _initialValue = initialValue {
    print(
        'State Sustained Check [Constructor]: Initializing. Target=$_targetState, Sustain=$_sustainDuration, Initial=$_initialValue');
    // Initialize state based on initialValue, then start listening
    if (_initialValue != null) {
      print('State Sustained Check [Constructor]: Processing initial value.');
      _handleStateChange(_initialValue, isInitial: true);
    } else {
      // No initial value, default to pending?
      print('State Sustained Check [Constructor]: No initial value, defaulting status to pending.');
      _setResult(CheckStatus.pending); // Or failure? Let's try pending.
    }
    print('State Sustained Check [Constructor]: Initial status set to ${_resultNotifier.value}. Starting listener.');
    _listen(); // Start listening to the stream
  }

  void _listen() {
    _subscription?.cancel();
    _subscription = _stream.listen(
      // Pass isInitial: false for subsequent updates
      (timedValue) => _handleStateChange(timedValue, isInitial: false),
      onDone: () {
        if (_resultNotifier.value == CheckStatus.pending) {
          print('State Sustained Check: Stream ended while pending. Failure!');
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
    final currentTime = DateTime.now();

    print(
        'State Sustained Check: Handling state change. New state: $newState, Is initial: $isInitial, Current Status: ${_resultNotifier.value}');
    if (isInitial) {
      print('State Sustained Check [Initial]: Processing initial value: $newState');
    }

    if (newState == _targetState) {
      // Entered or stayed in target state
      if (_targetStateEnteredTime == null || _resultNotifier.value == CheckStatus.failure) {
        // Start/Restart timer if not already running or if recovering from failure
        print('State Sustained Check: Entered/Re-entered target state. Starting timer.');
        _targetStateEnteredTime = currentTime;
        _setResult(CheckStatus.pending);
        _sustainTimer?.cancel();
        _sustainTimer = Timer(_sustainDuration, () {
          print('State Sustained Check: Timer complete.');
          // Timer completed, check if we are *still* in the target state implicitly
          // and if the status was still pending.
          if (_resultNotifier.value == CheckStatus.pending && _targetStateEnteredTime != null) {
            print('State Sustained Check: Setting to Success!');
            _setResult(CheckStatus.success);
            // Keep _targetStateEnteredTime, status is now Success until exited
          }
        });
      } else if (_resultNotifier.value == CheckStatus.success) {
        // Already succeeded, do nothing, stay success.
        print('State Sustained Check: Already in success state.');
      }
      // If pending and already tracking (_targetStateEnteredTime != null), let timer run.
    } else {
      // Left target state (newState != _targetState)
      if (_targetStateEnteredTime != null) {
        // We were previously in the target state
        print('State Sustained Check: Left target state.');
        _sustainTimer?.cancel(); // Stop timer regardless of status
        if (_resultNotifier.value == CheckStatus.pending) {
          // Was pending but left too early
          print('State Sustained Check: Left before timer complete. Failure!');
          _setResult(CheckStatus.failure);
        } else if (_resultNotifier.value == CheckStatus.success) {
          // Was success, but now left. Transition to failure.
          print('State Sustained Check: Left after success. Setting to Failure!');
          _setResult(CheckStatus.failure);
        }
        // If already failure, leaving doesn't change it.
        _targetStateEnteredTime = null; // Reset entry time
      } else {
        // Not in target state, and wasn't tracking entry time.
        // If initial state is not target, set to failure. Otherwise, should be pending/success/failure already.
        if (isInitial) {
          print(
              'State Sustained Check [Initial]: Initial state $newState is not target state $_targetState. Setting Failure!');
          _setResult(CheckStatus.failure);
        }
      }
    }
  }

  // Helper to prevent redundant notifications
  void _setResult(CheckStatus newStatus) {
    if (_resultNotifier.value != newStatus) {
      print('State Sustained Check: Updating status from ${_resultNotifier.value} to $newStatus');
      _resultNotifier.value = newStatus;
    } else {
      print('State Sustained Check: Status remains $newStatus');
    }
  }

  void _handleError() {
    print('State Sustained Check: Error in stream.');
    _setResult(CheckStatus.failure);
    _resetTimerAndState();
  }

  void _resetTimerAndState() {
    _sustainTimer?.cancel();
    _sustainTimer = null;
    _targetStateEnteredTime = null;
  }

  void dispose() {
    print('Disposing StreamSustainedStateChecker');
    _subscription?.cancel();
    _resetTimerAndState();
    _resultNotifier.dispose();
  }
}
