/// Base class for all Temporal Logic formulas.
///
/// Implementations define specific temporal operators or atomic propositions.
/// The type parameter [T] represents the type of the state in the trace.
/*sealed*/ class Formula<T> {
  const Formula();

  // The `eval` method is removed. Evaluation is now handled by `evaluateTrace`
  // in `evaluator.dart`, operating on `Trace<T>` objects.
  // bool eval(List<T> t, int i);

  @override
  String toString(); // Force subclasses to implement for better debugging
}

/// Represents an atomic proposition based on a state predicate.
///
/// Evaluates to `true` if the predicate [pred] holds for the state at the current index.
final class AtomicProposition<T> extends Formula<T> {
  /// The predicate function that defines the atomic proposition.
  final bool Function(T state) pred;
  final String? name; // Optional name for better toString

  const AtomicProposition(this.pred, {this.name});

  // @override
  // bool eval(List<T> t, int i) {
  //   if (i < 0 || i >= t.length) {
  //     return false;
  //   }
  //   return pred(t[i]);
  // }

  @override
  String toString() => name ?? '$pred'; // Use name if provided
}

/// Represents the logical negation (`NOT` or `!`) of a formula.
final class Not<T> extends Formula<T> {
  final Formula<T> operand;
  const Not(this.operand);

  // @override
  // bool eval(List<T> t, int i) => !operand.eval(t, i);

  @override
  String toString() => '!($operand)';
}

/// Represents the logical conjunction (`AND` or `&&`) of two formulas.
final class And<T> extends Formula<T> {
  final Formula<T> left;
  final Formula<T> right;
  const And(this.left, this.right);

  // @override
  // bool eval(List<T> t, int i) => left.eval(t, i) && right.eval(t, i);

  @override
  String toString() => '($left && $right)';
}

/// Represents the logical disjunction (`OR` or `||`) of two formulas.
final class Or<T> extends Formula<T> {
  final Formula<T> left;
  final Formula<T> right;
  const Or(this.left, this.right);

  // @override
  // bool eval(List<T> t, int i) => left.eval(t, i) || right.eval(t, i);

  @override
  String toString() => '($left || $right)';
}

/// Represents the logical implication (`IMPLIES` or `->`).
final class Implies<T> extends Formula<T> {
  final Formula<T> left; // Antecedent
  final Formula<T> right; // Consequent
  const Implies(this.left, this.right);

  // @override
  // bool eval(List<T> t, int i) => !left.eval(t, i) || right.eval(t, i);

  @override
  String toString() => '($left -> $right)';
}

/// Represents the temporal operator NEXT (`X` or `○`).
///
/// Evaluates to `true` if the [operand] holds at the next time step (i+1).
/// For finite traces, if the current index `i` is the last index, it evaluates to `false`
/// because there is no next state.
final class Next<T> extends Formula<T> {
  final Formula<T> operand;
  const Next(this.operand);

  // @override
  // bool eval(List<T> t, int i) {
  //   // Handle invalid current index
  //   if (i < -1 || i >= t.length) return false;
  //   // Note: We allow i == -1 slightly unconventionally to simplify some recursive definitions
  //   // later, but for direct evaluation, i < 0 is usually an error/false.
  //   // Let's refine this: standard eval expects i >= 0.
  //   if (i < 0) return false;
  //
  //   // Check if a next state exists
  //   final nextIndex = i + 1;
  //   if (nextIndex >= t.length) {
  //     return false; // Finite trace semantics: no next state means Xp is false
  //   }
  //
  //   // Evaluate operand at the next state
  //   return operand.eval(t, nextIndex);
  // }

  @override
  String toString() => 'X($operand)';
}

/// Represents the temporal operator ALWAYS (`G` or `□`).
///
/// Evaluates to `true` if the [operand] holds at the current time step `i`
/// and at all subsequent time steps in the trace.
final class Always<T> extends Formula<T> {
  final Formula<T> operand;
  const Always(this.operand);

  // @override
  // bool eval(List<T> t, int i) {
  //   // Handle strictly invalid current index (negative)
  //   if (i < 0) return false;
  //
  //   // The loop condition (k < t.length) correctly handles the case where i >= t.length.
  //   // G p is vacuously true over an empty suffix.
  //
  //   // Check operand at all indices from i to the end of the trace
  //   for (var k = i; k < t.length; k++) {
  //     if (!operand.eval(t, k)) {
  //       return false;
  //     }
  //   }
  //   // If the loop completes without returning false, the operand holds everywhere (or the suffix was empty)
  //   return true;
  // }

  @override
  String toString() => 'G($operand)';
}

/// Represents the temporal operator EVENTUALLY (`F` or `◇`).
///
/// Evaluates to `true` if the [operand] holds at the current time step `i`
/// or at any subsequent time step in the trace.
final class Eventually<T> extends Formula<T> {
  final Formula<T> operand;
  const Eventually(this.operand);

  // @override
  // bool eval(List<T> t, int i) {
  //   // Handle invalid current index
  //   if (i < 0 || i >= t.length) return false;
  //
  //   // Check operand at index i and all subsequent indices
  //   for (var k = i; k < t.length; k++) {
  //     if (operand.eval(t, k)) {
  //       return true; // Found a state where the operand holds
  //     }
  //   }
  //   // If the loop completes, the operand never holds from i onwards
  //   return false;
  // }

  @override
  String toString() => 'F($operand)';
}

/// Represents the temporal operator UNTIL (`U`).
///
/// `left U right` holds at index `i` if there exists an index `k >= i` such that
/// `right` holds at `k`, and for all indices `j` where `i <= j < k`,
/// `left` holds at `j`.
final class Until<T> extends Formula<T> {
  final Formula<T> left;  // The condition that must hold until the right side holds
  final Formula<T> right; // The condition that must eventually hold
  const Until(this.left, this.right);

  // @override
  // bool eval(List<T> t, int i) {
  //   // Handle invalid current index
  //   if (i < 0 || i >= t.length) return false;
  //
  //   // Iterate through future states (k >= i)
  //   for (var k = i; k < t.length; k++) {
  //     // Check if the 'right' condition holds at k
  //     if (right.eval(t, k)) {
  //       // Now check if 'left' holds for all states from i up to (but not including) k
  //       bool leftHolds = true;
  //       for (var j = i; j < k; j++) {
  //         if (!left.eval(t, j)) {
  //           leftHolds = false;
  //           break;
  //         }
  //       }
  //       // If 'left' held all the way, then 'until' is satisfied
  //       if (leftHolds) {
  //         return true;
  //       }
  //     }
  //   }
  //
  //   // If the loop completes without finding a suitable k, 'until' is false
  //   return false;
  // }

  @override
  String toString() => '($left U $right)';
}

/// Represents the temporal operator WEAK UNTIL (`W`).
///
/// `left W right` holds at index `i` if either:
/// 1. There exists `k >= i` such that `right` holds at `k` and `left` holds for all `j` where `i <= j < k` (like Until).
/// 2. `left` holds for all `k >= i` (like Always).
final class WeakUntil<T> extends Formula<T> {
  final Formula<T> left;
  final Formula<T> right;
  const WeakUntil(this.left, this.right);

  // @override
  // bool eval(List<T> t, int i) {
  //   // Handle invalid current index
  //   if (i < 0 || i >= t.length) return false;
  //
  //   // Iterate through future states (k >= i), checking both conditions.
  //   for (var k = i; k < t.length; k++) {
  //     // Check if 'right' holds at k. If so, we need 'left' to have held until now.
  //     if (right.eval(t, k)) {
  //       bool leftHeldUntilK = true;
  //       for (var j = i; j < k; j++) {
  //         if (!left.eval(t, j)) {
  //           leftHeldUntilK = false;
  //           break;
  //         }
  //       }
  //       if (leftHeldUntilK) {
  //         return true; // Condition 1 (like Until) met.
  //       }
  //     }
  //
  //     // If 'right' didn't hold at k, 'left' must hold at k to potentially satisfy condition 2 (Always left).
  //     if (!left.eval(t, k)) {
  //       // If left fails at any point k where right hasn't held, WeakUntil fails.
  //       return false;
  //     }
  //   }
  //
  //   // If the loop completes, it means 'right' never held, but 'left' held for all k >= i.
  //   // This satisfies condition 2 (like Always left).
  //   return true;
  // }

  @override
  String toString() => '($left W $right)';
}

/// Represents the temporal operator RELEASE (`R`).
///
/// `left R right` holds at index `i` if `right` holds at `i` and all preceding
/// indices `j` (where `i <= j < k` for some `k`) until (and including) an index `k`
/// where `left` holds. If `left` never holds, `right` must hold indefinitely.
/// Formally, `p R q` is equivalent to `!( !p U !q )`
final class Release<T> extends Formula<T> {
  final Formula<T> left;
  final Formula<T> right;
  const Release(this.left, this.right);

  // @override
  // bool eval(List<T> t, int i) {
  //   // Handle invalid current index
  //   if (i < 0 || i >= t.length) return false;
  //
  //   // Iterate through future states (k >= i)
  //   for (var k = i; k < t.length; k++) {
  //     // If 'left' holds at k, then 'right' must have held for all j from i to k (inclusive)
  //     if (left.eval(t, k)) {
  //       bool rightHeldUntilK = true;
  //       for (var j = i; j <= k; j++) {
  //         if (!right.eval(t, j)) {
  //           rightHeldUntilK = false;
  //           break;
  //         }
  //       }
  //       if (rightHeldUntilK) {
  //         return true;
  //       }
  //     }
  //   }
  //
  //   // If the loop finished without 'left' ever holding,
  //   // then 'right' must hold for all indices >= i
  //   for (var k = i; k < t.length; k++) {
  //     if (!right.eval(t, k)) {
  //       return false; // 'right' failed, and 'left' never became true, so Release is false
  //     }
  //   }
  //
  //   // If the loop completes, 'right' held for all k >= i (and 'left' never held)
  //   return true;
  // }

  @override
  String toString() => '($left R $right)';
}

/// Provides convenient extension methods for building formulas using logical connectives.
extension LogicalConnectives<T> on Formula<T> {
  /// Creates a logical AND formula (`this && other`).
  And<T> and(Formula<T> other) => And<T>(this, other);

  /// Creates a logical OR formula (`this || other`).
  Or<T> or(Formula<T> other) => Or<T>(this, other);

  /// Creates a logical IMPLIES formula (`this -> other`).
  Implies<T> implies(Formula<T> other) => Implies<T>(this, other);

  /// Creates a logical NOT formula (`!this`).
  Not<T> not() => Not<T>(this);
}

// Removed unused CheckResult enum
// Release (R) will follow. 
