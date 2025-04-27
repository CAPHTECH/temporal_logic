import 'package:meta/meta.dart';

/// Represents a closed time interval `[lowerBound, upperBound]` used in MTL formulas.
///
/// The bounds are inclusive and represented using [Duration].
/// Both bounds must be non-negative, and `upperBound` must be greater than
/// or equal to `lowerBound`.
///
/// Use factory constructors like [TimeInterval.exactly], [TimeInterval.upTo],
/// [TimeInterval.atLeast], or [TimeInterval.always] for common interval types.
@immutable
class TimeInterval {
  /// The inclusive lower bound of the time interval.
  /// Must be non-negative.
  final Duration lowerBound;

  /// The inclusive upper bound of the time interval.
  /// Must be greater than or equal to [lowerBound].
  /// Note: "Infinity" is currently represented by a very large duration.
  final Duration upperBound;

  // TODO: Add support for open/half-open intervals (e.g., (lower, upper], [lower, upper)) if needed.

  /// Creates a closed time interval `[lowerBound, upperBound]`.
  ///
  /// Throws an assertion error if `lowerBound` is negative or if `upperBound`
  /// is less than `lowerBound`.
  TimeInterval(this.lowerBound, this.upperBound) {
    assert(lowerBound >= Duration.zero, 'Lower bound must be non-negative.');
    assert(upperBound >= lowerBound, 'Upper bound must be >= lower bound.');
  }

  /// Creates an interval representing exactly duration `d`: `[d, d]`.
  factory TimeInterval.exactly(Duration d) => TimeInterval(d, d);

  /// Creates an interval from zero up to duration `d`: `[0, d]`.
  factory TimeInterval.upTo(Duration d) => TimeInterval(Duration.zero, d);

  /// Creates an interval from duration `d` onwards: `[d, infinity)`.
  ///
  /// **Note:** Infinity is currently approximated using a very large duration
  /// (`Duration(days: 365 * 100)`). Evaluation logic might need to handle this
  /// specially or be updated for true unbounded interval support.
  factory TimeInterval.atLeast(Duration d) {
    // Using a large duration as a proxy for infinity.
    const Duration practicallyInfinity = Duration(days: 365 * 100); // 100 years
    return TimeInterval(d, practicallyInfinity);
  }

  /// Creates an interval representing all non-negative time: `[0, infinity)`.
  /// Equivalent to `TimeInterval.atLeast(Duration.zero)`.
  factory TimeInterval.always() => TimeInterval.atLeast(Duration.zero);

  /// Checks if the given [duration] falls within this time interval (inclusive).
  bool contains(Duration duration) {
    return duration >= lowerBound && duration <= upperBound;
  }

  /// Returns a string representation, e.g., `[100ms, 500ms]` or `[1000ms, inf)`.
  @override
  String toString() {
    final lowerMs = lowerBound.inMilliseconds;
    final upperMs = upperBound.inMilliseconds;
    // Check against the proxy value for infinity
    if (upperMs >= const Duration(days: 365 * 100).inMilliseconds) {
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
  int get hashCode => Object.hash(lowerBound, upperBound);
}
