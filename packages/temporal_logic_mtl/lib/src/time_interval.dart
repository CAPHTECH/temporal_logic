import 'package:meta/meta.dart';

/// Represents a time interval [lowerBound, upperBound].
/// Intervals can be open or closed at either end, though for simplicity,
/// we might start with closed intervals.
@immutable
class TimeInterval {
  final Duration lowerBound;
  final Duration upperBound;
  // TODO: Add flags for open/closed intervals if needed

  /// Creates a closed time interval [lower, upper].
  TimeInterval(this.lowerBound, this.upperBound) {
    assert(lowerBound >= Duration.zero, 'Lower bound must be non-negative.');
    assert(upperBound >= lowerBound, 'Upper bound must be >= lower bound.');
  }

  /// Creates an interval representing exactly duration `d`. [d, d]
  factory TimeInterval.exactly(Duration d) => TimeInterval(d, d);

  /// Creates an interval [0, d].
  factory TimeInterval.upTo(Duration d) => TimeInterval(Duration.zero, d);

  /// Creates an interval [d, infinity).
  /// Note: Representing infinity requires care in verification algorithms.
  /// For now, we might use a very large duration or handle it specially.
  factory TimeInterval.atLeast(Duration d) {
    // Using a large duration as a proxy for infinity for now.
    // A more robust implementation would handle unbounded intervals directly.
    const Duration practicallyInfinity = Duration(days: 365 * 100); // 100 years
    return TimeInterval(d, practicallyInfinity);
  }

  /// Creates an interval [0, infinity).
  factory TimeInterval.always() => TimeInterval.atLeast(Duration.zero);

  bool contains(Duration duration) {
    return duration >= lowerBound && duration <= upperBound;
  }

  @override
  String toString() {
    final lowerMs = lowerBound.inMilliseconds;
    final upperMs = upperBound.inMilliseconds;
    // Basic representation, could be enhanced for infinity/open intervals
    if (upperMs > const Duration(days: 365 * 99).inMilliseconds) {
      return '[${lowerMs}ms, inf)';
    }
    return '[${lowerMs}ms, ${upperMs}ms]';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeInterval &&
          runtimeType == other.runtimeType &&
          lowerBound == other.lowerBound &&
          upperBound == other.upperBound;

  @override
  int get hashCode => lowerBound.hashCode ^ upperBound.hashCode;
} 
