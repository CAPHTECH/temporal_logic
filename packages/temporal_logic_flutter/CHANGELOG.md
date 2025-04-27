## 0.0.1-dev

*   **Initial development release.**
*   Provides basic integration with Flutter for temporal logic checking.
*   Introduces `TraceRecorder` for capturing state changes over time.
*   Includes Stream-based checkers: `StreamLtlChecker`, `StreamMtlChecker`, `StreamSustainedStateChecker`.
*   Provides example Widgets for visualizing check status: `LtlCheckerWidget`, `MtlCheckerWidget`, `SustainedStateCheckerWidget`.
*   Defines `CheckStatus` enum.
*   Includes `Matchers` for defining state properties.
*   Depends on `temporal_logic_core` and `temporal_logic_mtl`. 
