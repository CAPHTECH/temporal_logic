# Login Flow LTL Example

This example demonstrates how to use the `temporal_logic_flutter` and `temporal_logic_core` packages to verify the behavior of a simple login flow in a Flutter application using Linear Temporal Logic (LTL).

It showcases how LTL can specify and verify properties over sequences of application states, particularly useful for detecting subtle bugs related to state transitions that might be missed by traditional widget tests focusing only on the final state.

## Application Overview

The application simulates a basic login process with the following screens/states:

1. **Login Screen:** User enters an email and taps "Login".
2. **Loading Screen:** Shown briefly while simulating a network request.
3. **Home Screen:** Shown upon successful login (e.g., email contains '@').
4. **Error Screen:** Shown upon failed login (e.g., invalid email format).

State management is handled using `flutter_riverpod`.

## Temporal Logic Integration

Instead of instrumenting the application code itself, this example uses an **external recording** approach within the widget tests (`test/widget_test.dart`):

1. **`AppSnap`:** An immutable class (`AppSnap`) is defined in `lib/main.dart` to capture the relevant snapshot of the application state at any point in time (e.g., `isLoading`, `isOnHomeScreen`, `hasError`, `loginClicked`).
2. **`TraceRecorder`:** A `TraceRecorder<AppSnap>` is initialized within the test.
3. **`ProviderContainer.listen`:** The test uses Riverpod's `container.listen` to observe changes in the application's state (`appStateProvider`). Whenever the state changes, the listener callback creates an `AppSnap` from the new state and records it using `recorder.record()`.
4. **LTL Formulas:** LTL formulas are defined in the test to express the expected temporal properties of the login flow. Key examples include:
    * **Successful Login:** `G(loginClicked -> (X loading && F home && G !error))`
        * Globally (G), if login is clicked, then in the next (X) state it's loading, AND eventually (F) the home state is reached, AND globally (G) afterwards the error state is never (!) true.
    * **Failed Login:** `G(loginClicked -> F error)`
        * Globally (G), if login is clicked, then eventually (F) the error state is reached.
    * **No Flicker (Safety):** `G(loading -> G !error)`
        * Globally (G), if the loading state is entered, then globally (G) afterwards the error state is never (!) true.
5. **`satisfiesLtl` Matcher:** The tests use the `expect(trace, satisfiesLtl(formula))` or `expect(trace, isNot(satisfiesLtl(formula)))` matcher to verify if the recorded trace conforms to the defined LTL specifications.

## Detecting Transient Bugs (Flicker Example)

This example deliberately includes a simulated "flicker" bug in `lib/main.dart`'s `login` method: on a successful login, the app briefly transitions to the `ErrorScreen` state before correcting itself and showing the `HomeScreen`.

The tests demonstrate:

* **LTL Detection:** The test `Successful login should NOT flicker through error state` uses formulas like `G(loading -> G !error)`. This formula evaluates to `false` because the trace *does* contain an error state after loading due to the flicker. The test asserts `isNot(satisfiesLtl(formula))` and therefore **passes**, correctly identifying the specification violation (the flicker). The original success formula test `Successful login flow ... (EXPECTED TO FAIL...)` also correctly fails its assertion `isNot(satisfiesLtl(formula))` because the `G !error` part is violated.
* **Standard Test Limitation:** The test `Standard test passes for successful login (misses flicker)` uses typical `expect(find.byType(HomeScreen), findsOneWidget);` etc., *after* `tester.pumpAndSettle()`. Because `pumpAndSettle` waits for all state changes to complete, the transient error state is gone by the time the assertions run. This test **passes** despite the flicker bug, highlighting how temporal logic can catch issues missed by final-state checks.

## Getting Started

1. Ensure you have Flutter installed.
2. Navigate to this directory (`examples/login_flow_ltl`).
3. Run `flutter pub get` to fetch dependencies. Note that the necessary `temporal_logic_*` packages are linked via `path` dependencies in `pubspec.yaml`, assuming they are located correctly relative to this example directory within the monorepo structure.
4. Run the application: `flutter run`
5. Run the tests: `flutter test`

This project provides a practical illustration of applying LTL for verifying complex application behavior over time in Flutter.
