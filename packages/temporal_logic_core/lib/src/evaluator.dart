import 'ast.dart';
import 'evaluation_result.dart';
import 'evaluator_common.dart';
import 'timed_value.dart';

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
EvaluationResult evaluateTrace<T>(Trace<T> trace, Formula<T> formula,
    {int startIndex = 0}) {
  // Initial checks might be added here, but core logic delegates to _evaluateFormula.
  // Bounds checking related to startIndex is often handled within the specific
  // operator logic as they look into the future of the trace.
  if (startIndex < 0) {
    // Returning failure here as negative indices are always invalid.
    return EvaluationResult.failure(
        'Start index $startIndex cannot be negative.',
        relatedIndex: startIndex);
  }
  // Allow startIndex >= trace.length, as some formulas (like G(p)) can be vacuously true
  // on an empty trace suffix.

  return _evaluateFormula(trace, formula, startIndex);
}

// Internal recursive evaluation function
EvaluationResult _evaluateFormula<T>(
    Trace<T> trace, Formula<T> formula, int index) {
  // Check bounds for the current evaluation index
  // Many operators need to look ahead, so they handle their own bounds checks relative to `index`.
  // However, accessing trace.events[index] requires index < trace.length.
  if (index < 0) {
    return EvaluationResult.failure("Evaluation index cannot be negative.",
        relatedIndex: index); // Should not happen with proper calls
  }
  // Note: index == trace.length is a valid state for some operators (e.g., G(p) is true).

  final result = evaluateCoreFormula(
    trace,
    formula,
    index,
    (nestedFormula, nestedIndex) =>
        _evaluateFormula(trace, nestedFormula, nestedIndex),
  );
  if (result != null) {
    return result;
  }

  throw UnimplementedError(
      'Evaluation logic for formula type ${formula.runtimeType} not implemented in core evaluator.');
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
