/// Base class for all temporal logic formulas.
///
/// Represents a proposition or a combination of propositions using logical
/// or temporal operators. Subclasses define specific operators like [And],
/// [Or], [Not], [Next], [Always], [Eventually], etc., or represent atomic
/// conditions like [AtomicProposition].
///
/// The type parameter [T] indicates the type of the state object found within
/// a [TraceEvent] in a [Trace]. Formulas are evaluated against these traces.
///
/// Formulas are typically immutable and represent the structure of a logical
/// assertion.
///
/// See also:
/// - `evaluateTrace` in `evaluator.dart` for the primary evaluation logic.
/// - [AtomicProposition] for basic conditions.
/// - [And], [Or], [Not], [Implies] for boolean logic.
/// - [Next], [Always], [Eventually], [Until], [WeakUntil], [Release] for LTL operators.
/// - (In `temporal_logic_mtl`) `EventuallyTimed`, `AlwaysTimed`, `UntilTimed` for MTL operators.
/*sealed*/ abstract class Formula<T> {
  // Made abstract as it has no direct instances
  const Formula();

  // Evaluation is primarily handled by the `evaluateTrace` function
  // defined in `evaluator.dart`, which recursively calls helper methods based
  // on the specific formula type.

  /// Returns a string representation of the formula, useful for debugging.
  @override
  String toString();

  // --- Common Logical Connective Builders ---

  /// Creates a logical conjunction (AND) with another [formula].
  /// `this && formula`
  And<T> and(Formula<T> formula) => And<T>(this, formula);

  /// Creates a logical disjunction (OR) with another [formula].
  /// `this || formula`
  Or<T> or(Formula<T> formula) => Or<T>(this, formula);

  /// Creates a logical implication (IMPLIES) with another [formula].
  /// `this -> formula`
  Implies<T> implies(Formula<T> formula) => Implies<T>(this, formula);

  /// Creates a logical negation (NOT) of this formula.
  /// `!this`
  Not<T> not() => Not<T>(this);

  // --- Common Temporal Operator Builders ---

  /// Creates a NEXT operator for this formula.
  /// `X(this)`
  Next<T> next() => Next<T>(this);

  /// Creates an ALWAYS (Globally) operator for this formula.
  /// `G(this)`
  Always<T> always() => Always<T>(this);

  /// Creates an EVENTUALLY (Finally) operator for this formula.
  /// `F(this)`
  Eventually<T> eventually() => Eventually<T>(this);

  /// Creates an UNTIL operator with another [formula].
  /// `this U formula`
  Until<T> until(Formula<T> formula) => Until<T>(this, formula);

  /// Creates a WEAK UNTIL operator with another [formula].
  /// `this W formula`
  WeakUntil<T> weakUntil(Formula<T> formula) => WeakUntil<T>(this, formula);

  /// Creates a RELEASE operator with another [formula].
  /// `this R formula`
  Release<T> release(Formula<T> formula) => Release<T>(this, formula);
}

/// Represents an atomic proposition, a basic condition evaluated on a state.
///
/// This is the simplest form of formula. It holds a [predicate] function
/// that takes a state of type [T] and returns `true` if the proposition holds
/// for that state, and `false` otherwise.
///
/// Example:
/// ```dart
/// // Checks if an integer state is greater than 10.
/// final isGreaterThan10 = AtomicProposition<int>((state) => state > 10);
/// ```
///
/// The optional [name] provides a human-readable identifier for the proposition,
/// used in `toString()` and potentially in evaluation results.
final class AtomicProposition<T> extends Formula<T> {
  /// The condition to evaluate on a state.
  final bool Function(T state) predicate;

  /// A descriptive name for the proposition (optional, used for `toString`).
  final String? name;

  /// Creates an atomic proposition with a given [predicate] and optional [name].
  const AtomicProposition(this.predicate, {this.name});

  @override
  String toString() => name ?? predicate.toString();
}

/// Represents the logical negation (NOT) of a formula.
///
/// Formula: `!operand`
///
/// Evaluates to `true` at a time point if the [operand] formula evaluates
/// to `false` at that same time point.
final class Not<T> extends Formula<T> {
  /// The formula being negated.
  final Formula<T> operand;

  /// Creates a negation formula.
  const Not(this.operand);

  @override
  String toString() => '!($operand)';
}

/// Represents the logical conjunction (AND) of two formulas.
///
/// Formula: `left && right`
///
/// Evaluates to `true` at a time point if both the [left] and [right]
/// formulas evaluate to `true` at that same time point.
final class And<T> extends Formula<T> {
  /// The left-hand side formula.
  final Formula<T> left;

  /// The right-hand side formula.
  final Formula<T> right;

  /// Creates a conjunction formula.
  const And(this.left, this.right);

  @override
  String toString() => '($left && $right)';
}

/// Represents the logical disjunction (OR) of two formulas.
///
/// Formula: `left || right`
///
/// Evaluates to `true` at a time point if at least one of the [left] or
/// [right] formulas evaluates to `true` at that same time point.
final class Or<T> extends Formula<T> {
  /// The left-hand side formula.
  final Formula<T> left;

  /// The right-hand side formula.
  final Formula<T> right;

  /// Creates a disjunction formula.
  const Or(this.left, this.right);

  @override
  String toString() => '($left || $right)';
}

/// Represents the logical implication (IMPLIES) of two formulas.
///
/// Formula: `left -> right` (Equivalent to `!left || right`)
///
/// Evaluates to `true` at a time point if either the [left] formula is
/// `false` or the [right] formula is `true` (or both) at that time point.
final class Implies<T> extends Formula<T> {
  /// The antecedent (left-hand side).
  final Formula<T> left;

  /// The consequent (right-hand side).
  final Formula<T> right;

  /// Creates an implication formula.
  const Implies(this.left, this.right);

  @override
  String toString() => '($left -> $right)';
}

/// Represents the temporal operator NEXT (`X` or `○`).
///
/// Formula: `X operand`
///
/// Evaluates to `true` at time `t` if the [operand] formula holds at the
/// next time point `t+1`. Requires the trace to have a state at `t+1`.
/// If time `t` is the last point in the trace, `X operand` is `false`.
///
/// **Evaluation Details:**
/// - If `i+1` is beyond the end of the trace, `Next` evaluates to `false`.
final class Next<T> extends Formula<T> {
  /// The formula that must hold at the next time step.
  final Formula<T> operand;

  /// Creates a Next formula.
  const Next(this.operand);

  @override
  String toString() => 'X($operand)';
}

/// Represents the temporal operator ALWAYS (`G` or `□`, also known as Globally).
///
/// Formula: `G operand` or `[] operand`
///
/// Evaluates to `true` at time `t` if the [operand] formula holds at the
/// current time `t` and all future time points in the trace.
///
/// **Evaluation Details:**
/// - If evaluated on an empty suffix of the trace (i.e., `i >= trace.length`),
///   `Always` evaluates to `true` (vacuously true).
final class Always<T> extends Formula<T> {
  /// The formula that must hold globally.
  final Formula<T> operand;

  /// Creates an Always formula.
  const Always(this.operand);

  @override
  String toString() => 'G($operand)';
}

/// Represents the temporal operator EVENTUALLY (`F` or `◇`, also known as Finally).
///
/// Formula: `F operand` or `<> operand`
///
/// Evaluates to `true` at time `t` if the [operand] formula holds at the
/// current time `t` or at some future time point in the trace.
///
/// **Evaluation Details:**
/// - If evaluated on an empty suffix of the trace (i.e., `i >= trace.length`),
///   `Eventually` evaluates to `false`.
final class Eventually<T> extends Formula<T> {
  /// The formula that must eventually hold.
  final Formula<T> operand;

  /// Creates an Eventually formula.
  const Eventually(this.operand);

  @override
  String toString() => 'F($operand)';
}

/// Represents the temporal operator UNTIL (`U`).
///
/// Formula: `left U right`
///
/// Evaluates to `true` at time `t` if the [right] formula holds at time `t`
/// or at some future time `k >= t`, and the [left] formula holds at all
/// time points from `t` up to (but not necessarily including) `k`.
/// This is the "strong" until, requiring [right] to eventually become true.
///
/// **Evaluation Details:**
/// - If the [right] operand never holds in the future (from index `i` onwards),
///   `Until` evaluates to `false`.
final class Until<T> extends Formula<T> {
  /// The formula that must hold until [right] becomes true.
  final Formula<T> left;

  /// The formula that must eventually become true.
  final Formula<T> right;

  /// Creates an Until formula.
  const Until(this.left, this.right);

  @override
  String toString() => '($left U $right)';
}

/// Represents the temporal operator WEAK UNTIL (`W`).
///
/// Formula: `left W right` (Equivalent to `(left U right) || G(left)`)
///
/// Evaluates to `true` at time `t` if either the [left] formula holds
/// indefinitely from `t` onwards, OR if the strong `left U right` condition
/// holds (i.e., [right] eventually becomes true, and [left] holds until then).
/// Unlike [Until], [right] is not required to eventually become true.
///
/// **Evaluation Details:**
/// - This evaluator implements `left W right` using its equivalence:
///   `G(left) || (left U right)`.
final class WeakUntil<T> extends Formula<T> {
  /// The formula that must hold until/unless [right] becomes true.
  final Formula<T> left;

  /// The formula that may eventually become true.
  final Formula<T> right;

  /// Creates a Weak Until formula.
  const WeakUntil(this.left, this.right);

  @override
  String toString() => '($left W $right)';
}

/// Represents the temporal operator RELEASE (`R`).
///
/// Formula: `left R right` (Equivalent to `!( (!left) U (!right) )`)
///
/// Evaluates to `true` at time `t` if the [right] formula holds at time `t`
/// and continues to hold up to and including the point where [left]
/// first becomes true. If [left] never becomes true, [right] must hold
/// indefinitely from `t` onwards.
///
/// Intuitively, [right] must always be true *unless* [left] "releases" it
/// by becoming true at some point (at which point [right] must also be true).
///
/// **Evaluation Details:**
/// - `Release` is the dual of `Until`.
/// - This evaluator implements `left R right` using its equivalence:
///   `!(!left U !right)`.
final class Release<T> extends Formula<T> {
  /// The formula that can "release" the condition.
  final Formula<T> left;

  /// The formula that must hold until (and including) the release.
  final Formula<T> right;

  /// Creates a Release formula.
  const Release(this.left, this.right);

  @override
  String toString() => '($left R $right)';
}
