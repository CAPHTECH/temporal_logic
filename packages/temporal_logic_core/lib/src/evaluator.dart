import 'package:meta/meta.dart';

import 'ast.dart';
import 'timed_value.dart';

/// Represents the outcome of evaluating a [Formula] against a [Trace].
///
/// This class encapsulates the result of checking if a temporal logic formula
/// holds true for a given sequence of timed events.
///
/// It contains not only whether the formula [holds] but also optional diagnostic
/// information like a failure [reason] and the specific time ([relatedTimestamp])
/// or index ([relatedIndex]) within the trace that is most pertinent to the result,
/// especially in case of failure.
///
/// This class is immutable.
@immutable
class EvaluationResult {
  /// `true` if the formula holds for the trace (or sub-trace beginning at the
  /// evaluated start index), `false` otherwise.
  final bool holds;

  /// An optional human-readable explanation for the evaluation outcome.
  ///
  /// This is particularly useful when [holds] is `false`, providing details about
  /// why the formula failed (e.g., which sub-formula failed at what point,
  /// or a boundary condition was met).
  ///
  /// Example: "Atomic proposition 'is_loading' failed", "Eventually failed: Operand never held."
  final String? reason;

  /// The timestamp within the trace that is most relevant to this result.
  ///
  /// For failures, this often indicates the timestamp of the [TraceEvent]
  /// where the violation occurred.
  /// For successes, its meaning might vary depending on the operator.
  final Duration? relatedTimestamp;

  /// The index within the trace's event list that is most relevant to this result.
  ///
  /// Similar to [relatedTimestamp], this often indicates the index of the
  /// [TraceEvent] where a failure occurred.
  final int? relatedIndex;

  /// Creates a detailed evaluation result.
  ///
  /// - [holds]: Whether the formula was satisfied.
  /// - [reason]: Optional explanation, especially for failures.
  /// - [relatedTimestamp]: Optional timestamp related to the outcome.
  /// - [relatedIndex]: Optional index related to the outcome.
  const EvaluationResult(this.holds, {this.reason, this.relatedTimestamp, this.relatedIndex});

  /// Creates a successful evaluation result (`holds` is `true`).
  /// Provides minimal information, suitable when only success/failure matters.
  const EvaluationResult.success() : this(true);

  /// Creates a failure evaluation result (`holds` is `false`).
  /// Requires a [reason] explaining the failure.
  /// Optionally includes [relatedTimestamp] and [relatedIndex] for context.
  const EvaluationResult.failure(String this.reason, {this.relatedTimestamp, this.relatedIndex}) : holds = false;

  /// Provides a concise string representation of the result.
  /// Includes the reason and location (time/index) if available.
  /// Example: `EvaluationResult(holds: false: Always failed: Operand failed at 150ms)`
  @override
  String toString() {
    final details = reason != null ? ': $reason' : '';
    final timeInfo = relatedTimestamp != null
        ? ' at ${relatedTimestamp!.inMilliseconds}ms'
        : (relatedIndex != null ? ' at index $relatedIndex' : '');
    return 'EvaluationResult(holds: $holds$details$timeInfo)';
  }
}

/// Evaluates a temporal logic [formula] against a given timed [trace]
/// starting from a specific [startIndex].
///
/// This function acts as the main entry point for evaluating any [Formula]
/// (including basic boolean logic, LTL operators, and potentially extended
/// operators like those in MTL if handled by subclasses) against a formal [Trace].
/// It performs initial checks and delegates the core recursive logic to
/// [_evaluateFormula].
///
/// The evaluation semantic is typically point-based: the result indicates whether
/// the [formula] holds true *at* the [startIndex] within the [trace]. Temporal
/// operators inherently look at the suffix of the trace starting from [startIndex].
///
/// **Example Semantics:**
/// - `evaluateTrace(trace, Always(p), startIndex: 2)` checks if `p` holds at
///   indices 2, 3, 4, ... of the trace.
/// - `evaluateTrace(trace, Eventually(q), startIndex: 5)` checks if `q` holds
///   at index 5 or any subsequent index.
///
/// **Parameters:**
/// - [trace]: The sequence of timed states/events ([TraceEvent]) to evaluate
///   against. Must have monotonically non-decreasing timestamps.
/// - [formula]: The temporal logic formula ([Formula]) to evaluate.
/// - [startIndex]: The 0-based index in `trace.events` from which to begin
///   evaluation. Defaults to 0 (evaluate from the start of the trace). Must be
///   non-negative.
///
/// **Returns:**
///   An [EvaluationResult] object containing:
///   - `holds`: Boolean indicating if the formula is satisfied at [startIndex].
///   - `reason`: Optional explanation, especially if `holds` is false.
///   - `relatedIndex` / `relatedTimestamp`: Optional context about the specific
///     point in the trace relevant to the result (e.g., where a violation occurred).
///
/// **Handling of Trace Boundaries:**
/// - A negative [startIndex] immediately results in a failure.
/// - Evaluating at or beyond the end of the trace (`startIndex >= trace.length`)
///   is permissible. The outcome depends on the specific formula:
///     - `Always(f)` is vacuously `true` on an empty suffix.
///     - `Eventually(f)` is `false` on an empty suffix.
///     - `AtomicProposition(p)` fails because there is no state to evaluate.
///     - Other operators are handled recursively.
EvaluationResult evaluateTrace<T>(Trace<T> trace, Formula<T> formula, {int startIndex = 0}) {
  // Initial checks might be added here, but core logic delegates to _evaluateFormula.
  // Bounds checking related to startIndex is often handled within the specific
  // operator logic as they look into the future of the trace.
  if (startIndex < 0) {
    // Returning failure here as negative indices are always invalid.
    return EvaluationResult.failure('Start index $startIndex cannot be negative.', relatedIndex: startIndex);
  }
  // Allow startIndex >= trace.length, as some formulas (like G(p)) can be vacuously true
  // on an empty trace suffix.

  return _evaluateFormula(trace, formula, startIndex);
}

// Internal recursive evaluation function
EvaluationResult _evaluateFormula<T>(Trace<T> trace, Formula<T> formula, int index) {
  // Check bounds for the current evaluation index
  // Many operators need to look ahead, so they handle their own bounds checks relative to `index`.
  // However, accessing trace.events[index] requires index < trace.length.
  if (index < 0) {
    return EvaluationResult.failure("Evaluation index cannot be negative.",
        relatedIndex: index); // Should not happen with proper calls
  }
  // Note: index == trace.length is a valid state for some operators (e.g., G(p) is true).

  switch (formula) {
    case AtomicProposition<T> p:
      if (index >= trace.length)
        return EvaluationResult.failure("Atomic proposition evaluated past trace end.", relatedIndex: index);
      final holds = p.predicate(trace.events[index].value);
      return EvaluationResult(holds,
          reason: !holds ? '${p.name ?? "Atomic"} failed' : null,
          relatedIndex: index,
          relatedTimestamp: trace.events[index].timestamp);

    case Not<T> f:
      final innerResult = _evaluateFormula(trace, f.operand, index);
      return EvaluationResult(!innerResult.holds,
          reason: innerResult.holds ? 'Negated formula held' : innerResult.reason,
          relatedIndex: innerResult.relatedIndex,
          relatedTimestamp: innerResult.relatedTimestamp);

    case And<T> f:
      final leftResult = _evaluateFormula(trace, f.left, index);
      if (!leftResult.holds) return leftResult; // Short-circuit
      final rightResult = _evaluateFormula(trace, f.right, index);
      // If left held but right failed, return right's failure reason
      if (!rightResult.holds) return rightResult;
      return const EvaluationResult.success(); // Both held

    case Or<T> f:
      final leftResult = _evaluateFormula(trace, f.left, index);
      if (leftResult.holds) return const EvaluationResult.success(); // Short-circuit
      final rightResult = _evaluateFormula(trace, f.right, index);
      // If left failed and right held, return success.
      if (rightResult.holds) return const EvaluationResult.success();
      // Both failed. Return combined reason or prioritize one?
      return EvaluationResult.failure(
          'Both sides of OR failed (${leftResult.reason ?? 'Left'}, ${rightResult.reason ?? 'Right'})',
          relatedIndex: index); // Index might not be precise

    case Implies<T> f:
      final leftResult = _evaluateFormula(trace, f.left, index);
      if (!leftResult.holds) return const EvaluationResult.success(); // Antecedent is false, implication holds
      final rightResult = _evaluateFormula(trace, f.right, index);
      // Antecedent is true, result depends on consequent
      if (!rightResult.holds)
        return EvaluationResult.failure(
            'Antecedent held but consequent failed: ${rightResult.reason ?? "Consequent eval failed"}',
            relatedIndex: rightResult.relatedIndex,
            relatedTimestamp: rightResult.relatedTimestamp);
      return const EvaluationResult.success();

    case Next<T> f:
      final nextIndex = index + 1;
      if (nextIndex >= trace.length)
        return EvaluationResult.failure('Next evaluated past trace end.', relatedIndex: index);
      // Evaluate operand at the next index
      return _evaluateFormula(trace, f.operand, nextIndex);

    case Always<T> f:
      for (var k = index; k < trace.length; k++) {
        final stepResult = _evaluateFormula(trace, f.operand, k);
        if (!stepResult.holds) {
          return EvaluationResult.failure('Always failed: ${stepResult.reason ?? "Operand failed"}',
              relatedIndex: k, relatedTimestamp: trace.events[k].timestamp);
        }
      }
      return const EvaluationResult.success(); // Holds for all steps (or trace suffix was empty)

    case Eventually<T> f:
      if (index >= trace.length)
        return EvaluationResult.failure('Eventually evaluated on empty trace suffix.',
            relatedIndex: index); // F(p) is false on empty suffix
      for (var k = index; k < trace.length; k++) {
        final stepResult = _evaluateFormula(trace, f.operand, k);
        if (stepResult.holds) {
          return const EvaluationResult.success(); // Found a state where it holds
        }
      }
      return EvaluationResult.failure('Eventually failed: Operand never held.', relatedIndex: index); // Never held

    case Until<T> f:
      if (index >= trace.length)
        return EvaluationResult.failure('Until evaluated on empty trace suffix.', relatedIndex: index);
      for (var k = index; k < trace.length; k++) {
        final rightResult = _evaluateFormula(trace, f.right, k);
        if (rightResult.holds) {
          // Check if left held from index up to k-1
          for (var j = index; j < k; j++) {
            final leftResult = _evaluateFormula(trace, f.left, j);
            if (!leftResult.holds) {
              return EvaluationResult.failure(
                  'Until failed: Left operand failed before right held (${leftResult.reason ?? "Left failed"})',
                  relatedIndex: j,
                  relatedTimestamp: trace.events[j].timestamp);
            }
          }
          return const EvaluationResult.success(); // Right held, left held until then
        }
        // Right didn't hold at k, so left must hold at k to continue
        final leftResult = _evaluateFormula(trace, f.left, k);
        if (!leftResult.holds) {
          return EvaluationResult.failure(
              'Until failed: Left operand failed before right held (${leftResult.reason ?? "Left failed"})',
              relatedIndex: k,
              relatedTimestamp: trace.events[k].timestamp);
        }
      }
      return EvaluationResult.failure('Until failed: Right operand never held.',
          relatedIndex: index); // Right never held

    // --- Default LTL definitions for W and R (can be overridden for efficiency) ---
    case WeakUntil<T> f: // Defined as G(left) or (left U right)
      final gLeft = Always<T>(f.left);
      final lUr = Until<T>(f.left, f.right);
      return _evaluateFormula(trace, Or<T>(gLeft, lUr), index);

    case Release<T> f: // Defined as !(!left U !right)
      final notLeft = Not<T>(f.left);
      final notRight = Not<T>(f.right);
      final notL_U_notR = Until<T>(notLeft, notRight);
      return _evaluateFormula(trace, Not<T>(notL_U_notR), index);

    default: // Add default case to satisfy non-nullable return type with unsealed Formula
      throw UnimplementedError(
          'Evaluation logic for formula type ${formula.runtimeType} not implemented in core evaluator.');
  }
}

/// Evaluates a classic LTL (Linear Temporal Logic) formula on a given list of states.
///
/// This is a convenience wrapper around [evaluateTrace] for scenarios where only
/// the *sequence* of states matters, and explicit timing information is not
/// required or available. It simplifies LTL evaluation by automatically converting
/// the input list into a [Trace] with default (e.g., 1ms) intervals between states.
///
/// Use this function for pure LTL checking without time constraints.
///
/// **Behavior:**
/// 1. Checks if the input [traceStates] list is empty. If so, returns `false`
///    (common convention for LTL on empty traces, though `Always` is technically true).
/// 2. Creates a `Trace<T>` using `Trace.fromList`, assigning incremental timestamps.
/// 3. Calls the main [evaluateTrace] function, starting the evaluation from the
///    beginning of this generated trace (`startIndex = 0`).
/// 4. Returns only the boolean `holds` field from the [EvaluationResult].
///
/// **Limitations:**
/// - **No Time Semantics:** This function discards any real-world timing. Formulas
///   involving specific time bounds (like those in Metric Temporal Logic) cannot
///   be correctly evaluated using this function.
/// - **Empty Trace Handling:** Returns `false` for empty traces, which might differ
///   from the strict mathematical semantics for operators like `Always` (which is
///   vacuously true on empty traces). This behavior aligns with practical
///   expectations where properties are usually checked on non-empty executions.
///
/// Parameters:
///   - [formula]: The LTL [Formula] to evaluate.
///   - [traceStates]: The ordered sequence of states (type [T]).
///
/// Returns:
///   `true` if the [formula] holds for the sequence according to standard LTL
///   semantics evaluated from the start; `false` otherwise (including for empty
///   [traceStates]).
bool evaluateLtl<T>(Formula<T> formula, List<T> traceStates) {
  if (traceStates.isEmpty) {
    // LTL evaluation on an empty trace is often considered false for most practical formulas,
    // especially those involving Eventually or Until. Returning false aligns with prior behavior.
    return false;
  }
  // Convert the list to a Trace (using default 1ms interval)
  final timedTrace = Trace<T>.fromList(traceStates);
  // Use the primary trace evaluator, starting at index 0.
  final result = evaluateTrace(timedTrace, formula);
  return result.holds;
}
