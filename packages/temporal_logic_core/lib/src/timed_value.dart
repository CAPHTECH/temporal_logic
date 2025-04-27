import 'package:meta/meta.dart';

/// Represents a value associated with a specific point in time ([timestamp]).
///
/// This class encapsulates a data point [value] of type [T] and the [Duration]
/// ([timestamp]) at which it was recorded or became valid. It serves as a basic
/// building block for time-series data.
///
/// While similar in structure to [TraceEvent], [TimedValue] is intended for more
/// general use cases where a value-timestamp pair is needed without the context
/// or constraints of being part of a formal [Trace] (like strict timestamp
/// monotonicity).
///
/// The [timestamp] typically represents the duration since a reference point or
/// epoch (e.g., application start, simulation start).
///
/// This class is immutable.
@immutable
class TimedValue<T> {
  /// The value recorded at the timestamp.
  final T value;

  /// The time at which the value was recorded or became valid.
  final Duration timestamp;

  /// Creates an immutable [TimedValue] instance.
  ///
  /// - [value]: The data value.
  /// - [timestamp]: The duration associated with the value.
  const TimedValue(this.value, this.timestamp);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimedValue<T> &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(value, timestamp); // Use Object.hash for better hash distribution

  /// Provides a compact string representation, e.g., `(value @ 123ms)` or `(value @ 1.5s)`.
  @override
  String toString() {
    // Format timestamp concisely (e.g., 100ms, 1.5s)
    String formatDuration(Duration d) {
      if (d.inMilliseconds < 0) return '?ms'; // Handle negative durations
      if (d.inMilliseconds < 1000) {
        return '${d.inMilliseconds}ms';
      }
      if (d.inMilliseconds % 1000 == 0) {
        return '${d.inSeconds}s'; // Whole seconds
      }
      return '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s'; // Seconds with one decimal place
    }

    return '($value @ ${formatDuration(timestamp)})';
  }
}

/// Represents a single event or state observation within a [Trace].
///
/// A [Trace] is composed of a sequence of [TraceEvent]s. Each event captures
/// the state ([value]) of a system at a specific point in time ([timestamp])
/// relative to the start of the trace.
///
/// **Key properties:**
/// - **Immutability:** TraceEvents are immutable.
/// - **Monotonic Timestamps:** Within a valid [Trace], events must be ordered
///   by non-decreasing timestamps.
///
/// Use [TraceEvent] when building or representing the history of a system's
/// evolution over time for evaluation against temporal logic formulas.
///
/// See also:
/// - [Trace], the container for a sequence of TraceEvents.
/// - [TimedValue], a similar but more general-purpose value-timestamp pair.
@immutable
class TraceEvent<T> {
  /// The time elapsed since the beginning of the trace when this event occurred.
  /// Timestamps within a [Trace] must be monotonically non-decreasing.
  final Duration timestamp;

  /// The state value recorded at this [timestamp].
  final T value;

  /// Creates an immutable trace event.
  ///
  /// - [timestamp]: The non-negative time offset from the trace start.
  /// - [value]: The state observed at the given [timestamp].
  const TraceEvent({required this.timestamp, required this.value});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TraceEvent<T> &&
          runtimeType == other.runtimeType &&
          timestamp == other.timestamp &&
          value == other.value;

  @override
  int get hashCode => Object.hash(timestamp, value); // Use Object.hash

  /// Provides a simple string representation, e.g., `value @ 123ms`.
  /// Note: For more formatting options, consider accessing `timestamp` directly.
  @override
  String toString() => '$value @ ${timestamp.inMilliseconds}ms';
}

/// Represents an immutable, ordered sequence of time-stamped events ([TraceEvent]).
///
/// This is the fundamental data structure against which temporal logic formulas
/// ([Formula]) are evaluated. It captures the evolution of a system's state [T]
/// over time.
///
/// **Core Properties:**
/// - **Immutability:** Once created, a Trace cannot be modified. Operations
///   that seem to modify a trace typically return a new `Trace` instance.
/// - **Monotonic Timestamps:** The `events` list is guaranteed to have timestamps
///   that are monotonically non-decreasing
///   (i.e., `events[i+1].timestamp >= events[i].timestamp` for all valid `i`).
///   This property is crucial for the semantics of most temporal logics and is
///   enforced by an assertion in the default constructor (in debug mode).
///
/// Traces are used by evaluator functions (like those potentially found in
/// `evaluator.dart` or specific logic packages like `temporal_logic_mtl`) to
/// determine the truth value of a [Formula] over the recorded behavior.
///
/// See also:
/// - [TraceEvent], the individual elements comprising a trace.
/// - [Formula], the logical specifications evaluated over traces.
/// - `evaluateTrace` (in `evaluator.dart`), the typical function for evaluation.
@immutable
class Trace<T> {
  /// The ordered, unmodifiable sequence of timed events comprising this trace.
  final List<TraceEvent<T>> events;

  /// Creates a trace from a given list of [TraceEvent]s.
  ///
  /// The provided [events] list is copied into an internal, unmodifiable list.
  ///
  /// **Important:** This constructor asserts (in debug mode) that the timestamps
  /// in the provided [events] list are monotonically non-decreasing. Providing
  /// out-of-order events may lead to unexpected behavior or errors during
  /// evaluation if assertions are disabled.
  ///
  /// - Parameter [events]: The list of trace events, expected to be sorted by
  ///   non-decreasing timestamp.
  Trace(List<TraceEvent<T>> events) : events = List.unmodifiable(events) {
    // Assert for monotonic timestamps in development/debug mode.
    // This helps catch logical errors early during trace construction.
    assert(() {
      if (this.events.length > 1) {
        for (int i = 1; i < this.events.length; i++) {
          final prev = this.events[i - 1];
          final curr = this.events[i];
          if (curr.timestamp < prev.timestamp) {
            // Provide a more informative error message.
            throw ArgumentError.value(
              events,
              'events',
              'Timestamps must be monotonically non-decreasing. ' +
                  'Violation at index $i: ' +
                  'Previous=${prev.timestamp} (${prev.value}), ' +
                  'Current=${curr.timestamp} (${curr.value})',
            );
          }
        }
      }
      return true;
    }());
  }

  /// Creates an empty trace with no events.
  /// Useful as a base case or initial value.
  Trace.empty() : events = const [];

  /// Creates a Trace from a simple list of state values, assigning timestamps
  /// automatically with a fixed interval.
  ///
  /// This factory is convenient for creating simple traces for testing or for
  /// evaluating pure LTL formulas where only the sequence and relative order
  /// matter, and absolute time is less critical.
  ///
  /// Each element in the [values] list becomes a [TraceEvent]. The timestamp for
  /// the element at index `i` is calculated as `interval * i`.
  ///
  /// Example:
  /// ```dart
  /// final trace = Trace.fromList(['a', 'b', 'c']);
  /// // Results in: Trace(a @ 0ms, b @ 1ms, c @ 2ms)
  ///
  /// final traceWithSteps = Trace.fromList([10, 20], interval: Duration(seconds: 1));
  /// // Results in: Trace(10 @ 0ms, 20 @ 1000ms)
  /// ```
  ///
  /// - [values]: The ordered list of state values.
  /// - [interval]: The non-negative time difference between consecutive events.
  ///   Defaults to 1 millisecond. Must not be negative.
  ///
  /// Throws [ArgumentError] if [interval] is negative.
  factory Trace.fromList(List<T> values, {Duration interval = const Duration(milliseconds: 1)}) {
    final traceEvents = <TraceEvent<T>>[];
    if (interval.isNegative) {
      throw ArgumentError.value(interval, 'interval', 'Interval cannot be negative.');
    }
    for (int i = 0; i < values.length; i++) {
      traceEvents.add(TraceEvent(timestamp: interval * i, value: values[i]));
    }
    return Trace(traceEvents); // Uses the default constructor for validation
  }

  /// Returns `true` if the trace contains no events.
  bool get isEmpty => events.isEmpty;

  /// Returns the number of events (time points) in the trace.
  int get length => events.length;

  /// Provides a string representation showing the sequence of events in the trace.
  /// Example: `Trace(StateA @ 0ms, StateB @ 150ms, StateC @ 500ms)`
  @override
  String toString() => 'Trace(${events.join(', ')})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Trace<T> &&
          runtimeType == other.runtimeType &&
          _listEquals(events, other.events); // Use listEquals from foundation

  @override
  int get hashCode => Object.hashAll(events);

  // Helper for deep list comparison.
  // Compares two lists element by element for equality.
  // Considers null lists and different lengths.
  // Note: For production, prefer using listEquals from package:collection
  // or package:flutter/foundation.dart for robustness.
  bool _listEquals<E>(List<E>? a, List<E>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    if (identical(a, b)) return true; // Optimization
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
