## Unreleased

* **API**: `temporal_logic_core.dart` を stable public entry point として明文化しました。
* **TEST**: 公開 export の回帰を固定する `public_api_exports_test.dart` を追加しました。

## 0.1.0

* **Initial release.**
* Provides core classes for propositional and LTL formulas (`Formula`, `AtomicProposition`, `And`, `Or`, `Not`, `Implies`, `Next`, `Always`, `Eventually`, `Until`, `WeakUntil`, `Release`).
* Includes `Trace` and `TraceEvent` for representing timed event sequences.
* Provides `evaluateTrace` function for evaluating formulas on traces, returning `EvaluationResult`.
* Includes helper functions for formula construction in `builder.dart` (e.g., `state`, `always`, `eventually`, `until`).
* Basic `LogicalConnectives` extension for formula building (`and`, `or`, `implies`, `not`).
