import 'package:meta/meta.dart';

/// Represents a value [value] associated with a specific point in time [timestamp].
///
/// The [timestamp] typically represents the duration since a reference epoch
/// (e.g., application start).
class TimedValue<T> {
  /// The value recorded at the timestamp.
  final T value;

  /// The time at which the value was recorded.
  final Duration timestamp;

  const TimedValue(this.value, this.timestamp);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimedValue<T> &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          timestamp == other.timestamp;

  @override
  int get hashCode => value.hashCode ^ timestamp.hashCode;

  @override
  String toString() {
    // Format timestamp concisely (e.g., 100ms, 1.5s)
    String formatDuration(Duration d) {
      // Keep milliseconds if < 1000 or exactly 1000
      if (d.inMilliseconds <= 1000) {
        return '${d.inMilliseconds}ms';
      }
      // Add more formatting if needed, e.g., for minutes/hours
      return '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s';
    }

    return '($value @ ${formatDuration(timestamp)})';
  }
}

/// Represents a value associated with a specific point in time.
///
/// Used by [Trace] to store the sequence of states/events with their timestamps.
@immutable
class TraceEvent<T> {
  /// The time elapsed since the start of the trace recording.
  final Duration timestamp;

  /// The state or event value at this time point.
  final T value;

  const TraceEvent({required this.timestamp, required this.value});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TraceEvent<T> &&
          runtimeType == other.runtimeType &&
          timestamp == other.timestamp &&
          value == other.value;

  @override
  int get hashCode => timestamp.hashCode ^ value.hashCode;

  @override
  String toString() => '$value @ ${timestamp.inMilliseconds}ms';
}

/// Represents a sequence of time-stamped events or states.
///
/// This is the primary input for evaluating temporal logic formulas,
/// especially Metric Temporal Logic (MTL) formulas that depend on
/// precise timing.
@immutable
class Trace<T> {
  /// The sequence of timed events.
  final List<TraceEvent<T>> events;

  /// Creates a trace from a list of events.
  /// The provided list is copied into an unmodifiable list to ensure immutability.
  /// Also ensures that the timestamps are monotonically non-decreasing.
  Trace(List<TraceEvent<T>> events) : events = List.unmodifiable(events) {
    // Add assertion for monotonic timestamps
    if (this.events.length > 1) {
      for (int i = 1; i < this.events.length; i++) {
        assert(this.events[i].timestamp >= this.events[i - 1].timestamp,
            'Timestamps must be monotonically non-decreasing. Failed at index $i: ${this.events[i - 1].timestamp} -> ${this.events[i].timestamp}');
      }
    }
  }

  /// Creates an empty trace.
  Trace.empty() : events = const [];

  /// Creates a Trace from a simple list of values, assigning index-based timestamps.
  ///
  /// Each element in the [values] list becomes a [TraceEvent] where the
  /// timestamp corresponds to its index (0, 1, 2, ...), scaled by a default
  /// or provided [interval]. This is useful for simple LTL evaluation where
  /// only the sequence matters, or for testing purposes.
  ///
  /// The default [interval] is 1 millisecond, meaning timestamps will be
  /// 0ms, 1ms, 2ms, etc.
  factory Trace.fromList(List<T> values, {Duration interval = const Duration(milliseconds: 1)}) {
    final traceEvents = <TraceEvent<T>>[];
    for (int i = 0; i < values.length; i++) {
      traceEvents.add(TraceEvent(timestamp: interval * i, value: values[i]));
    }
    return Trace(traceEvents);
  }

  /// Returns true if the trace contains no events.
  bool get isEmpty => events.isEmpty;

  /// Returns the number of events in the trace.
  int get length => events.length;

  @override
  String toString() => 'Trace(${events.join(', ')})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Trace<T> &&
          runtimeType == other.runtimeType &&
          _listEquals(events, other.events); // Use listEquals for deep comparison

  @override
  int get hashCode => Object.hashAll(events); // Use Object.hashAll for lists

  // Helper for deep list comparison
  bool _listEquals<E>(List<E>? a, List<E>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
