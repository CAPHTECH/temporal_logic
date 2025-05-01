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
