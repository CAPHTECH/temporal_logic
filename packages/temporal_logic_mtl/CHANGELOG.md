## Unreleased

* **BREAKING**: `checkEventuallyWithin`、`checkAlwaysWithin`、`checkUntilWithin` を削除しました。代わりに `evaluateMtlTrace` と timed formula を使ってください。
* **API**: `temporal_logic_mtl.dart` は compatibility facade を経由せず、timed evaluator と timed AST を直接公開する形に整理しました。
* **TEST**: 公開 export の回帰を固定する `public_api_exports_test.dart` を追加しました。
* **DOCS**: `MIGRATION.md` に旧来ヘルパーからの移行手順を追加しました。

## 0.2.0

* **FEAT**: Implemented timed `Release` (`R_I`) operator.
* **FEAT**: Implemented timed `WeakUntil` (`W_I`) operator.
* **FEAT**: Added tests for `ReleaseTimed` and `WeakUntilTimed` operators.
* **FEAT**: Added comprehensive tests for boundary conditions in timed operators.
* **FEAT**: Added tests for nested MTL formulas.
* **FIX**: Refined evaluation logic for timed operators (`F_I`, `G_I`, `U_I`) for correctness and edge cases.
* **TEST**: Added tests for core `TimedValue`, `TraceEvent`, and `Trace` classes (`temporal_logic_core`).

## 0.1.0

* **Initial release.**
* Introduces Metric Temporal Logic (MTL) capabilities.
* Defines `TimeInterval` for specifying time bounds.
* Provides timed temporal operators: `EventuallyTimed`, `AlwaysTimed`, `UntilTimed`.
* Includes `evaluateMtlTrace` function for evaluating LTL and MTL formulas against timed traces.
* Depends on `temporal_logic_core` for base formula structures and trace representation.
