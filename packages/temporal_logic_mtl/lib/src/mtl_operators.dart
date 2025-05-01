import 'package:temporal_logic_core/temporal_logic_core.dart';

import 'time_interval.dart';

// --- MTL AST Nodes ---

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

// --- Integrated MTL/LTL Evaluator ---

/// Evaluates a temporal logic [formula] (potentially including both LTL and MTL
/// operators) against a given timed [trace], starting from [startIndex].
///
/// This function serves as the primary entry point for checking specifications
/// involving time. It handles both standard LTL operators (from `temporal_logic_core`)
/// and MTL operators (like [EventuallyTimed], [AlwaysTimed], [UntilTimed])
/// defined in this library.
///
/// Evaluation starts at the given [startIndex] of the trace (defaults to 0).
/// Temporal operators consider the suffix of the trace starting from this index,
/// taking into account the timestamps of events for MTL operators.
///
/// Parameters:
/// - [trace]: The sequence of timed states/events ([TraceEvent]) to evaluate
///   against. Timestamps must be monotonically non-decreasing.
/// - [formula]: The LTL or MTL formula to evaluate.
/// - [startIndex]: The 0-based index in the [trace] from which to begin
///   evaluation. Defaults to 0. Must be non-negative and not exceed the
///   trace length.
///
/// Returns an [EvaluationResult] indicating success or failure, potentially
/// with details on the reason for failure and the relevant time/index.
///
/// **Semantics Overview:**
/// - Standard LTL operators behave as defined in `temporal_logic_core`'s `evaluateTrace`,
///   considering only the sequence order relative to [startIndex].
/// - MTL operators ([EventuallyTimed], [AlwaysTimed], [UntilTimed]) evaluate their
///   operands based on whether subsequent events fall within the specified
///   [TimeInterval] relative to the event at [startIndex].
/// - See the documentation for specific MTL operators for detailed semantics.
///
/// **Note:** This function uses [_evaluateRecursive] internally.
EvaluationResult evaluateMtlTrace<T>(Trace<T> trace, Formula<T> formula, {int startIndex = 0}) {
  // Check for empty trace for certain operators early?
  // Or let recursive calls handle it.
  if (trace.isEmpty && startIndex == 0) {
    // Define behavior for empty trace based on formula type? Might be complex.
    // Most temporal operators are false on empty traces, except perhaps G(p).
    // Let's rely on the recursive logic for now.
  }

  // Ensure startIndex is within reasonable bounds before recursion
  if (startIndex < 0 || startIndex > trace.length) {
    return EvaluationResult.failure('Start index $startIndex out of bounds for trace length ${trace.length}');
  }

  return _evaluateRecursive(trace, formula, startIndex);
}

// Internal recursive evaluation function (Handles LTL and MTL)
EvaluationResult _evaluateRecursive<T>(Trace<T> trace, Formula<T> formula, int index) {
  // Base case: If index is beyond trace length, behavior depends on operator.
  // Handled within each operator case.

  // --- Get current timestamp if needed (avoid repeated lookups) ---
  Duration? currentIndexTimestamp;
  if (index < trace.length) {
    currentIndexTimestamp = trace.events[index].timestamp;
  } else {
    // Handle cases where index is at trace.length for operators like Always/Eventually
    // which might be vacuously true/false on empty suffixes.
  }

  // --- Core LTL Operators (Logic copied from temporal_logic_core.evaluator) ---
  switch (formula) {
    case AtomicProposition<T> p:
      if (index >= trace.length)
        return EvaluationResult.failure("Atomic proposition evaluated past trace end.", relatedIndex: index);
      final currentEvent = trace.events[index];
      final holds = p.predicate(currentEvent.value);
      return EvaluationResult(holds,
          reason: !holds ? '${p.name ?? "Atomic"} failed' : null,
          relatedIndex: index,
          relatedTimestamp: currentEvent.timestamp);

    case Not<T> f:
      final innerResult = _evaluateRecursive(trace, f.operand, index);
      return EvaluationResult(!innerResult.holds,
          reason: innerResult.holds ? 'Negated formula held' : innerResult.reason,
          relatedIndex: innerResult.relatedIndex,
          relatedTimestamp: innerResult.relatedTimestamp);

    case And<T> f:
      final leftResult = _evaluateRecursive(trace, f.left, index);
      if (!leftResult.holds) return leftResult; // Short-circuit
      final rightResult = _evaluateRecursive(trace, f.right, index);
      return rightResult; // If left holds, result is determined by right

    case Or<T> f:
      final leftResult = _evaluateRecursive(trace, f.left, index);
      if (leftResult.holds) return leftResult; // Short-circuit
      final rightResult = _evaluateRecursive(trace, f.right, index);
      // If left failed, result is determined by right
      // If both failed, rightResult will contain the failure reason for the right side.
      // We might want a more combined reason here?
      return rightResult;

    case Implies<T> f:
      final leftResult = _evaluateRecursive(trace, f.left, index);
      if (!leftResult.holds) return const EvaluationResult.success(); // Antecedent false -> implication holds
      // Antecedent true, result is the evaluation of the consequent
      return _evaluateRecursive(trace, f.right, index);

    case Next<T> f:
      final nextIndex = index + 1;
      if (nextIndex >= trace.length)
        return EvaluationResult.failure('Next evaluated past trace end.', relatedIndex: index);
      // Evaluate operand at the next index
      return _evaluateRecursive(trace, f.operand, nextIndex);

    case Always<T> f: // G phi
      for (var k = index; k < trace.length; k++) {
        final stepResult = _evaluateRecursive(trace, f.operand, k);
        if (!stepResult.holds) {
          // Found a point where the operand fails
          return EvaluationResult.failure('Always failed: ${stepResult.reason ?? "Operand failed"}',
              relatedIndex: k, relatedTimestamp: trace.events[k].timestamp);
        }
      }
      // Operand holds for all k >= index (or suffix is empty)
      return const EvaluationResult.success();

    case Eventually<T> f: // F phi
      if (index >= trace.length)
        return EvaluationResult.failure('Eventually evaluated on empty trace suffix.',
            relatedIndex: index); // F phi is false on empty suffix
      for (var k = index; k < trace.length; k++) {
        final stepResult = _evaluateRecursive(trace, f.operand, k);
        if (stepResult.holds) {
          return const EvaluationResult.success(); // Found a state where it holds
        }
      }
      // Operand never holds for k >= index
      return EvaluationResult.failure('Eventually failed: Operand never held.',
          relatedIndex: index, relatedTimestamp: trace.events.isNotEmpty ? trace.events[index].timestamp : null);

    case Until<T> f: // left U right
      if (index >= trace.length)
        return EvaluationResult.failure('Until evaluated on empty trace suffix.', relatedIndex: index);
      for (var k = index; k < trace.length; k++) {
        final rightResult = _evaluateRecursive(trace, f.right, k);
        if (rightResult.holds) {
          // Right holds at k. Check if Left held for all j in [index, k)
          for (var j = index; j < k; j++) {
            final leftResult = _evaluateRecursive(trace, f.left, j);
            if (!leftResult.holds) {
              // Left failed before Right held
              return EvaluationResult.failure(
                  'Until failed: Left operand failed before right held (${leftResult.reason ?? "Left failed"})',
                  relatedIndex: j,
                  relatedTimestamp: trace.events[j].timestamp);
            }
          }
          // Left held for all j in [index, k)
          return const EvaluationResult.success();
        }
        // Right didn't hold at k. Left must hold at k to continue.
        final leftResult = _evaluateRecursive(trace, f.left, k);
        if (!leftResult.holds) {
          // Left failed before Right held
          return EvaluationResult.failure(
              'Until failed: Left operand failed before right held (${leftResult.reason ?? "Left failed"})',
              relatedIndex: k,
              relatedTimestamp: trace.events[k].timestamp);
        }
      }
      // Loop finished: Right never held
      return EvaluationResult.failure('Until failed: Right operand never held.',
          relatedIndex: index, relatedTimestamp: trace.events.isNotEmpty ? trace.events[index].timestamp : null);

    case WeakUntil<T> f: // left W right === G(left) or (left U right)
      // Evaluate G(left)
      final alwaysLeftResult = _evaluateRecursive(trace, Always<T>(f.left), index);
      if (alwaysLeftResult.holds) return const EvaluationResult.success();
      // Evaluate (left U right)
      final untilResult = _evaluateRecursive(trace, Until<T>(f.left, f.right), index);
      return untilResult;

    case Release<T> f: // left R right === !(!left U_I !right)
      final notLeft = Not<T>(f.left);
      final notRight = Not<T>(f.right);
      final untilFormula = Until<T>(notLeft, notRight);
      final untilResult = _evaluateRecursive(trace, untilFormula, index);
      // Negate the result of the Until
      return EvaluationResult(!untilResult.holds,
          reason: untilResult.holds
              ? 'Release failed: !(${untilFormula}) held'
              : 'Release held: !(${untilFormula}) failed (${untilResult.reason ?? "reason unknown"})',
          relatedIndex: untilResult.relatedIndex,
          relatedTimestamp: untilResult.relatedTimestamp);

    // --- MTL Operators ---

    case EventuallyTimed<T> f: // F_I phi
      if (currentIndexTimestamp == null) {
        // Can't evaluate timed interval from past end of trace
        return EvaluationResult.failure('EventuallyTimed evaluated past trace end.', relatedIndex: index);
      }
      for (var k = index; k < trace.length; k++) {
        final Duration timeDiff = trace.events[k].timestamp - currentIndexTimestamp;
        // Optimization: if time difference exceeds interval, operand cannot hold within it later
        if (timeDiff > f.interval.upperBound) break;

        if (f.interval.contains(timeDiff)) {
          final stepResult = _evaluateRecursive(trace, f.operand, k);
          if (stepResult.holds) {
            // Found a point within the interval where operand holds
            return const EvaluationResult.success();
          }
        }
      }
      // Operand never held within the interval I relative to index
      return EvaluationResult.failure('EventuallyTimed failed: Operand never held within interval ${f.interval}.',
          relatedIndex: index, relatedTimestamp: currentIndexTimestamp);

    case AlwaysTimed<T> f: // G_I phi
      if (currentIndexTimestamp == null) {
        // Vacuously true if evaluated past end of trace (no points in interval)
        return const EvaluationResult.success();
      }
      for (var k = index; k < trace.length; k++) {
        final Duration timeDiff = trace.events[k].timestamp - currentIndexTimestamp;
        // Optimization: if time difference exceeds interval, no need to check further
        if (timeDiff > f.interval.upperBound) break;

        if (f.interval.contains(timeDiff)) {
          final stepResult = _evaluateRecursive(trace, f.operand, k);
          if (!stepResult.holds) {
            // Found a point within interval where operand fails
            return EvaluationResult.failure(
                'AlwaysTimed failed: ${stepResult.reason ?? "Operand failed"} within interval ${f.interval}.',
                relatedIndex: k,
                relatedTimestamp: trace.events[k].timestamp);
          }
        }
      }
      // Operand held for all points within the interval I relative to index,
      // or no points existed in the interval (vacuously true).
      return const EvaluationResult.success();

    case UntilTimed<T> f: // left U_I right
      if (currentIndexTimestamp == null) {
        return EvaluationResult.failure('UntilTimed evaluated past trace end.', relatedIndex: index);
      }
      for (var k = index; k < trace.length; k++) {
        final Duration timeDiff = trace.events[k].timestamp - currentIndexTimestamp;

        // Check if right operand holds within interval first
        if (timeDiff <= f.interval.upperBound && f.interval.contains(timeDiff)) {
          final rightResult = _evaluateRecursive(trace, f.right, k);
          if (rightResult.holds) {
            // Right holds at k within interval. Now check if Left held until k.
            for (var j = index; j < k; j++) {
              final leftResult = _evaluateRecursive(trace, f.left, j);
              if (!leftResult.holds) {
                // Left failed before Right held within interval
                return EvaluationResult.failure(
                    'UntilTimed failed: Left operand failed before right held within interval ${f.interval} (${leftResult.reason ?? "Left failed"}).',
                    relatedIndex: j,
                    relatedTimestamp: trace.events[j].timestamp);
              }
            }
            // Left held for all j in [index, k)
            return const EvaluationResult.success();
          }
        }

        // Optimization: If we passed the interval, right can't hold within it later.
        if (timeDiff > f.interval.upperBound) break;

        // If right didn't hold at k (or k wasn't in interval yet), left must hold at k to continue.
        final leftResult = _evaluateRecursive(trace, f.left, k);
        if (!leftResult.holds) {
          // Left failed before Right held within interval
          return EvaluationResult.failure(
              'UntilTimed failed: Left operand failed before right held within interval ${f.interval} (${leftResult.reason ?? "Left failed"}).',
              relatedIndex: k,
              relatedTimestamp: trace.events[k].timestamp);
        }
      }

      // Loop finished: Right never held within the interval I
      return EvaluationResult.failure('UntilTimed failed: Right operand never held within interval ${f.interval}.',
          relatedIndex: index, relatedTimestamp: currentIndexTimestamp);

    case ReleaseTimed<T> f: // left R_I right
      // Evaluate !(!left U_I !right)
      final notLeft = Not<T>(f.left);
      final notRight = Not<T>(f.right);
      final untilNotLeftNotRight = UntilTimed<T>(notLeft, notRight, f.interval);
      final evalUntil = _evaluateRecursive(trace, untilNotLeftNotRight, index);
      // Release holds if the Until fails
      return EvaluationResult(!evalUntil.holds,
          reason: evalUntil.holds
              ? 'ReleaseTimed failed: Corresponding ¬(${f.left}) U_${f.interval} ¬(${f.right}) held'
              : null,
          relatedIndex: evalUntil.relatedIndex,
          relatedTimestamp: evalUntil.relatedTimestamp);
    case WeakUntilTimed<T> f: // left W_I right === G_I left or (left U_I right)
      // Try G_I left first
      final alwaysLeft = AlwaysTimed<T>(f.left, f.interval);
      final alwaysResult = _evaluateRecursive(trace, alwaysLeft, index);
      if (alwaysResult.holds) return const EvaluationResult.success();

      // If G_I left fails, try left U_I right
      final untilLeftRight = UntilTimed<T>(f.left, f.right, f.interval);
      final untilResult = _evaluateRecursive(trace, untilLeftRight, index);
      return untilResult; // Result is the result of the Until

    // --- Default: Unknown Formula Type ---
    default:
      // Potentially handle LTL operators here if not done above
      // Or throw an error for unsupported types
      return EvaluationResult.failure('Unsupported formula type encountered: ${formula.runtimeType}');
  }
}

// --- Deprecated Standalone Check Functions ---

/// [DEPRECATED: Use evaluateMtlTrace] Checks if the formula [operand] holds eventually within the [interval]
/// for the given timed [trace].
///
/// Checks if operand [phi] becomes true at some point within the [interval]
/// relative to the start of the [trace]. (F_I phi)
@Deprecated('Use evaluateMtlTrace with EventuallyTimed formula')
bool checkEventuallyWithin<S>(
    Trace<S> trace, // Use Trace from core
    TimeInterval interval,
    AtomicProposition<S> operand) {
  // Use AtomicProposition
  if (trace.isEmpty) return false;
  final startTime = trace.events.first.timestamp;

  for (int i = 0; i < trace.length; i++) {
    final currentTime = trace.events[i].timestamp;
    final timeOffset = currentTime - startTime;

    // Check if the current time point is within the interval
    if (interval.contains(timeOffset)) {
      // Evaluate the proposition directly on the state at time i
      if (operand.predicate(trace.events[i].value)) {
        return true; // Found a time point satisfying the operand within the interval
      }
    }
    // Optimization: If current time is already past the upper bound
    if (timeOffset > interval.upperBound) {
      break;
    }
  }
  return false; // No satisfying time point found within the interval
}

/// [DEPRECATED: Use evaluateMtlTrace] Checks if operand [phi] holds true at all points within the [interval]
/// relative to the start of the [trace]. (G_I phi)
@Deprecated('Use evaluateMtlTrace with AlwaysTimed formula')
bool checkAlwaysWithin<S>(
    Trace<S> trace, // Use Trace from core
    TimeInterval interval,
    AtomicProposition<S> operand) {
  // Use AtomicProposition

  if (trace.isEmpty) {
    return true;
  }
  final startTime = trace.events.first.timestamp;

  for (int i = 0; i < trace.length; i++) {
    final currentEvent = trace.events[i]; // Use TraceEvent
    final currentTime = currentEvent.timestamp;
    final currentValue = currentEvent.value;
    final timeOffset = currentTime - startTime;

    // Only check points *within* the interval
    final isInInterval = interval.contains(timeOffset);

    if (isInInterval) {
      final operandResult = operand.predicate(currentValue);
      if (!operandResult) {
        return false; // Found a time point violating the operand within the interval
      }
    }
    // Optimization: If current time is already past the upper bound
    if (timeOffset > interval.upperBound) {
      break;
    }
  }
  // If we checked at least one point and found no violations, return true.
  // If no points were in the interval, G_I p is vacuously true.
  return true; // Either no violation found or interval was effectively empty for the trace
}

/// [DEPRECATED: Use evaluateMtlTrace] Checks if [left] holds true until [right] becomes true within the [interval]
/// relative to the start of the [trace]. (phi U_I psi)
///
/// Semantics: Exists time `t` in `interval` such that `right` holds at `t`,
/// AND for all times `t'` from start (0) up to `t`, `left` holds at `t'`.
/// Note: The interval applies ONLY to the point where `right` must hold.
/// The `left` condition applies from the beginning of the trace up to that point.
@Deprecated('Use evaluateMtlTrace with UntilTimed formula')
bool checkUntilWithin<S>(
    Trace<S> trace, // Use Trace from core
    TimeInterval interval,
    AtomicProposition<S> left, // Use AtomicProposition
    AtomicProposition<S> right) {
  // Use AtomicProposition
  if (trace.isEmpty) return false;
  final startTime = trace.events.first.timestamp;

  for (int k = 0; k < trace.length; k++) {
    final timeK = trace.events[k].timestamp;
    final timeOffsetK = timeK - startTime;
    final stateK = trace.events[k].value;

    // Check if 'right' (psi) holds at time k, and time k is within the interval
    if (interval.contains(timeOffsetK) && right.predicate(stateK)) {
      // Found a potential endpoint k for the Until.
      // Now, check if 'left' (phi) held true at all points j from 0 up to (but not including) k.
      bool leftHeldPreviously = true;
      for (int j = 0; j < k; j++) {
        final stateJ = trace.events[j].value;
        if (!left.predicate(stateJ)) {
          leftHeldPreviously = false;
          break; // Found a point before k where left didn't hold
        }
      }

      if (leftHeldPreviously) {
        // Yes, right holds at k (in interval) and left held for all j < k.
        return true; // Found a valid 'until' sequence
      }
      // If left didn't hold previously, continue searching for another k
    }

    // Optimization: If time k is already past the interval's upper bound,
    // and right hasn't been met within the interval yet, we might be able to stop early?
    // But right could potentially become true later *outside* the interval, fulfilling a prior Until?
    // The standard definition is usually about right holding *within* the interval.
    // Let's stick to checking all k. If we pass the interval without right holding within it,
    // the loop will finish, and we'll return false.
    // Optimization: If timeOffsetK > interval.upperBound, no *future* k can satisfy the interval condition.
    if (timeOffsetK > interval.upperBound) {
      // We haven't found a k within the interval where right holds yet.
      break;
    }
  }

  return false; // No satisfying sequence found
}

// --- Convenience functions ---

// Add other variants as needed, e.g., eventuallyAtLeast, eventuallyBetween, etc.
// Note: If adding non-conflicting convenience functions, consider giving them
// unique names like `eventuallyUpTo`, `alwaysUpTo`, `untilUpTo` to avoid ambiguity.
