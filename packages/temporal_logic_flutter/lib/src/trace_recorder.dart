import 'package:clock/clock.dart';
import 'package:temporal_logic_core/temporal_logic_core.dart';

/// Records a sequence of state changes over time to produce a [Trace].
///
/// This recorder is designed to be driven by the application or test framework,
/// explicitly calling [record] when the state changes.
class TraceRecorder<T> {
  final List<TraceEvent<T>> _events = [];
  DateTime? _startTime;
  final Clock _clock;

  /// The interval used for interpreting the trace, potentially by evaluation logic.
  /// This recorder itself does not sample periodically; recording is manual via [record].
  final Duration interval;

  /// The recorded sequence of events.
  Trace<T> get trace => Trace(_events);

  /// Creates a recorder.
  ///
  /// The [interval] might be used by the underlying temporal logic evaluation
  /// to determine the time granularity or semantics.
  /// Optionally accepts a [Clock] instance, defaulting to the system clock.
  TraceRecorder({
    this.interval = const Duration(milliseconds: 100),
    Clock? clock,
  }) : _clock = clock ?? const Clock();

  /// Initializes the recorder, marking the start time using the provided clock
  /// and clearing previous events.
  /// Must be called before the first call to [record].
  void initialize() {
    _startTime = _clock.now();
    _events.clear();
  }

  /// Records the current state [T] at the current time (from the clock) relative to [initialize].
  ///
  /// Throws a [StateError] if [initialize] has not been called.
  ///
  /// Optimization: By default, only adds an event if the state is different
  /// from the last recorded state, creating a trace of state *changes*.
  /// Set [recordDuplicates] to true to record every call, even if the state is the same.
  void record(T state, {bool recordDuplicates = false}) {
    if (_startTime == null) {
      throw StateError(
          'TraceRecorder must be initialized before recording. Call initialize().');
    }
    final now = _clock.now();
    final timestamp = now.difference(_startTime!);

    if (recordDuplicates || _events.isEmpty || _events.last.value != state) {
      _events.add(TraceEvent(timestamp: timestamp, value: state));
    }
  }
}
