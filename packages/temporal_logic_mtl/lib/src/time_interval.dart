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
  static const Duration _practicalInfinity = Duration(days: 365 * 100000);

  /// The inclusive lower bound of the time interval.
  /// Must be non-negative.
  final Duration lowerBound;

  /// The inclusive upper bound of the time interval.
  /// Must be greater than or equal to [lowerBound].
  /// Note: "Infinity" is currently represented by a very large duration.
  final Duration upperBound;

  final bool _isUnbounded;

  // TODO: Add support for open/half-open intervals (e.g., (lower, upper], [lower, upper)) if needed.

  /// Creates a closed time interval `[lowerBound, upperBound]`.
  ///
  /// Throws an [ArgumentError] if `lowerBound` is negative or if `upperBound`
  /// is less than `lowerBound`.
  TimeInterval(this.lowerBound, this.upperBound) : _isUnbounded = false {
    if (lowerBound < Duration.zero) {
      throw ArgumentError.value(
        lowerBound,
        'lowerBound',
        'Lower bound must be non-negative.',
      );
    }

    if (upperBound < lowerBound) {
      throw ArgumentError.value(
        upperBound,
        'upperBound',
        'Upper bound must be greater than or equal to lowerBound.',
      );
    }
  }

  TimeInterval._unbounded(this.lowerBound)
      : upperBound = _practicalInfinity,
        _isUnbounded = true {
    if (lowerBound < Duration.zero) {
      throw ArgumentError.value(
        lowerBound,
        'lowerBound',
        'Lower bound must be non-negative.',
      );
    }
  }

  /// Creates an interval representing exactly duration `d`: `[d, d]`.
  factory TimeInterval.exactly(Duration d) => TimeInterval(d, d);

  /// Creates an interval from zero up to duration `d`: `[0, d]`.
  factory TimeInterval.upTo(Duration d) => TimeInterval(Duration.zero, d);

  /// Creates an interval from duration `d` onwards: `[d, infinity)`.
  ///
  /// Internally, unbounded intervals carry an explicit flag so evaluation does
  /// not stop at the legacy sentinel upper bound.
  factory TimeInterval.atLeast(Duration d) => TimeInterval._unbounded(d);

  /// Creates an interval representing all non-negative time: `[0, infinity)`.
  /// Equivalent to `TimeInterval.atLeast(Duration.zero)`.
  factory TimeInterval.always() => TimeInterval.atLeast(Duration.zero);

  /// Returns `true` when this interval has no finite upper bound.
  bool get isUnbounded => _isUnbounded;

  /// Checks if the given [duration] falls within this time interval (inclusive).
  bool contains(Duration duration) {
    return duration >= lowerBound && (_isUnbounded || duration <= upperBound);
  }

  /// Returns `true` when [duration] is strictly greater than the finite upper bound.
  ///
  /// This is mainly useful for evaluators that want to stop scanning once a
  /// bounded interval can no longer match.
  bool exceedsUpperBound(Duration duration) {
    return !_isUnbounded && duration > upperBound;
  }

  /// Returns a string representation, e.g., `[100ms, 500ms]` or `[1000ms, inf)`.
  @override
  String toString() {
    final lowerMs = lowerBound.inMilliseconds;
    if (_isUnbounded) {
      return '[${lowerMs}ms, inf)';
    }
    final upperMs = upperBound.inMilliseconds;
    return '[${lowerMs}ms, ${upperMs}ms]';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeInterval &&
          runtimeType == other.runtimeType &&
          lowerBound == other.lowerBound &&
          upperBound == other.upperBound &&
          _isUnbounded == other._isUnbounded;

  @override
  int get hashCode => Object.hash(lowerBound, upperBound, _isUnbounded);
}
