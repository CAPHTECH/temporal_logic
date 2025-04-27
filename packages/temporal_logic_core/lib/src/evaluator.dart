import 'package:meta/meta.dart';

import 'ast.dart';
import 'timed_value.dart';

/// Represents the result of evaluating a temporal logic formula on a trace.
@immutable
class EvaluationResult {
  /// Whether the formula holds true for the trace.
  final bool holds;

  /// An optional explanation or reason, particularly useful when [holds] is false.
  final String? reason;

  /// Optional index or timestamp related to the evaluation outcome (e.g., where it failed).
  final Duration? relatedTimestamp;
  final int? relatedIndex;

  const EvaluationResult(this.holds, {this.reason, this.relatedTimestamp, this.relatedIndex});

  const EvaluationResult.success() : this(true);
  const EvaluationResult.failure(String this.reason, {this.relatedTimestamp, this.relatedIndex}) : holds = false;

  @override
  String toString() {
    final details = reason != null ? ': $reason' : '';
    final timeInfo = relatedTimestamp != null ? ' at ${relatedTimestamp!.inMilliseconds}ms' 
                    : (relatedIndex != null ? ' at index $relatedIndex' : '');
    return 'EvaluationResult(holds: $holds$details$timeInfo)';
  }
}

/// Evaluates a temporal logic [formula] against a given [trace].
///
/// This is the main entry point for checking if a sequence of timed events
/// satisfies a temporal property.
///
/// [startIndex] specifies the index in the trace from which to start evaluation (usually 0).
EvaluationResult evaluateTrace<T>(Trace<T> trace, Formula<T> formula, {int startIndex = 0}) {
  // Handle base cases and edge conditions
  if (startIndex < 0 || startIndex > trace.length) {
    // It might be valid for startIndex == trace.length for some formulas (e.g., G(p) is true on empty suffix)
    // but generally, starting beyond the trace length implies failure or vacuously true depending on formula.
    // Let the formula-specific logic handle index checks.
    // return EvaluationResult.failure('Start index $startIndex out of bounds for trace length ${trace.length}');
  }
  
  return _evaluateFormula(trace, formula, startIndex);
}

// Internal recursive evaluation function
EvaluationResult _evaluateFormula<T>(Trace<T> trace, Formula<T> formula, int index) {
  // Check bounds for the current evaluation index
  // Many operators need to look ahead, so they handle their own bounds checks relative to `index`.
  // However, accessing trace.events[index] requires index < trace.length.
  if (index < 0) {
     return EvaluationResult.failure("Evaluation index cannot be negative.", relatedIndex: index); // Should not happen with proper calls
  }
  // Note: index == trace.length is a valid state for some operators (e.g., G(p) is true).

  switch (formula) {
    case AtomicProposition<T> p:
      if (index >= trace.length) return EvaluationResult.failure("Atomic proposition evaluated past trace end.", relatedIndex: index);
      final holds = p.pred(trace.events[index].value);
      return EvaluationResult(holds, reason: !holds ? '${p.name ?? "Atomic"} failed' : null, relatedIndex: index, relatedTimestamp: trace.events[index].timestamp);

    case Not<T> f:
      final innerResult = _evaluateFormula(trace, f.operand, index);
      return EvaluationResult(!innerResult.holds, reason: innerResult.holds ? 'Negated formula held' : innerResult.reason, relatedIndex: innerResult.relatedIndex, relatedTimestamp: innerResult.relatedTimestamp);

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
      return EvaluationResult.failure('Both sides of OR failed (${leftResult.reason ?? 'Left'}, ${rightResult.reason ?? 'Right'})', relatedIndex: index); // Index might not be precise

    case Implies<T> f:
      final leftResult = _evaluateFormula(trace, f.left, index);
      if (!leftResult.holds) return const EvaluationResult.success(); // Antecedent is false, implication holds
      final rightResult = _evaluateFormula(trace, f.right, index);
      // Antecedent is true, result depends on consequent
      if (!rightResult.holds) return EvaluationResult.failure('Antecedent held but consequent failed: ${rightResult.reason ?? "Consequent eval failed"}', relatedIndex: rightResult.relatedIndex, relatedTimestamp: rightResult.relatedTimestamp);
      return const EvaluationResult.success();

    case Next<T> f:
       final nextIndex = index + 1;
       if (nextIndex >= trace.length) return EvaluationResult.failure('Next evaluated past trace end.', relatedIndex: index);
       // Evaluate operand at the next index
       return _evaluateFormula(trace, f.operand, nextIndex);

    case Always<T> f:
       for (var k = index; k < trace.length; k++) {
         final stepResult = _evaluateFormula(trace, f.operand, k);
         if (!stepResult.holds) {
           return EvaluationResult.failure('Always failed: ${stepResult.reason ?? "Operand failed"}', relatedIndex: k, relatedTimestamp: trace.events[k].timestamp);
         }
       }
       return const EvaluationResult.success(); // Holds for all steps (or trace suffix was empty)

    case Eventually<T> f:
        if (index >= trace.length) return EvaluationResult.failure('Eventually evaluated on empty trace suffix.', relatedIndex: index); // F(p) is false on empty suffix
        for (var k = index; k < trace.length; k++) {
          final stepResult = _evaluateFormula(trace, f.operand, k);
          if (stepResult.holds) {
            return const EvaluationResult.success(); // Found a state where it holds
          }
        }
        return EvaluationResult.failure('Eventually failed: Operand never held.', relatedIndex: index); // Never held

    case Until<T> f:
        if (index >= trace.length) return EvaluationResult.failure('Until evaluated on empty trace suffix.', relatedIndex: index);
        for (var k = index; k < trace.length; k++) {
           final rightResult = _evaluateFormula(trace, f.right, k);
           if (rightResult.holds) {
               // Check if left held from index up to k-1
               for (var j = index; j < k; j++) {
                   final leftResult = _evaluateFormula(trace, f.left, j);
                   if (!leftResult.holds) {
                       return EvaluationResult.failure('Until failed: Left operand failed before right held (${leftResult.reason ?? "Left failed"})', relatedIndex: j, relatedTimestamp: trace.events[j].timestamp);
                   }
               }
               return const EvaluationResult.success(); // Right held, left held until then
           }
           // Right didn't hold at k, so left must hold at k to continue
           final leftResult = _evaluateFormula(trace, f.left, k);
           if (!leftResult.holds) {
               return EvaluationResult.failure('Until failed: Left operand failed before right held (${leftResult.reason ?? "Left failed"})', relatedIndex: k, relatedTimestamp: trace.events[k].timestamp);
           }
        }
        return EvaluationResult.failure('Until failed: Right operand never held.', relatedIndex: index); // Right never held

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
        throw UnimplementedError('Evaluation logic for formula type ${formula.runtimeType} not implemented in core evaluator.');
  }
} 

/// Evaluates an LTL formula on a given trace.
///
/// LTL semantics typically start evaluation from the beginning of the trace (index 0).
/// Assumes the `eval` method implemented in each [Formula] subclass correctly
/// handles the recursive LTL semantics over the provided trace `t` starting from index `i=0`.
///
/// - [formula]: The LTL formula to evaluate.
/// - [trace]: The sequence of states.
///
/// Returns `true` if the formula holds on the trace, `false` otherwise.
/// Returns `false` if the trace is empty.
bool evaluateLtl<T>(Formula<T> formula, List<T> trace) {
  if (trace.isEmpty) {
    // LTL evaluation on an empty trace is often considered false for most practical formulas,
    // especially those involving Eventually or Until. Returning false aligns with prior behavior.
    return false;
  }
  // Convert the list to a Trace (using default 1ms interval)
  final timedTrace = Trace<T>.fromList(trace);
  // Use the primary trace evaluator, starting at index 0.
  final result = evaluateTrace(timedTrace, formula);
  return result.holds;
} 
