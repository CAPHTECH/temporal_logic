## 0.1.0

* **Initial release.**
* Provides core classes for propositional and LTL formulas (`Formula`, `AtomicProposition`, `And`, `Or`, `Not`, `Implies`, `Next`, `Always`, `Eventually`, `Until`, `WeakUntil`, `Release`).
* Includes `Trace` and `TraceEvent` for representing timed event sequences.
* Provides `evaluateTrace` function for evaluating formulas on traces, returning `EvaluationResult`.
* Includes helper functions for formula construction in `builder.dart` (e.g., `state`, `always`, `eventually`, `until`).
* Basic `LogicalConnectives` extension for formula building (`and`, `or`, `implies`, `not`).
