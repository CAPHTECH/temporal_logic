import 'package:temporal_logic_core/temporal_logic_core.dart';

import 'time_interval.dart';

/// Represents the timed eventually operator `F_I φ` (Finally within Interval).
///
/// Asserts that the [operand] formula `φ` holds true at some point `k`
/// in the trace suffix starting from the evaluation point `i`, such that the time
/// difference `timestamp(k) - timestamp(i)` falls within the specified [interval] `I`.
///
/// Example: `EventuallyTimed(isReady, TimeInterval.upTo(Duration(seconds: 5)))`
/// asserts that `isReady` becomes true within 5 seconds from the current time.
final class EventuallyTimed<T> extends Formula<T> {
  /// The formula `φ` that must eventually hold within the interval.
  final Formula<T> operand;

  /// The time interval `I` within which the [operand] must hold.
  final TimeInterval interval;

  /// Creates a timed eventually formula `F_I φ`.
  const EventuallyTimed(this.operand, this.interval);

  @override
  String toString() => 'F$interval($operand)';
}

/// Represents the timed always operator `G_I φ` (Globally within Interval).
///
/// Asserts that the [operand] formula `φ` holds true at all points `k`
/// in the trace suffix starting from the evaluation point `i`, such that the time
/// difference `timestamp(k) - timestamp(i)` falls within the specified [interval] `I`.
///
/// If no points `k` fall within the interval `I` relative to point `i`,
/// the formula is considered vacuously true.
///
/// Example: `AlwaysTimed(isStable, TimeInterval(Duration(seconds: 1), Duration(seconds: 10)))`
/// asserts that `isStable` holds continuously between 1 and 10 seconds from now.
final class AlwaysTimed<T> extends Formula<T> {
  /// The formula `φ` that must always hold within the interval.
  final Formula<T> operand;

  /// The time interval `I` throughout which the [operand] must hold.
  final TimeInterval interval;

  /// Creates a timed always formula `G_I φ`.
  const AlwaysTimed(this.operand, this.interval);

  @override
  String toString() => 'G$interval($operand)';
}

/// Represents the timed until operator `φ U_I ψ` (Until within Interval).
///
/// Asserts that there exists a point `k` in the trace suffix starting from `i` such that:
/// 1. The time difference `timestamp(k) - timestamp(i)` falls within the [interval] `I`.
/// 2. The [right] formula `ψ` holds at point `k`.
/// 3. For all points `j` such that `i <= j < k`, the [left] formula `φ` holds.
///
/// Example: `requesting.untilTimed(granted, TimeInterval.upTo(Duration(seconds: 2)))`
/// asserts that `requesting` holds until `granted` becomes true, and that `granted`
/// becomes true within 2 seconds.
final class UntilTimed<T> extends Formula<T> {
  /// The formula `φ` that must hold until [right] becomes true.
  final Formula<T> left;

  /// The formula `ψ` that must eventually become true within the interval.
  final Formula<T> right;

  /// The time interval `I` within which [right] must become true.
  final TimeInterval interval;

  /// Creates a timed until formula `φ U_I ψ`.
  const UntilTimed(this.left, this.right, this.interval);

  @override
  String toString() => '($left U$interval $right)';
}

/// Represents the timed release operator `φ R_I ψ` (Release within Interval).
///
/// Asserts that the [right] formula `ψ` holds true at all points `k`
/// within the [interval] `I` relative to the starting point `i`, *unless* the
/// [left] formula `φ` becomes true at some point `j` within `I`. If `φ`
/// becomes true at `j`, then `ψ` must hold at all points from `j` up to the
/// time `t_i + interval.upperBound`.
///
/// Another way to think about it: For all points `k` within the interval `I`
/// relative to `i`, if `ψ` fails at `k`, then `φ` must hold at `k`.
/// This is equivalent to `¬(¬left U_I ¬right)`.
///
/// Example: `error R_[0, 10s] recovery` asserts that `recovery` holds for the
/// first 10 seconds, or until an `error` occurs (if it occurs within 10s),
/// after which `recovery` must still hold until the 10s mark.
final class ReleaseTimed<T> extends Formula<T> {
  /// The formula `φ` that can "release" the obligation for [right] to hold
  /// continuously (though [right] must still hold when [left] holds).
  final Formula<T> left;

  /// The formula `ψ` that must generally hold throughout the interval.
  final Formula<T> right;

  /// The time interval `I`.
  final TimeInterval interval;

  /// Creates a timed release formula `φ R_I ψ`.
  const ReleaseTimed(this.left, this.right, this.interval);

  @override
  String toString() => '($left R$interval $right)';
}

/// Represents the timed weak until operator `φ W_I ψ` (Weak Until within Interval).
///
/// Asserts that either:
/// 1. The [left] formula `φ` holds true at all points `k` within the
///    [interval] `I` relative to the starting point `i` (i.e., `G_I φ` holds).
/// OR
/// 2. The timed until condition `φ U_I ψ` holds.
///
/// This means `φ` must hold continuously within `I` up until a point `k`
/// (also within `I`) where `ψ` holds. Unlike `U_I`, if `ψ` never holds within
/// `I`, the formula can still be true provided `φ` holds throughout `I`.
///
/// Equivalent to `(φ U_I ψ) ∨ G_I φ`.
///
/// Example: `processing W_[0, 5s] completed` asserts that `processing` holds
/// until `completed` becomes true within 5 seconds, OR `processing` holds
/// continuously for the entire 5 seconds.
final class WeakUntilTimed<T> extends Formula<T> {
  /// The formula `φ` that must hold until [right] becomes true, or throughout the interval.
  final Formula<T> left;

  /// The formula `ψ` that eventually becomes true within the interval, or never does.
  final Formula<T> right;

  /// The time interval `I`.
  final TimeInterval interval;

  /// Creates a timed weak until formula `φ W_I ψ`.
  const WeakUntilTimed(this.left, this.right, this.interval);

  @override
  String toString() => '($left W$interval $right)';
}
