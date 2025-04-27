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
  final String? name;

  const AtomicProposition(this.pred, {this.name});

  @override
  String toString() => name ?? '$pred';
}

/// Represents the logical negation (`NOT` or `!`) of a formula.
final class Not<T> extends Formula<T> {
  final Formula<T> operand;
  const Not(this.operand);

  @override
  String toString() => '!($operand)';
}

/// Represents the logical conjunction (`AND` or `&&`) of two formulas.
final class And<T> extends Formula<T> {
  final Formula<T> left;
  final Formula<T> right;
  const And(this.left, this.right);

  @override
  String toString() => '($left && $right)';
}

/// Represents the logical disjunction (`OR` or `||`) of two formulas.
final class Or<T> extends Formula<T> {
  final Formula<T> left;
  final Formula<T> right;
  const Or(this.left, this.right);

  @override
  String toString() => '($left || $right)';
}

/// Represents the logical implication (`IMPLIES` or `->`).
final class Implies<T> extends Formula<T> {
  final Formula<T> left;
  final Formula<T> right;
  const Implies(this.left, this.right);

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

  @override
  String toString() => 'F($operand)';
}

/// Represents the temporal operator UNTIL (`U`).
///
/// `left U right` holds at index `i` if there exists an index `k >= i` such that
/// `right` holds at `k`, and for all indices `j` where `i <= j < k`,
/// `left` holds at `j`.
final class Until<T> extends Formula<T> {
  final Formula<T> left;
  final Formula<T> right;
  const Until(this.left, this.right);

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
