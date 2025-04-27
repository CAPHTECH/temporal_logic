## 0.1.0

*   **Initial release.**
*   Introduces Metric Temporal Logic (MTL) capabilities.
*   Defines `TimeInterval` for specifying time bounds.
*   Provides timed temporal operators: `EventuallyTimed`, `AlwaysTimed`, `UntilTimed`.
*   Includes `evaluateMtlTrace` function for evaluating LTL and MTL formulas against timed traces.
*   Depends on `temporal_logic_core` for base formula structures and trace representation. 
