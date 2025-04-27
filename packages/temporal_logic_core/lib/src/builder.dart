import 'ast.dart';

// --- Atomic Propositions ---

/// Creates an atomic proposition based on a state predicate.
/// Alias for constructing an [AtomicProposition] formula.
AtomicProposition<T> state<T>(bool Function(T state) pred, {String? name}) =>
    AtomicProposition<T>(pred, name: name);

/// Creates an atomic proposition [Formula] based on an event predicate.
///
/// This is functionally identical to [state] but can improve readability
/// by signaling that the predicate relates to an event occurring *at* this state/time,
/// rather than a condition holding *over* a state. Both create an [AtomicProposition].
/// Example: `event<MyEvents>((e) => e == MyEvents.buttonClicked)`
AtomicProposition<T> event<T>(bool Function(T stateOrEvent) predicate,
    {String? name}) {
  // Semantically, an event check is just a state check at a specific time.
  return AtomicProposition<T>(predicate, name: name);
}

// --- Boolean Connectives ---
// And, Or, Not, Implies are typically created using extension methods
// defined in temporal_logic_flutter/lib/src/ltl_helpers.dart or similar.
// We don't need explicit builder functions here for those.

// --- Temporal Operator Builders (Unary) ---

/// Creates a NEXT (`X`) formula.
///
/// Example: `next(state((s) => s.isReady))`
Next<T> next<T>(Formula<T> operand) {
  return Next<T>(operand);
}

/// Creates an ALWAYS (`G`) formula.
///
/// Example: `always(state((s) => s.isValid))`
Always<T> always<T>(Formula<T> operand) {
  return Always<T>(operand);
}

/// Creates an EVENTUALLY (`F`) formula.
///
/// Example: `eventually(state((s) => s.isComplete))`
Eventually<T> eventually<T>(Formula<T> operand) {
  return Eventually<T>(operand);
}

// --- Temporal Operator Builders (Binary) ---

/// Creates an UNTIL (`U`) formula.
///
/// Example: `state((s)=>s.requesting).until(state((s)=>s.granted))`
Until<T> until<T>(Formula<T> left, Formula<T> right) {
  return Until<T>(left, right);
}

/// Creates a WEAK UNTIL (`W`) formula.
///
/// Example: `state((s)=>s.trying).weakUntil(state((s)=>s.succeeded))`
WeakUntil<T> weakUntil<T>(Formula<T> left, Formula<T> right) {
  return WeakUntil<T>(left, right);
}

/// Creates a RELEASE (`R`) formula.
///
/// Example: `state((s)=>s.errorOccurred).release(state((s)=>s.recovering))`
Release<T> release<T>(Formula<T> left, Formula<T> right) {
  return Release<T>(left, right);
}
