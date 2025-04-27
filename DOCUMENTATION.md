# Temporal Logic Packages for Flutter & Dart - Detailed Documentation

Welcome to the detailed documentation for the `temporal_logic_core`, `temporal_logic_mtl`, and `temporal_logic_flutter` packages. This guide aims to provide a comprehensive understanding of the concepts, APIs, and best practices for using temporal logic to specify and verify the behavior of your Dart and Flutter applications, especially those with complex state transitions and timing requirements.

**Target Audience:** Developers looking to write more robust tests for sequential or time-dependent behavior in their Flutter/Dart applications.

**Table of Contents:**

- [Temporal Logic Packages for Flutter \& Dart - Detailed Documentation](#temporal-logic-packages-for-flutter--dart---detailed-documentation)
  - [1. Introduction](#1-introduction)
    - [Why Temporal Logic?](#why-temporal-logic)
    - [Package Overview](#package-overview)
    - [Your First LTL Test (Login Flow Example)](#your-first-ltl-test-login-flow-example)
  - [3. Core Concepts](#3-core-concepts)
    - [Traces and Timestamps](#traces-and-timestamps)
    - [State Snapshots (`AppSnap`)](#state-snapshots-appsnap)
    - [Propositions: `state` vs `event`](#propositions-state-vs-event)
    - [Linear Temporal Logic (LTL) Basics](#linear-temporal-logic-ltl-basics)
    - [Metric Temporal Logic (MTL) Basics](#metric-temporal-logic-mtl-basics)
  - [4. API Reference](#4-api-reference)
    - [`temporal_logic_core` API](#temporal_logic_core-api)
      - [Formula](#formula)
      - [AtomicProposition](#atomicproposition)
      - [Logical Operators (`and`, `or`, `not`, `implies`)](#logical-operators-and-or-not-implies)
      - [LTL Operators (`next`, `always`, `eventually`, `until`, `release`)](#ltl-operators-next-always-eventually-until-release)
      - [Helper Functions (`state`, `event`)](#helper-functions-state-event)
    - [`temporal_logic_mtl` API](#temporal_logic_mtl-api)
      - [TimeInterval](#timeinterval)
      - [Timed Operators (`alwaysTimed`, `eventuallyTimed`)](#timed-operators-alwaystimed-eventuallytimed)
      - [Evaluation (`evaluateMtlTrace`)](#evaluation-evaluatemtltrace)
    - [`temporal_logic_flutter` API](#temporal_logic_flutter-api)
      - [TraceRecorder](#tracerecorder)
      - [Matchers (`satisfiesLtl`)](#matchers-satisfiesltl)
  - [5. Cookbook \& Best Practices](#5-cookbook--best-practices)
    - [Integrating with State Management (Riverpod Example)](#integrating-with-state-management-riverpod-example)
    - [Designing Effective `AppSnap` Types](#designing-effective-appsnap-types)
    - [Common LTL/MTL Patterns](#common-ltlmtl-patterns)
    - [Testing Asynchronous Operations](#testing-asynchronous-operations)
    - [Handling Transient Events (`loginClicked`)](#handling-transient-events-loginclicked)
    - [Performance Considerations](#performance-considerations)
  - [6. More Examples](#6-more-examples)
    - [Form Validation Flow](#form-validation-flow)
    - [Animation Sequence Verification](#animation-sequence-verification)
    - [Network Request Lifecycle](#network-request-lifecycle)
  - [7. Troubleshooting](#7-troubleshooting)

---

## 1. Introduction

### Why Temporal Logic?

Modern applications, especially UI-rich Flutter apps, involve complex sequences of events, state changes, and timing. Bugs arising from incorrect ordering, timing issues, or unexpected state interactions can be hard to catch with traditional testing methods that focus primarily on static snapshots or final outcomes.

Temporal Logic (LTL and MTL) provides a formal and precise language to describe and verify properties *over time*, looking at the entire sequence of states.

- **LTL (Linear Temporal Logic):** Specifies properties about the *order* of events and states (e.g., "A login attempt must *eventually* be followed by either a successful login state or an error state").
- **MTL (Metric Temporal Logic):** Extends LTL with *quantitative time constraints* (e.g., "A loading indicator must disappear *within 3 seconds* after data is fetched").

Using these packages allows you to:

- **Clearly Specify Complex Behavior:** Define intended temporal sequences and timing constraints unambiguously.
- **Enhance Test Coverage:** Design tests specifically targeting complex temporal scenarios, race conditions, and intermediate states.
- **Detect Subtle Bugs:** Catch issues like transient incorrect states (UI flickers), violations of required sequences, or timing failures that might be missed otherwise.

### Package Overview

- **`packages/temporal_logic_core`**: Foundational interfaces, LTL formula construction, and basic trace structures.
- **`packages/temporal_logic_mtl`**: MTL implementation, adding timed operators and evaluation for timed traces.
- **`packages/temporal_logic_flutter`**: Flutter-specific integrations, including `TraceRecorder` for capturing state sequences and `flutter_test` Matchers (`satisfiesLtl`, `satisfiesMtl`).

### Your First LTL Test (Login Flow Example)

The `examples/login_flow_ltl` provides a practical starting point. Here's the essence of its test (`test/widget_test.dart` using external recording), demonstrating how to verify a specific sequence of state changes after a login attempt:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login_flow_ltl_example/main.dart'; // Your app
import 'package:temporal_logic_core/temporal_logic_core.dart' as tlCore;
import 'package:temporal_logic_flutter/temporal_logic_flutter.dart' as tlFlutter;

// Represents a snapshot of the relevant application state for verification.
// Needs to be immutable and implement ==/hashCode.
class AppSnap {
  final bool isLoading;
  final bool isOnHomeScreen;
  final bool hasError;
  final bool loginClicked; // Transient event flag

  AppSnap({
    required this.isLoading,
    required this.isOnHomeScreen,
    required this.hasError,
    required this.loginClicked,
  });

  // Factory constructor to create from the actual app state (e.g., Riverpod state)
  factory AppSnap.fromAppState(AppState state, {bool loginClicked = false}) {
    return AppSnap(
      isLoading: state.isLoading,
      isOnHomeScreen: state.currentScreen == AppScreen.home,
      hasError: state.errorMessage != null,
      loginClicked: loginClicked, // Capture the event
    );
  }
  // Implement == and hashCode...
}

void main() {
  testWidgets('Successful login flow satisfies LTL formula', (tester) async {
    // 1. Setup: Create a recorder to capture state snapshots over time.
    final recorder = tlFlutter.TraceRecorder<AppSnap>();
    final container = ProviderContainer(); // Assuming Riverpod for state management
    addTearDown(container.dispose);
    recorder.initialize(); // Start time tracking

    // 2. Recording: Capture the initial state and listen for subsequent state changes.
    final initialState = container.read(appStateProvider);
    recorder.record(AppSnap.fromAppState(initialState)); // Record initial snapshot
    container.listen<AppState>(appStateProvider, (prev, next) {
      // Record every relevant state change
      recorder.record(AppSnap.fromAppState(next));
    });

    // 3. Setup UI
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.pumpAndSettle(); // Allow asynchronous operations and state changes to complete and be recorded

    // 4. Simulate User Interaction
    await tester.enterText(find.byKey(const Key('email')), 'valid@email.com');
    // Before tapping, record a special snapshot indicating the *intent* or *event*
    final currentStateBeforeClick = container.read(appStateProvider);
    recorder.record(AppSnap.fromAppState(currentStateBeforeClick, loginClicked: true));
    await tester.tap(find.byKey(const Key('login')));
    await tester.pumpAndSettle(); // Allow asynchronous operations and state changes to complete and be recorded

    // 5. Define Propositions: Basic true/false statements about an AppSnap.
    // Use `state` for conditions that hold over a duration.
    final loading = tlCore.state<AppSnap>((s) => s.isLoading, name: 'loading');
    final home = tlCore.state<AppSnap>((s) => s.isOnHomeScreen, name: 'home');
    final error = tlCore.state<AppSnap>((s) => s.hasError, name: 'error');
    // Use `event` for conditions marking a specific point in time (often a transition trigger).
    final loginClicked = tlCore.event<AppSnap>((s) => s.loginClicked, name: 'loginClicked');

    // 6. Define LTL Formula: Specify the expected temporal behavior.
    // "Globally (G), if loginClicked happens, then necessarily (->)
    //  in the next state (X) we are loading, AND
    //  eventually (F) we reach the home screen, AND
    //  globally (G) we never encounter an error."
    // G(loginClicked -> (X loading && F home && G !error))
    final formula = tlCore.always(
      loginClicked.implies(
        tlCore.next(loading)
        .and(tlCore.eventually(home))
        .and(tlCore.always(error.not()))
      )
    );

    // 7. Verify: Check if the recorded sequence of AppSnaps (the trace) satisfies the formula.
    final trace = recorder.trace;
    // Use the custom matcher from temporal_logic_flutter
    expect(trace, tlFlutter.satisfiesLtl(formula));
  });
}
```

## 3. Core Concepts

### Traces and Timestamps

- A **Trace** (`Trace<T>`) is the core data structure, representing an ordered sequence of application state snapshots (`T`) captured over time. Think of it as a log or history of relevant state changes.
- Each element in the trace is a **TraceEvent<T>**, containing:
  - `value`: The state snapshot (`T`) itself.
  - `timestamp`: When this snapshot was recorded (`Duration` since recording started).
- The `TraceRecorder` automatically assigns timestamps based on its internal `TimeProvider` (defaults to wall-clock time) when `record()` is called.

### State Snapshots (`AppSnap`)

- The generic type `T` in `Trace<T>` (often named `AppSnap` or similar by convention) represents a **simplified, immutable snapshot** of your application's state at a particular moment. It contains only the information relevant to the temporal properties you want to verify.
- **Why use a dedicated `AppSnap`?**
  - **Focus:** Isolates the specific state aspects needed for verification, ignoring irrelevant details from your full application state (e.g., complex UI models, unrelated data).
  - **Immutability:** Ensures that each recorded state is fixed and cannot be changed later, crucial for reliable trace evaluation.
  - **Simplicity:** Makes defining propositions easier, as they only operate on the simplified `AppSnap` structure.
  - **Decoupling:** Keeps your temporal logic tests separate from the intricacies of your main application state management classes.
- **Design Principles for `AppSnap`:**
  - Include only boolean flags, enums, or simple values needed for your formulas.
  - Keep it minimal but sufficient.
  - **Crucially, make it immutable and correctly implement `==` and `hashCode`** for proper comparison within the trace and formulas.

### Propositions: `state` vs `event`

Temporal logic formulas are built upon **Atomic Propositions**: fundamental true/false statements about a single state snapshot (`AppSnap`). The key is choosing whether a condition represents an ongoing *state* or a momentary *event*.

- **`tlCore.state<T>(Predicate<T> predicate, {String? name})`**:
  - **Purpose:** Creates an `AtomicProposition` intended to represent a condition that holds *while* the application is in a certain configuration or phase (a duration).
  - **`predicate`:** A function `(T state) => bool` that returns `true` if the state snapshot `state` satisfies the condition.
  - **`name`:** An optional descriptive name for debugging.
  - **Example:** `final isLoading = tlCore.state<AppSnap>((s) => s.isLoading, name: 'Is Loading');`
  - **See Also:** Section 3 - Propositions: `state` vs `event` for conceptual details.

- **`tlCore.event<T>(Predicate<T> predicate, {String? name})`**:
  - **Purpose:** Creates an `AtomicProposition` intended to represent something happening at a specific point in time (an occurrence or trigger).
  - **`predicate`:** A function `(T state) => bool` that returns `true` if the state snapshot `state` represents the occurrence of the event. Often, this predicate checks a transient flag set specifically for one snapshot.
  - **`name`:** An optional descriptive name for debugging.
  - **Example:** `final loginClicked = tlCore.event<AppSnap>((s) => s.loginClicked, name: 'Login Clicked Event');`
  - **See Also:** Section 3 - Propositions: `state` vs `event` and Section 5 - Handling Transient Events for conceptual and practical details.

**Choosing Between `state` and `event`:**

| Feature        | `state<T>`                                     | `event<T>`                                         |
| -------------- | :--------------------------------------------- | :------------------------------------------------- |
| **Represents** | A condition holding over a duration (a phase) | An occurrence at a point in time (a trigger)       |
| **Typical Use**| `isLoading`, `isLoggedIn`, `hasError`          | `buttonClicked`, `requestSent`, `itemAdded`        |
| **Predicate**  | True for *multiple* consecutive snapshots    | Often true for only a *single* snapshot            |
| **LTL Focus**  | What is true *during* a period               | What is true *at the moment* something happens   |

The choice significantly affects how temporal operators like `next` (X), `always` (G), and `eventually` (F) interpret the formula, as they operate on the sequence of true/false evaluations of these propositions over the trace.

### Linear Temporal Logic (LTL) Basics

LTL reasons about properties along the linear sequence of states in the trace. It allows you to express relationships between states over time. Key operators provided by `temporal_logic_core` (available as extension methods on `Formula`):

- **`next(formula)` (X)**: "In the immediately following state, `formula` must be true." (Looks one step ahead).
- **`always(formula)` (G)**: "From this point forward (including the current state), `formula` must always be true." (Invariant property).
- **`eventually(formula)` (F)**: "At some point from now on (including the current state), `formula` must become true." (Liveness property, something good eventually happens).
- **`until(formula1, formula2)` (U)**: "`formula1` must remain true continuously *at least until* the point where `formula2` becomes true. Furthermore, `formula2` *must* eventually become true."
- **`release(formula1, formula2)` (R)**: "`formula2` must remain true up to and including the point where `formula1` first becomes true. If `formula1` never becomes true, `formula2` must remain true forever." (Dual of Until; often used for ensuring a condition holds unless released by another).
- Standard logical operators (`and`, `or`, `not`, `implies`) combine these temporal operators and propositions.

### Metric Temporal Logic (MTL) Basics

MTL extends LTL by adding explicit time constraints to the temporal operators, allowing you to reason about *how long* things take. Provided by `temporal_logic_mtl`.

- **`TimeInterval(Duration start, Duration end, {bool startInclusive, bool endInclusive})`**: Defines a precise time window relative to the current state's timestamp.
- **`alwaysTimed(formula, TimeInterval interval)` (G[a,b])**: "`formula` must hold true at all future states whose timestamps fall within the specified `interval` relative to the current time." (e.g., "Globally, for the next 5 seconds, the error flag must be false").
- **`eventuallyTimed(formula, TimeInterval interval)` (F[a,b])**: "`formula` must become true at some future state whose timestamp falls within the specified `interval` relative to the current time." (e.g., "Eventually, within 2 seconds, the success message must appear").
- Evaluation requires a `Trace` with meaningful timestamps (usually automatically handled by `TraceRecorder`) and uses the `evaluateMtlTrace` function.

## 4. API Reference

### `temporal_logic_core` API

#### Formula<T>

The abstract base class for all temporal logic expressions (LTL). Represents a statement whose truth value can be evaluated at a specific point in a trace.

#### AtomicProposition<T>

The simplest form of `Formula`. Represents a basic true/false statement about a single state snapshot `T`, evaluated using a predicate function. `state<T>` and `event<T>` create instances of this.

- `bool predicate(T state)`: The function that determines if the proposition is true for a given state.
- `String name`: An optional descriptive name for the proposition, useful for debugging and understanding evaluation results.

#### Logical Operators (`and`, `or`, `not`, `implies`)

These operators combine existing formulas to create more complex logical statements. They are typically used as extension methods on `Formula<T>` objects.

- **`formula1.and(formula2)`**: Creates a new formula that is true at a point in the trace if and only if *both* `formula1` AND `formula2` are true at that same point.
  - **Semantics:** Standard logical conjunction (∧).
  - **Example:** `isLoading.and(networkUnavailable)`

- **`formula1.or(formula2)`**: Creates a new formula that is true at a point in the trace if *either* `formula1` OR `formula2` (or both) are true at that point.
  - **Semantics:** Standard logical disjunction (∨).
  - **Example:** `isError.or(isWarning)`

- **`formula.not()`**: Creates a new formula that is true at a point in the trace if and only if the original `formula` is *false* at that point.
  - **Semantics:** Standard logical negation (¬ or !).
  - **Example:** `isLoggedIn.not()`

- **`formula1.implies(formula2)`**: Creates a new formula representing logical implication. It is true at a point in the trace if `formula1` is false, OR if both `formula1` and `formula2` are true. It is only false if `formula1` is true and `formula2` is false.
  - **Semantics:** Material implication (→). Equivalent to `formula1.not().or(formula2)`.
  - **Example:** `loginAttempted.implies(isLoading.eventually())` (If a login was attempted, then eventually loading must occur).

#### LTL Operators (`next`, `always`, `eventually`, `until`, `release`)

These are the core temporal operators that reason about sequences of states over time.

- **`formula.next()`** or `tlCore.next(formula)`:
  - **Symbol:** X `formula`
  - **Semantics:** The `formula` must hold true in the *immediately following* state in the trace. If the current state is the last state in the trace, `next` is typically considered false (as there is no next state).
  - **Example:** `requestSent.implies(tlCore.next(responsePending))` (If a request was just sent, the next state must show the response as pending).

- **`formula.always()`** or `tlCore.always(formula)`:
  - **Symbol:** G `formula`
  - **Semantics:** The `formula` must hold true in the *current* state and *all subsequent* states in the trace until the end.
  - **Example:** `loggedIn.implies(tlCore.always(sessionValid))` (Once logged in, the session must remain valid for the entire remaining trace).
  - **Common Use:** Expressing safety properties or invariants (something bad should never happen).

- **`formula.eventually()`** or `tlCore.eventually(formula)`:
  - **Symbol:** F `formula`
  - **Semantics:** The `formula` must hold true *at some point* in the trace, either in the current state or in some future state.
  - **Example:** `buttonPressed.implies(tlCore.eventually(operationComplete))` (If the button is pressed, the operation must complete at some point later).
  - **Common Use:** Expressing liveness properties (something good should eventually happen).

- **`formula1.until(formula2)`** or `tlCore.until(formula1, formula2)`:
  - **Symbol:** `formula1` U `formula2`
  - **Semantics:** `formula1` must hold true continuously from the current state *at least until* the state where `formula2` becomes true. Crucially, `formula2` *must* eventually become true at or after the current state.
  - **Example:** `waitingForInput.until(inputReceived)` (We must be in the 'waiting' state continuously until 'inputReceived' becomes true, and 'inputReceived' must eventually happen).

- **`formula1.release(formula2)`** or `tlCore.release(formula1, formula2)`:
  - **Symbol:** `formula1` R `formula2`
  - **Semantics:** `formula2` must hold true continuously from the current state up to *and including* the point where `formula1` first becomes true. If `formula1` never becomes true in the remainder of the trace, `formula2` must hold true for the entire remainder. `formula2` must be true *at least* until `formula1` is true (if `formula1` ever becomes true). This is the logical dual of `until`.
  - **Example:** `errorOccurred.release(operationInProgress)` (The operation must remain 'in progress' at least until an error occurs. If no error occurs, it must stay 'in progress'.) Often used to state that a condition (`formula2`) must hold unless some releasing condition (`formula1`) happens.

#### Helper Functions (`state`, `event`)

These factory functions are the primary way to create `AtomicProposition` instances, forming the building blocks of your formulas.

- **`tlCore.state<T>(Predicate<T> predicate, {String? name})`**:
  - **Purpose:** Creates an `AtomicProposition` intended to represent a condition that holds *while* the application is in a certain configuration or phase (a duration).
  - **`predicate`:** A function `(T state) => bool` that returns `true` if the state snapshot `state` satisfies the condition.
  - **`name`:** An optional descriptive name for debugging.
  - **Example:** `final isLoading = tlCore.state<AppSnap>((s) => s.isLoading, name: 'Is Loading');`
  - **See Also:** Section 3 - Propositions: `state` vs `event` for conceptual details.

- **`tlCore.event<T>(Predicate<T> predicate, {String? name})`**:
  - **Purpose:** Creates an `AtomicProposition` intended to represent something happening at a specific point in time (an occurrence or trigger).
  - **`predicate`:** A function `(T state) => bool` that returns `true` if the state snapshot `state` represents the occurrence of the event. Often, this predicate checks a transient flag set specifically for one snapshot.
  - **`name`:** An optional descriptive name for debugging.
  - **Example:** `final loginClicked = tlCore.event<AppSnap>((s) => s.loginClicked, name: 'Login Clicked Event');`
  - **See Also:** Section 3 - Propositions: `state` vs `event` and Section 5 - Handling Transient Events for conceptual and practical details.

### `temporal_logic_mtl` API

This package extends `temporal_logic_core` by adding Metric Temporal Logic (MTL) capabilities, allowing formulas to include explicit time constraints.

#### TimeInterval

A class defining a time window used by timed MTL operators (like `alwaysTimed` and `eventuallyTimed`). It specifies a range relative to the timestamp of the current state being evaluated.

- **Constructor:** `TimeInterval(Duration start, Duration end, {bool startInclusive = true, bool endInclusive = false})`
  - **`start`**: The start `Duration` of the interval (relative to the current time).
  - **`end`**: The end `Duration` of the interval (relative to the current time).
  - **`startInclusive`**: Whether a timestamp equal to `start` is included in the interval. Defaults to `true`.
  - **`endInclusive`**: Whether a timestamp equal to `end` is included in the interval. Defaults to `false`.
- **Interpretation:** An interval `[start, end)` (default) means the time `t` must satisfy `start <= t < end`. If `endInclusive` is true, it becomes `start <= t <= end`.
- **Examples:**
  - `TimeInterval(Duration.zero, Duration(seconds: 5))` represents `[0s, 5s)` - from now up to (but not including) 5 seconds.
  - `TimeInterval(Duration(seconds: 2), Duration(seconds: 10), endInclusive: true)` represents `[2s, 10s]` - from 2 seconds up to and including 10 seconds.
  - `TimeInterval(Duration(seconds: 1), Duration(seconds: 1))` represents the single instant `t = 1s` (since `startInclusive` is true and `endInclusive` is false by default).

#### Timed Operators (`alwaysTimed`, `eventuallyTimed`)

These operators extend their LTL counterparts (`always`, `eventually`) by adding a `TimeInterval` constraint.

- **`formula.alwaysTimed(interval)`** or `tlMtl.alwaysTimed(formula, interval)`:
  - **Symbol:** G[`interval`] `formula` (e.g., G[0, 5s] `formula`)
  - **Semantics:** The `formula` must hold true at *all* future states in the trace whose timestamp `t_future` satisfies `t_current + interval.start <= t_future < t_current + interval.end` (adjusting for inclusiveness based on `interval` flags). If no states fall within the interval, the operator is vacuously true.
  - **Example:** `dataFetched.implies(loadingIndicatorVisible.not().alwaysTimed(TimeInterval(Duration.zero, Duration(seconds: 1))))` (If data was fetched, then the loading indicator must *not* be visible for the entire interval from 0s to 1s after the fetch).

- **`formula.eventuallyTimed(interval)`** or `tlMtl.eventuallyTimed(formula, interval)`:
  - **Symbol:** F[`interval`] `formula` (e.g., F[2s, 5s] `formula`)
  - **Semantics:** The `formula` must hold true at *at least one* future state in the trace whose timestamp `t_future` satisfies `t_current + interval.start <= t_future < t_current + interval.end` (adjusting for inclusiveness). If no state within the interval satisfies the formula, or if no states fall within the interval, the operator is false.
  - **Example:** `requestSent.implies(responseReceived.eventuallyTimed(TimeInterval(Duration.zero, Duration(seconds: 3))))` (If a request was sent, a response must be received sometime within the next 3 seconds).

#### Evaluation (`evaluateMtlTrace`)

This is the core function in `temporal_logic_mtl` used to check if a timed trace satisfies an MTL formula.

- **Signature:** `EvaluationResult evaluateMtlTrace<T>(Trace<T> trace, Formula<T> formula, {int startIndex = 0})`
- **Purpose:** Evaluates whether the given `formula` (which can contain LTL and MTL operators) holds true for the provided `trace`, starting the evaluation from the state at `startIndex`.
- **Parameters:**
  - `trace`: The `Trace<T>` object containing the sequence of state snapshots and their timestamps.
  - `formula`: The `Formula<T>` (potentially including timed operators like `alwaysTimed` or `eventuallyTimed`) to evaluate against the trace.
  - `startIndex`: The index within the trace from which to start the evaluation. Defaults to `0` (the beginning of the trace).
- **Returns:** An `EvaluationResult` object.
  - `bool holds`: `true` if the formula holds for the trace starting at `startIndex`, `false` otherwise.
  - `String? reason`: If `holds` is `false`, this may contain a string explaining why the formula failed (e.g., which sub-formula failed at which index or time). This is helpful for debugging test failures.
- **Usage:** While you can call this function directly, it's more common in Flutter tests to use the `satisfiesMtl` matcher provided by `temporal_logic_flutter`, which calls this function internally.

### `temporal_logic_flutter` API

This package provides utilities specifically for integrating temporal logic testing into Flutter applications, primarily using `flutter_test`.

#### TraceRecorder<T>

A helper class designed for Flutter integration. It simplifies the process of capturing a `Trace<T>` from a running application or simulation, automatically handling timestamps.

- **Constructor:** `TraceRecorder({TimeProvider timeProvider = const WallClockTimeProvider()})`
  - `timeProvider`: An optional `TimeProvider` used to get the current timestamp when `record` is called. Defaults to `WallClockTimeProvider`, which uses the system's real time. For testing purposes, you might inject a custom `FakeTimeProvider` to control time progression deterministically.
- **Methods:**
  - `void initialize()`: Resets the recorder, clears any existing trace events, and records the starting time based on the `timeProvider`. This should be called at the beginning of each test or recording session.
  - `void record(T state)`: Captures the given `state` snapshot, associates it with the current timestamp obtained from the `timeProvider`, and adds it as a `TraceEvent<T>` to the internal trace.
- **Getter:**
  - `Trace<T> get trace`: Returns the `Trace<T>` object containing all the `TraceEvent<T>` instances recorded since the last `initialize()` call.
- **Typical Usage (Flutter Tests):**
    1. Instantiate `TraceRecorder<AppSnap>()`.
    2. Call `recorder.initialize()` at the start of the test.
    3. Use a state management listener (like `container.listen` for Riverpod) or manual calls within test interactions to call `recorder.record(AppSnap.fromAppState(...))` whenever a relevant state change occurs or an event needs marking.
    4. After interactions, access `recorder.trace` and pass it to an `expect` statement with a `satisfiesLtl` matcher.

#### Matchers (`satisfiesLtl`)

Custom `flutter_test` matchers that integrate temporal logic evaluation directly into your `expect` statements, making tests more readable.

- **`Matcher satisfiesLtl<T>(Formula<T> formula)`**
  - **Purpose:** Creates a `Matcher` that checks if a given `Trace<T>` satisfies the provided LTL `formula`.
  - **Mechanism:** Internally, this matcher calls an LTL evaluation function (similar to `evaluateMtlTrace` but potentially optimized for LTL) on the trace provided to `expect`.
  - **Usage:**

      ```dart
      final trace = recorder.trace;
      final ltlFormula = tlCore.always(isSuccess.implies(isError.not()));
      expect(trace, tlFlutter.satisfiesLtl(ltlFormula));

      // Can also be negated:
      expect(failedTrace, isNot(tlFlutter.satisfiesLtl(ltlFormula)));
      ```

  - **Output on Failure:** When the match fails, it typically provides a descriptive error message, often including the reason from the underlying `EvaluationResult`, indicating where and why the formula was violated in the trace.

## 5. Cookbook & Best Practices

This section provides practical advice, patterns, and code snippets for effectively using the temporal logic packages in your projects.

### Integrating with State Management (Riverpod Example)

The most common way to capture a trace in Flutter tests is to listen to changes in your state management solution and record an `AppSnap` whenever relevant state updates occur. Here's a more detailed look using Riverpod:

**Assumptions:**

- You have a Riverpod `StateNotifierProvider` (e.g., `appStateProvider`) that exposes your main application state (`AppState`).
- You have an `AppSnap` class with a factory constructor `AppSnap.fromAppState(AppState state, {bool transientEventFlag = false})`.

**Test Setup:**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temporal_logic_flutter/temporal_logic_flutter.dart' as tlFlutter;
import 'package:temporal_logic_core/temporal_logic_core.dart' as tlCore;
// Import your AppState, AppSnap, providers, and main app widget
// ...

void main() {
  testWidgets('Example Riverpod Integration Test', (tester) async {
    // 1. Create Recorder and ProviderContainer
    final recorder = tlFlutter.TraceRecorder<AppSnap>();
    // Create a fresh container for this test to isolate state
    final container = ProviderContainer();
    // Ensure container is disposed at the end of the test
    addTearDown(container.dispose);

    // 2. Initialize Recorder (Starts time tracking)
    recorder.initialize();

    // 3. Record Initial State *before* listening
    // Read the initial state directly from the provider
    final initialState = container.read(appStateProvider);
    recorder.record(AppSnap.fromAppState(initialState));

    // 4. Listen for State Changes
    // Use container.listen to react to any changes in AppState
    container.listen<AppState>(
      appStateProvider, // The provider to listen to
      (previousState, newState) {
        // IMPORTANT: Record the newState whenever the AppState changes.
        // The AppSnap.fromAppState factory is responsible for extracting
        // the relevant boolean/enum values for the snapshot.
        recorder.record(AppSnap.fromAppState(newState));
      },
      // Optional: fireImmediately: true (if you hadn't recorded initial state separately)
      // Optional: onError to handle provider errors if necessary
    );

    // 5. Pump the Widget Tree with the Test Container
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MyApp(), // Your root widget
      ),
    );
    // Allow initial build and state stabilization
    await tester.pumpAndSettle();

    // --- Test Interactions --- 
    // Example: Simulate tapping a login button

    // Optional but recommended for transient events:
    // Record the state *just before* the event trigger with the event flag set
    final stateBeforeClick = container.read(appStateProvider);
    recorder.record(AppSnap.fromAppState(stateBeforeClick, loginClicked: true));

    // Find and tap the button (assuming it updates the AppState via the provider)
    await tester.tap(find.byKey(const Key('loginButton')));

    // Allow time for async operations and state updates to propagate
    await tester.pumpAndSettle(); 

    // --- Verification --- 
    final trace = recorder.trace;
    final formula = tlCore.always(/* ... your LTL/MTL formula ... */);

    expect(trace, tlFlutter.satisfiesLtl(formula)); // Or satisfiesMtl

    // Recorder is disposed automatically via addTearDown if needed,
    // but container disposal is usually the more critical part.
  });
}
```

**Key Points:**

- **Isolate State:** Use a `ProviderContainer` specific to the test.
- **Initial State:** Record the state *before* listening to capture T=0.
- **Listen Hook:** `container.listen` is the core mechanism for automatically recording subsequent states.
- **`AppSnap` Factory:** The `AppSnap.fromAppState` logic is crucial for translating your potentially complex `AppState` into the simplified snapshot needed for verification.
- **Transient Events:** Handle button clicks or similar momentary events by manually recording an `AppSnap` with a specific flag set *just before* or *at the moment* the event occurs (see Section 5 - Handling Transient Events).
- **`pumpAndSettle`:** Use liberally after interactions to ensure all state changes triggered by the interaction are processed and recorded by the listener.

This pattern decouples your test logic from the specifics of how state changes occur, as long as those changes are reflected in the `AppState` exposed by the provider you are listening to.

### Designing Effective `AppSnap` Types

The `AppSnap` class (or whatever you choose to call your state snapshot type `T`) is arguably the most critical piece of your temporal logic testing setup. A well-designed `AppSnap` makes your tests clearer, more robust, and easier to maintain. Here are the key principles:

- **Purpose Revisited:** Remember, `AppSnap` is a *simplified view* of your application state, containing *only* the information needed to evaluate the temporal properties you care about for a specific test or suite of tests. It's not meant to replicate your entire application state.

- **Immutability is Key:**
  - **Why?** Temporal logic relies on evaluating sequences of *fixed* states. If snapshots could change after being recorded, the evaluation would be meaningless and unpredictable.
  - **How?** Declare all fields `final`. Ensure any objects held within `AppSnap` are also immutable (or treat them as such, e.g., by copying data instead of holding references if they might change).
  - **Benefit:** Guarantees that each `TraceEvent` represents a distinct, unchanging state at a specific time.

- **Relevance (Minimal but Sufficient):**
  - **Why?** Including unnecessary state information in `AppSnap` makes it harder to reason about, increases the chance of irrelevant changes triggering recordings, and potentially impacts performance slightly.
  - **How?** For each temporal formula you intend to write, identify the specific boolean conditions or enum values it depends on. Only include fields in `AppSnap` that are necessary to derive these conditions. For example, if you only care if `user != null`, include a boolean `isLoggedIn` field rather than the entire `User` object.
  - **Benefit:** Keeps tests focused, reduces noise in the trace, and simplifies proposition definitions.

- **Derive, Don't Duplicate State Logic:**
  - **Why?** Your application state (e.g., in Riverpod, Bloc, etc.) is the single source of truth. Re-implementing logic to determine `isLoading` or `hasError` within the `AppSnap` factory or test setup leads to duplicated logic and potential inconsistencies.
  - **How?** Create `AppSnap` instances using a factory constructor (e.g., `AppSnap.fromAppState(AppState state)`) that takes your *actual* application state object as input. Inside this factory, read the necessary properties from the real state object and map them to the simplified fields of `AppSnap`.
  - **Benefit:** Ensures `AppSnap` accurately reflects the source-of-truth state at the time of recording and avoids logic duplication.

- **Implement `==` and `hashCode` Correctly:**
  - **Why?** The evaluation engine might compare snapshots to detect stable states, cycles, or whether a proposition holds consistently. Correct equality checking is essential for these comparisons.
  - **How?**
    - Use the `equatable` package for easy and reliable implementation.
    - Alternatively, manually override `==` and `hashCode`, ensuring you compare all fields and follow the contract (if `a == b`, then `a.hashCode == b.hashCode`).
  - **Benefit:** Ensures reliable evaluation of temporal formulas, especially those involving state stability or repetition.

**Example Structure:**

```dart
import 'package:equatable/equatable.dart';

// Assuming you have an AppState class from your state management
class AppState { 
  final User? currentUser;
  final bool networkFetchIsLoading;
  final String? lastErrorMessage;
  final List<Item> items;
  // ... other state fields
}

// Your simplified snapshot class
class AppSnap extends Equatable {
  final bool isLoggedIn;
  final bool isLoading;
  final bool hasError;
  final int itemCount;
  final bool transientLoginClick; // For marking events

  const AppSnap({
    required this.isLoggedIn,
    required this.isLoading,
    required this.hasError,
    required this.itemCount,
    this.transientLoginClick = false, // Default to false
  });

  // Factory to create from the real state
  factory AppSnap.fromAppState(AppState state, {bool loginClicked = false}) {
    return AppSnap(
      isLoggedIn: state.currentUser != null,
      isLoading: state.networkFetchIsLoading,
      hasError: state.lastErrorMessage != null && state.lastErrorMessage!.isNotEmpty,
      itemCount: state.items.length,
      transientLoginClick: loginClicked, // Use the passed value
    );
  }

  @override
  List<Object?> get props => [
        isLoggedIn,
        isLoading,
        hasError,
        itemCount,
        transientLoginClick,
      ];
}
```

By following these principles, you create `AppSnap` types that effectively bridge your application's state with the formal requirements of temporal logic verification.

### Common LTL/MTL Patterns

Temporal logic formulas often follow recurring patterns that express fundamental properties of system behavior. Understanding these patterns helps in formulating effective tests. Here are some common ones, along with their typical LTL/MTL representation:

(Assume standard propositions like `request`, `response`, `errorState`, `action`, `completion`, `loading`, `formValid`, `submitEnabled` are defined based on your `AppSnap`)

- **Response (Eventually):** "A certain condition (`request`) must eventually be followed by another condition (`response`)."
  - **Meaning:** If the `request` happens, the system guarantees that, at some point later, the `response` will happen. It doesn't say *when*, only that it *will* happen.
  - **Formula:** `tlCore.always(request.implies(tlCore.eventually(response)))`
  - **LTL:** `G(request -> F response)`
  - **Use Case:** Verifying that actions lead to expected outcomes (e.g., submitting data eventually leads to a success confirmation), acknowledgments are received, etc.

- **Response (Next):** "If `request` happens, then `response` must happen in the very next state."
  - **Meaning:** The effect (`response`) must be immediate in terms of state transitions following the cause (`request`).
  - **Formula:** `tlCore.always(request.implies(tlCore.next(response)))`
  - **LTL:** `G(request -> X response)`
  - **Use Case:** Testing immediate state updates after synchronous actions (e.g., clicking a button immediately enables another).

- **Safety (Never / Invariant):** "A certain undesirable condition (`errorState`) must never occur."
  - **Meaning:** Throughout the entire execution trace (from the point the formula is checked), the `errorState` condition must always be false.
  - **Formula:** `tlCore.always(errorState.not())`
  - **LTL:** `G(!errorState)`
  - **Use Case:** Enforcing critical safety constraints, ensuring forbidden states are unreachable (e.g., a user should never see admin controls, a system should never enter a deadlock state).

- **Liveness (Eventually):** "If an `action` is triggered, its `completion` must eventually occur."
  - **Meaning:** The system must eventually make progress and reach the `completion` state after the `action` has occurred. It guarantees termination or eventual success.
  - **Formula:** `tlCore.always(action.implies(tlCore.eventually(completion)))`
  - **LTL:** `G(action -> F completion)`
  - **Use Case:** Ensuring processes don't get stuck, requests are eventually processed, progress indicators eventually disappear.

- **Timed Response (MTL):** "If `request` happens, then `response` must occur within a specific time interval (e.g., 5 seconds)."
  - **Meaning:** Extends the basic Response pattern with a real-time constraint.
  - **Formula:** `tlCore.always(request.implies(response.eventuallyTimed(TimeInterval(Duration.zero, Duration(seconds: 5)))))`
  - **MTL:** `G(request -> F[0s, 5s] response)`
  - **Use Case:** Testing performance requirements, timeouts, animations completing within a duration, user feedback appearing promptly.

- **No Flicker / Stability During Phase:** "While a certain phase condition (`loading`) is true, an undesirable transient condition (`error`) must never become true."
  - **Meaning:** Guarantees stability during a specific operation. The `error` condition is forbidden as long as the `loading` condition holds.
  - **Formula 1 (Strict):** `tlCore.always(loading.implies(error.not()))`
    - **LTL:** `G(loading -> !error)` (Error must *never* be true when loading is true)
  - **Formula 2 (Using Until):** `tlCore.always(loading.implies(error.not().until(loading.not())))`
    - **LTL:** `G(loading -> (!error U !loading))` (If loading starts, error must remain false at least until loading becomes false)
  - **Use Case:** Preventing temporary error messages during loading, ensuring UI consistency during transitions, verifying that certain actions are disabled during a process.

- **State Ordering:** "State `phaseA` must always be followed eventually by `phaseB` before `phaseC` can occur."
  - **Meaning:** Enforces a specific sequence of major states.
  - **Formula (Conceptual - may need refinement based on strictness):** `tlCore.always(phaseA.implies(phaseC.not().until(phaseB)))`
  - **LTL:** `G(phaseA -> (!phaseC U phaseB))`
  - **Use Case:** Testing wizards, multi-step processes, ensuring setup phases complete before operational phases begin.

These patterns provide a starting point. Complex behaviors often require combining these patterns using logical operators (`and`, `or`, `implies`, `not`).

### Testing Asynchronous Operations

Flutter applications heavily rely on asynchronous operations (`Future`s, `Stream`s) for tasks like network requests, database access, and even complex animations. Testing the temporal behavior surrounding these operations requires careful handling within `flutter_test`.

**Challenges:**

- **Intermediate States:** Async operations often involve multiple state changes (e.g., `initial -> loading -> success` or `initial -> loading -> error`). Capturing *all* relevant intermediate states is crucial for accurate temporal verification.
- **Timing:** For MTL tests, the timing of these state changes relative to the triggering action is the primary focus.

**Techniques:**

1. **State Management Listener (Primary Method):** As shown in the Riverpod example (Section 5.1), using your state management's listener mechanism (`container.listen`, `bloc.stream.listen`) is the most robust way. The listener automatically calls `recorder.record()` whenever the state object updates, regardless of whether it was triggered synchronously or asynchronously.

2. **`tester.pumpAndSettle()`:** This is the most important `flutter_test` utility for async operations.
    - **What it does:** Advances the clock and repeatedly pumps frames until no more frames are scheduled. This allows `Future`s to complete, `Stream` events to be delivered, timers to fire, and animations to finish (within a default timeout).
    - **When to use:** Call `await tester.pumpAndSettle()` *after* performing an action that triggers an asynchronous operation (e.g., tapping a button that fetches data).
    - **Effect on Trace:** This ensures that all state changes resulting from the async operation (and captured by your listener) are recorded *before* you proceed to the `expect` verification step.

    ```dart
    // Action that triggers an async data fetch and state update
    await tester.tap(find.byKey(const Key('fetchButton'))); 
    
    // *** Crucial step ***
    // Allow the fetch Future to complete, the state notifier to update, 
    // and the listener to record the final state (and any intermediates).
    await tester.pumpAndSettle(); 

    // Now the trace should contain states like 'initial', 'loading', 'success/error'
    final trace = recorder.trace;
    expect(trace, satisfiesLtl(/* ... formula checking loading then success/error ... */));
    ```

3. **`tester.pump(Duration duration)`:**
    - **What it does:** Advances the simulated clock by the specified `duration` and pumps a single frame.
    - **When to use:** Less common for typical LTL verification but useful for:
        - **MTL:** Testing properties within specific time windows requires controlling time explicitly.
        - **Animations:** Stepping through an animation frame by frame.
        - **Debouncing/Throttling:** Verifying behavior after a specific delay.
    - **Caution:** `pump` only advances time and processes work scheduled for *that specific frame*. It doesn't guarantee `Future`s complete like `pumpAndSettle` does. You might need multiple `pump` calls or a combination with `pumpAndSettle`.

4. **Fake Time Providers:** For precise control over time in MTL tests, inject a fake `TimeProvider` into your `TraceRecorder` that you can manually advance in your test.

**Summary:** Rely on state listeners to capture all states and use `pumpAndSettle` after triggering actions to ensure async updates are reflected in the trace before verification.

### Handling Transient Events (`loginClicked`)

Events like button clicks, gestures, receiving a single notification, or submitting a form often act as *triggers* for state changes rather than causing a persistent, directly observable change in the main state object itself. For example, clicking 'Login' might immediately trigger an async network call, changing the state to `loading` later, but the 'click' itself isn't stored permanently in the `AppState`.

**Challenge:** If you only record `AppSnap` when the main `AppState` changes via a listener, you might miss the *exact moment* the event occurred. This makes it difficult or impossible to verify formulas that depend on the immediate consequence of the event, such as `G(loginClicked -> X loading)` (Globally, if login was clicked, the *next* state must be loading).

**Solution: Explicit Event Recording**

The solution is to manually record a special `AppSnap` in your test code precisely when the event occurs, marking it with a transient flag.

**Steps:**

1. **Add a Transient Flag to `AppSnap`:** Include a dedicated boolean field in your `AppSnap` class specifically for marking this event (e.g., `final bool loginClicked;`). Ensure it defaults to `false` in the constructor/factory unless explicitly set.

    ```dart
    // In AppSnap class
    final bool transientLoginClick;

    const AppSnap({ 
      // ... other fields
      this.transientLoginClick = false, // Default to false
    });

    factory AppSnap.fromAppState(AppState state, {bool loginClicked = false}) {
      return AppSnap(
        // ... map other fields from state ...
        transientLoginClick: loginClicked, // Use the passed value
      );
    }
    ```

2. **Identify the Trigger in Test:** Locate the line in your `flutter_test` code that simulates the event (e.g., `await tester.tap(...)`, `await tester.enterText(...)`).

3. **Record *Before* Triggering:** *Immediately before* the line that simulates the event, read the current application state and manually call `recorder.record()`, passing the current state but overriding the transient flag to `true`.

    ```dart
    // --- Test Interactions --- 
    
    // Get current state *before* the tap action
    final stateBeforeClick = container.read(appStateProvider);
    
    // *** Manually record the event occurrence ***
    recorder.record(AppSnap.fromAppState(stateBeforeClick, loginClicked: true)); 

    // Now, simulate the actual event
    await tester.tap(find.byKey(const Key('loginButton')));
    
    // Proceed with pumpAndSettle etc.
    await tester.pumpAndSettle();
    ```

4. **Implicit Reset:** The *next* time `recorder.record()` is called (likely by your state listener reacting to the consequence of the tap, or another manual record), the `AppSnap.fromAppState` factory will be called *without* explicitly setting `loginClicked: true`, so the flag will naturally revert to its default `false` value in the subsequent snapshot(s).

5. **Use `event<T>` Proposition:** Define your temporal logic proposition using `tlCore.event<T>` that checks this specific transient flag.

    ```dart
    final loginClicked = tlCore.event<AppSnap>(
      (s) => s.transientLoginClick, 
      name: 'loginClickedEvent'
    );
    
    // Now you can use it in formulas like:
    final formula = tlCore.always(loginClicked.implies(tlCore.next(isLoading)));
    ```

**Why this works:** This technique inserts a unique marker into the trace precisely at the point the event is logically considered to have happened within the test flow. It allows temporal operators like `X` (Next) and timed operators F[0, ...] (Eventually within 0 seconds...) to accurately reason about the state immediately following the event trigger.

### Performance Considerations

While temporal logic testing provides powerful verification capabilities, it's worth being mindful of potential performance implications, primarily within the context of your test suite execution time.

- **Trace Recording Frequency:**
  - **Impact:** If your application state changes very frequently, and your listener records an `AppSnap` for every single change, you can generate very long traces.
  - **Mitigation:**
    - **Selective Recording:** Consider if you *really* need to capture every single intermediate state. Sometimes, filtering or debouncing within your state listener (or only recording specific state transitions) might be acceptable, *but be cautious* as this can hide transient bugs you might want to catch.
    - **Effective `AppSnap`:** A well-designed, minimal `AppSnap` ensures you only record when *relevant* state changes, reducing unnecessary trace events.
    - **Focus Tests:** Write more focused tests with shorter interaction sequences rather than monolithic tests covering huge parts of the application flow, which naturally limits trace length.

- **`AppSnap` Complexity:**
  - **Impact:** Creating the `AppSnap` instance (especially within the `fromAppState` factory) involves reading from your real state and constructing a new object. If this factory does complex calculations or deep copies large data structures, it can add overhead each time `record()` is called.
  - **Mitigation:** Keep the `AppSnap.fromAppState` factory lightweight. Perform simple field assignments and boolean checks. Avoid deep copies or complex computations within the factory.

- **Formula Evaluation Complexity:**
  - **Impact:** Evaluating complex LTL/MTL formulas, especially those involving nested temporal operators or checks over very long traces, takes computational effort.
  - **Mitigation:**
    - **Simpler Formulas:** Where possible, prefer simpler, more direct formulas. Break down complex properties into multiple, smaller, verifiable formulas if feasible.
    - **Trace Length:** As mentioned, keeping traces reasonably short helps evaluation speed.
    - **MTL Precision:** For MTL, using extremely fine-grained `TimeInterval`s might require checking more states, although the impact is usually less significant than overall trace length or formula complexity.

- **Test Execution Time:**
  - **Overall Impact:** The primary effect of the above points is potentially increasing the execution time of your `flutter_test` suite.
  - **Perspective:** Temporal logic tests inherently examine sequences, which often involves more setup and interaction than simple unit tests or widget tests checking a single state. A slight increase in test time is often a worthwhile trade-off for the increased verification power.

**General Recommendations:**

- Start with the simplest `AppSnap` and recording strategy that meets your verification needs.
- Optimize `AppSnap` creation and formula complexity if you observe significant test slowdowns.
- Profile your tests if performance becomes a critical issue, but prioritize correctness and thoroughness of verification first.

In most typical Flutter application testing scenarios, the performance overhead of using these packages is unlikely to be prohibitive, especially compared to the benefits of catching complex temporal bugs.

## 6. More Examples

This section outlines potential application scenarios where temporal logic testing can provide significant value. (Note: These examples are currently conceptual; full implementations may be added later.)

### Form Validation Flow

- **Scenario:** A form with multiple fields, real-time validation, and a submit button that should only be enabled when all fields are valid.
- **Temporal Properties to Verify:**
  - "The submit button is never enabled (`submitEnabled.not()`) unless the form is valid (`formValid`)." (Safety: `G(submitEnabled -> formValid)`)
  - "If an invalid field (`fieldXInvalid`) is corrected, eventually the overall form valid status (`formValid`) becomes true (assuming other fields are valid)." (Liveness: `G(fieldXCorrection -> F(formValid))`)
  - "After submitting (`submitClicked`), the form eventually enters a loading state (`loading`) and then either a success (`success`) or error (`error`) state." (Response Sequence: `G(submitClicked -> F(loading.and(F(success.or(error)))))`)

### Animation Sequence Verification

- **Scenario:** A complex UI animation involving multiple stages or coordinated movements of different elements.
- **Temporal Properties to Verify:**
  - "If the animation starts (`animationStart`), it must eventually reach the end state (`animationEnd`)." (Liveness: `G(animationStart -> F(animationEnd))`)
  - "Phase 2 (`phase2Active`) of the animation never starts until Phase 1 (`phase1Active`) has finished (`phase1Finished`)." (Ordering: `G(phase2Active -> X(!phase1Active.until(phase1Finished)))` - simplified)
  - "The entire animation must complete within 500 milliseconds." (Timed Liveness: `G(animationStart -> F[0ms, 500ms](animationEnd))`)
  - "Element A (`elementAPositioned`) remains in its final position once the animation ends." (Stability: `G(animationEnd -> G(elementAPositioned))`)

### Network Request Lifecycle

- **Scenario:** Managing the states associated with fetching data from a server, including loading indicators and error handling.
- **Temporal Properties to Verify:**
  - "Whenever a request is sent (`requestSent`), a loading indicator (`isLoading`) becomes true immediately or in the next state." (Immediate Response: `G(requestSent -> isLoading.or(X(isLoading)))`)
  - "If a request is sent (`requestSent`), eventually either a success state (`success`) or a failure state (`failure`) must be reached." (Liveness/Completion: `G(requestSent -> F(success.or(failure)))`)
  - "The loading indicator (`isLoading`) must eventually become false after a request is sent." (Liveness/Termination: `G(requestSent -> F(isLoading.not()))`)
  - "If a request fails (`failure`), an error message (`hasError`) is displayed until the user takes an action (`dismissError`)." (State Holding: `G(failure -> hasError.until(dismissError))`)
  - "A request should time out (reach `failure` state) if no success response is received within 10 seconds." (Timed Response: `G(requestSent.and(!success.eventuallyTimed(TimeInterval(Duration.zero, Duration(seconds:10))))) -> F(failure))`)

## 7. Troubleshooting

Here are common issues encountered when writing and running temporal logic tests, along with debugging strategies:

- **Formula Doesn't Evaluate as Expected (Test Fails Logically):**
  - **Symptom:** `expect(trace, satisfiesLtl/Mtl(formula))` fails, but you believe the application logic is correct.
  - **Check Proposition Definitions:**
    - **`state` vs `event`:** Did you use `tlCore.state` for a condition that only holds momentarily, or `tlCore.event` for a condition that persists? Review Section 3 - Propositions: `state` vs `event` and Section 4 - API Reference.
    - **Predicate Logic:** Is the predicate function `(s) => ...` inside `state`/`event` correctly reflecting the condition based on the `AppSnap` fields? Add print statements inside the predicate or test it separately.
    - **`AppSnap` Mapping:** Is the `AppSnap.fromAppState` factory correctly mapping the real application state to the `AppSnap` fields used by the propositions? Verify this mapping logic.
  - **Verify Formula Logic:**
    - **Operator Semantics:** Double-check your understanding of the LTL/MTL operators (X, G, F, U, R, G[], F[]). Are you using the right operator for the property you want to express? Refer to Sections 3 & 4.
    - **Operator Precedence/Grouping:** Use parentheses `()` to ensure logical operators (`and`, `or`, `implies`) and temporal operators combine as intended. `A.implies(B.and(C))` is different from `A.implies(B).and(C)` and `A.implies(B.or(C))` is different from `A.implies(B).or(C)`.
    - **Simplify:** Temporarily comment out parts of a complex formula to isolate which sub-formula is failing.
    - **Visualize/Simulate:** For complex LTL, consider sketching the state sequence on paper or using an online LTL visualizer/model checker (with abstract proposition names) to confirm the formula's behavior in different scenarios.
  - **Inspect the Trace:** The recorded trace is the ground truth for evaluation.
    - **Print the Trace:** Add `print(recorder.trace.events.map((e) => '\${e.timestamp}: \${e.value}').join('\\n'));` (or similar) before the `expect` call to see the exact sequence of `AppSnap` objects and timestamps recorded.
    - **Manual Walkthrough:** Step through the printed trace manually, evaluating your formula at each step (especially around the failure point indicated by the matcher output) to see where it diverges from expectations.
    - **Timestamps (MTL):** For MTL failures, pay close attention to the `timestamp` values in the printed trace. Are they advancing as expected? Is the duration between relevant events correct for your `TimeInterval`s?

- **Test Fails Unexpectedly (Trace Doesn't Match Reality):**
  - **Symptom:** The formula seems correct, but the test fails because the recorded trace doesn't accurately reflect the application's behavior during the test execution.
  - **Check `AppSnap` Creation:** As above, ensure `AppSnap.fromAppState` is correctly translating the live application state.
  - **Check Recorder Listening/Recording:**
    - **Listener Setup:** Is the state listener (`container.listen`, `bloc.stream.listen`) correctly set up *after* the initial state is recorded but *before* interactions begin?
    - **Listener Missed States:** Is the listener capturing *all* relevant intermediate states, especially during rapid state changes or asynchronous operations? State management solutions might debounce or skip intermediate states under certain conditions. Ensure your listener captures every emission if needed.
    - **Manual Recording:** If handling transient events, are you calling `recorder.record(...)` at the *exact right moment* in your test interaction flow?
  - **`pumpAndSettle`/`pump` Usage:**
    - **Insufficient Settling:** Did you `await tester.pumpAndSettle()` *after* every interaction (`tap`, `enterText`, etc.) that triggers asynchronous work or state changes? Sometimes multiple `pumpAndSettle` calls might be needed if there are chained async operations.
    - **Incorrect `pump` Duration:** If using `pump(duration)`, is the duration sufficient for the expected async work to complete or the timer to fire?
    - **Mixing `pump` and `pumpAndSettle`:** Understand the difference. `pump` just advances time; `pumpAndSettle` tries to let all scheduled work finish.

- **Dependency Issues / Setup Errors:**
  - **Symptom:** Test fails during setup, `pub get` issues, type errors.
  - **Check `pubspec.yaml`:** Ensure consistent versions of `temporal_logic_*` packages and Flutter/Dart SDK constraints. Use `path:` dependencies correctly if working within the monorepo.
  - **Run Clean Build:** Execute `flutter clean` and `flutter pub get` to resolve potential caching issues.
  - **Provider Scope:** Ensure your test widget tree is wrapped in the necessary `ProviderScope` (or `BlocProvider`, etc.) if using state management integration.

---
