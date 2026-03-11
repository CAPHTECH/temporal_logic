import 'package:temporal_logic_core/temporal_logic_core.dart';

/// Naive recursive implementation of Release that does NOT use duality rewrite.
///
/// p R q at i:
///   if i >= trace.length: true (vacuously)
///   q holds at i, AND (p holds at i OR p R q at i+1)
bool naiveRelease(
    Trace<int> trace, Formula<int> p, Formula<int> q, int startIndex) {
  if (startIndex >= trace.length) return true;
  final qHolds = evaluateTrace(trace, q, startIndex: startIndex).holds;
  if (!qHolds) return false;
  final pHolds = evaluateTrace(trace, p, startIndex: startIndex).holds;
  if (pHolds) return true;
  return naiveRelease(trace, p, q, startIndex + 1);
}

/// Naive recursive implementation of WeakUntil that does NOT use duality rewrite.
///
/// p W q at i:
///   if i >= trace.length: true (vacuously, G(p) on empty suffix)
///   q holds at i: true (U terminates immediately)
///   p holds at i: check p W q at i+1
///   otherwise: false
bool naiveWeakUntil(
    Trace<int> trace, Formula<int> p, Formula<int> q, int startIndex) {
  if (startIndex >= trace.length) return true;
  final qHolds = evaluateTrace(trace, q, startIndex: startIndex).holds;
  if (qHolds) return true;
  final pHolds = evaluateTrace(trace, p, startIndex: startIndex).holds;
  if (!pHolds) return false;
  return naiveWeakUntil(trace, p, q, startIndex + 1);
}
