# Temporal Logic for Flutter & Dart

This repository contains a collection of Dart packages for working with various forms of temporal logic, primarily aimed at verification and specification within Flutter applications, but also usable in pure Dart environments.

## Packages

*   **`packages/temporal_logic_core`**: Provides the fundamental interfaces and structures for propositional logic and basic trace representations.
*   **`packages/temporal_logic_mtl`**: Implements Metric Temporal Logic (MTL), allowing specifications over timed traces with quantitative time constraints.
*   **`packages/temporal_logic_flutter`**: Integrates temporal logic concepts with Flutter, potentially offering widgets or utilities for visualizing or checking properties against application state changes over time (details TBD).

## Examples

*   **`examples/counter_ltl`**: A simple Flutter counter example demonstrating Linear Temporal Logic (LTL) concepts (or intended to).
*   **`examples/snackbar_mtl`**: A Flutter example showcasing the use of Metric Temporal Logic (MTL) for specifying behavior related to Snackbars.

## Getting Started

1.  **Ensure Flutter is installed:** Follow the official [Flutter installation guide](https://docs.flutter.dev/get-started/install).
2.  **Install FVM (Optional but Recommended):** If you prefer using FVM to manage Flutter versions, install it following the [FVM documentation](https://fvm.app/docs/getting_started/installation). This project is configured to use FVM.
3.  **Clone the repository:**
    ```bash
    git clone https://github.com/your-username/temporal_logic_flutter.git # Replace with actual repo URL
    cd temporal_logic_flutter
    ```
4.  **Get dependencies:**
    ```bash
    # If using FVM
    fvm flutter pub get

    # If using system Flutter
    flutter pub get
    ```
5.  **Run tests (Optional):** Navigate to individual package directories (e.g., `packages/temporal_logic_core`) and run tests:
    ```bash
    # If using FVM
    cd packages/temporal_logic_core
    fvm flutter test

    # If using system Flutter
    cd packages/temporal_logic_core
    flutter test
    ```

## Contributing

Contributions are welcome! Please follow these general guidelines:

1.  **Fork the repository** and create your branch from `main`.
2.  **Make your changes.** Ensure code is formatted (`dart format .`) and passes analysis (`flutter analyze`).
3.  **Add tests** for any new features or bug fixes.
4.  **Ensure all tests pass** within the relevant package(s).
5.  **Create a pull request** with a clear description of your changes.

Please note that this project adheres to a [Contributor Covenant code of conduct](https://www.contributor-covenant.org/). By participating, you are expected to uphold this code.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details. 
