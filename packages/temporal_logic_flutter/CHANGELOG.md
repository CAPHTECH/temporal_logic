## 0.1.0

* **Initial release.**
* Initial release of the `temporal_logic_flutter` package.
* Provides Flutter integration (TraceRecorder, Widgets, Matchers) for temporal logic.
* Provides basic integration with Flutter for temporal logic checking.
* Introduces `TraceRecorder` for capturing state changes over time.
* Includes Stream-based checkers: `StreamLtlChecker`, `StreamMtlChecker`, `StreamSustainedStateChecker`.
* Provides example Widgets for visualizing check status: `LtlCheckerWidget`, `MtlCheckerWidget`, `SustainedStateCheckerWidget`.
* Defines `CheckStatus` enum.
* Includes `Matchers` for defining state properties.
* Depends on `temporal_logic_core` and `temporal_logic_mtl`.

## 0.1.1

* **CHORE**: Updated dependency constraints to allow `temporal_logic_mtl: ^0.2.0`.
