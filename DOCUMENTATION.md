# Temporal Logic Packages for Flutter & Dart - Detailed Documentation

Welcome to the detailed documentation for the `temporal_logic_core`, `temporal_logic_mtl`, and `temporal_logic_flutter` packages. This guide aims to provide a comprehensive understanding of the concepts, APIs, and best practices for using temporal logic to specify and verify the behavior of your Dart and Flutter applications.

**Table of Contents:**

- [Temporal Logic Packages for Flutter \& Dart - Detailed Documentation](#temporal-logic-packages-for-flutter--dart---detailed-documentation)
  - [1. Introduction](#1-introduction)
    - [Why Temporal Logic?](#why-temporal-logic)
    - [Package Overview](#package-overview)
  - [2. Getting Started](#2-getting-started)
    - [Installation](#installation)
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
      - [Matchers (`satisfiesLtl`, `satisfiesMtl`)](#matchers-satisfiesltl-satisfiesmtl)
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

Modern applications, especially UI-rich Flutter apps, involve complex sequences of events, state changes, and timing. Bugs arising from incorrect ordering, timing issues, or unexpected state interactions can be hard to catch with traditional testing methods that focus on static states or final outcomes.

Temporal Logic (LTL and MTL) provides a formal language to precisely describe and verify properties *over time*.

- **LTL (Linear Temporal Logic):** Specifies properties about the *order* of events and states (e.g., "event A must *eventually* be followed by state B").
- **MTL (Metric Temporal Logic):** Extends LTL with *quantitative time constraints* (e.g., "event A must be followed by state B *within 5 seconds*").

Using these packages allows you to:

- **Clearly Specify Behavior:** Define intended temporal behavior unambiguously.
- **Improve Testability:** Design tests targeting complex temporal scenarios and race conditions.
- **Catch Subtle Bugs:** Detect issues like transient incorrect states (flickers) or violations of required sequences.

### Package Overview

- **`packages/temporal_logic_core`**: Foundational interfaces, LTL formula construction, and basic trace structures.
- **`packages/temporal_logic_mtl`**: MTL implementation, adding timed operators and evaluation for timed traces.
- **`packages/temporal_logic_flutter`**: Flutter-specific integrations, including `TraceRecorder` for capturing state sequences and `flutter_test` Matchers (`satisfiesLtl`, `satisfiesMtl`).

## 2. Getting Started

### Installation

Add dependencies to your `pubspec.yaml`. For development within this monorepo, use `path` dependencies:

```yaml
# Example for an app/example using the packages
dependencies:
  flutter:
    sdk: flutter
  # Add packages you need:
  temporal_logic_flutter:
    path: ../packages/temporal_logic_flutter # Adjust path as needed

# Ensure transitive dependencies are also using paths if needed:
dependency_overrides:
  temporal_logic_core:
    path: ../packages/temporal_logic_core # Adjust path as needed
  temporal_logic_mtl:
    path: ../packages/temporal_logic_mtl # Adjust path as needed

dev_dependencies:
  flutter_test:
    sdk: flutter
```

Run `flutter pub get`.

### Your First LTL Test (Login Flow Example)

The `examples/login_flow_ltl` provides a practical starting point. Here's the essence of its test (`test/widget_test.dart` using external recording):

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login_flow_ltl_example/main.dart'; // Your app
import 'package:temporal_logic_core/temporal_logic_core.dart' as tlCore;
import 'package:temporal_logic_flutter/temporal_logic_flutter.dart' as tlFlutter;

void main() {
  testWidgets('Successful login flow satisfies LTL formula', (tester) async {
    // 1. Setup Recorder and Container (No App Code Modification)
    final recorder = tlFlutter.TraceRecorder<AppSnap>();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    recorder.initialize();

    // 2. Record Initial State & Listen for Changes
    final initialState = container.read(appStateProvider); // Assuming Riverpod
    recorder.record(AppSnap.fromAppState(initialState));
    container.listen<AppState>(appStateProvider, (prev, next) {
      recorder.record(AppSnap.fromAppState(next));
    });

    // 3. Pump Widget
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.pumpAndSettle();

    // 4. Simulate Interaction
    await tester.enterText(find.byKey(const Key('email')), 'valid@email.com');
    await tester.tap(find.byKey(const Key('login')));
    await tester.pumpAndSettle(); // Allow state changes to be recorded

    // 5. Define Propositions & Formula
    final loading = tlCore.state<AppSnap>((s) => s.isLoading, name: 'loading');
    final home = tlCore.state<AppSnap>((s) => s.isOnHomeScreen, name: 'home');
    final error = tlCore.state<AppSnap>((s) => s.hasError, name: 'error');
    final loginClicked = tlCore.event<AppSnap>((s) => s.loginClicked, name: 'loginClicked');

    // G(loginClicked -> (X loading && F home && G !error))
    final formula = tlCore.always(
      loginClicked.implies(
        tlCore.next(loading)
        .and(tlCore.eventually(home))
        .and(tlCore.always(error.not()))
      )
    );

    // 6. Verify Trace
    final trace = recorder.trace;
    expect(trace, tlFlutter.satisfiesLtl(formula));
  });
}
```

*(This section provides a high-level overview. Subsequent sections detail the concepts and APIs)*

## 3. Core Concepts

### Traces and Timestamps

- A **Trace** (`Trace<T>`) represents a sequence of application states (`T`) over time.
- Each element in the trace is a **TraceEvent<T>** containing the state (`value`) and its timestamp (`timestamp`).
- Timestamps are typically `Duration` objects representing time since the start of the recording or a fixed epoch.
- The `TraceRecorder` automatically assigns timestamps when `record()` is called.

### State Snapshots (`AppSnap`)

- The generic type `T` in `Trace<T>` represents a snapshot of your application's state relevant to the properties you want to verify.
- This is often an immutable custom class (like `AppSnap` in the example) containing boolean flags or enum values derived from your actual application state (e.g., from your Riverpod `AppState`).
- **Design Principle:** Include only the state aspects needed for your temporal formulas. Keep it minimal but sufficient. Make it immutable and implement `==` and `hashCode`.

### Propositions: `state` vs `event`

Temporal logic formulas are built upon **Atomic Propositions**, which are basic statements about a state snapshot that can be true or false.

- **`tlCore.state<T>(Predicate<T> predicate, {String? name})`**:
  - Represents a condition that holds *while* the application is in a certain state.
  - The `predicate` function evaluates to `true` if the condition holds for the given state snapshot `T`.
  - Example: `final loading = tlCore.state<AppSnap>((s) => s.isLoading);` (True whenever `isLoading` is true in the snapshot).
- **`tlCore.event<T>(Predicate<T> predicate, {String? name})`**:
  - Represents something that happens *at a specific point in time*, often marking the *start* of a state or an action occurrence.
  - Technically, it evaluates the `predicate` on the *current* state, but its interpretation in LTL formulas often relates to transitions or occurrences.
  - Used to capture momentary flags or signals (like `loginClicked` in the example, which was true only in the single snapshot immediately after the button tap).
  - **Key Difference:** `state` typically describes duration, while `event` describes instantaneous occurrence or the beginning of a state. The choice affects how operators like `next` or `always` interpret the formula.

### Linear Temporal Logic (LTL) Basics

LTL reasons about properties along a linear sequence of states (the trace). Key operators provided by `temporal_logic_core` (used via extension methods on `Formula`):

- **`next(formula)` (X)**: `formula` must hold in the *next* state of the trace.
- **`always(formula)` (G)**: `formula` must hold in the *current* state AND *all future* states.
- **`eventually(formula)` (F)**: `formula` must hold in the *current* state OR *some future* state.
- **`until(formula1, formula2)` (U)**: `formula1` must hold *at least until* `formula2` holds. `formula2` must hold in the current or a future state.
- **`release(formula1, formula2)` (R)**: `formula2` must hold *up to and including* the point where `formula1` first holds. If `formula1` never holds, `formula2` must hold forever. (Dual of Until).
- Standard logical operators (`and`, `or`, `not`, `implies`) combine these.

### Metric Temporal Logic (MTL) Basics

MTL extends LTL by adding time constraints to temporal operators. Provided by `temporal_logic_mtl`.

- **`TimeInterval(Duration start, Duration end, {bool startInclusive, bool endInclusive})`**: Defines a time window.
- **`alwaysTimed(formula, TimeInterval interval)` (G[a,b])**: `formula` must hold at all future states within the specified `interval` relative to the current time.
- **`eventuallyTimed(formula, TimeInterval interval)` (F[a,b])**: `formula` must hold at some future state within the specified `interval` relative to the current time.
- Evaluation requires a `Trace` with meaningful timestamps and the `evaluateMtlTrace` function.

## 4. API Reference

*(This section would contain detailed descriptions of each class and function, similar to Dartdoc, but potentially more narrative)*

### `temporal_logic_core` API

#### Formula<T>

*(Abstract base class for all formulas)*

#### AtomicProposition<T>

*(Represents a basic true/false statement about state T)*

- `bool predicate(T state)`
- `String name`

#### Logical Operators (`and`, `or`, `not`, `implies`)

- `formula1.and(formula2)`

- `formula1.or(formula2)`
- `formula.not()`
- `formula1.implies(formula2)`

#### LTL Operators (`next`, `always`, `eventually`, `until`, `release`)

- `formula.next()` or `tlCore.next(formula)`

- `formula.always()` or `tlCore.always(formula)`
- `formula.eventually()` or `tlCore.eventually(formula)`
- `formula1.until(formula2)` or `tlCore.until(formula1, formula2)`
- `formula1.release(formula2)` or `tlCore.release(formula1, formula2)`

#### Helper Functions (`state`, `event`)

- `tlCore.state<T>(...)`

- `tlCore.event<T>(...)`

### `temporal_logic_mtl` API

#### TimeInterval

- `Duration start`

- `Duration end`
- `bool startInclusive`
- `bool endInclusive`

#### Timed Operators (`alwaysTimed`, `eventuallyTimed`)

- `formula.alwaysTimed(interval)` or `tlMtl.alwaysTimed(formula, interval)`

- `formula.eventuallyTimed(interval)` or `tlMtl.eventuallyTimed(formula, interval)`

#### Evaluation (`evaluateMtlTrace`)

- `EvaluationResult evaluateMtlTrace<T>(Trace<T> trace, Formula<T> formula, {int startIndex = 0})`

- `EvaluationResult` properties: `bool holds`, `String? reason`

### `temporal_logic_flutter` API

#### TraceRecorder<T>

- `TraceRecorder({Duration interval = const Duration(milliseconds: 100), TimeProvider timeProvider = const WallClockTimeProvider()})` (Note: Current example uses `interval: Duration.zero` for manual recording)

- `void initialize()`
- `void record(T state)`
- `Trace<T> get trace`
- `void dispose()`

#### Matchers (`satisfiesLtl`, `satisfiesMtl`)

- `Matcher satisfiesLtl<T>(Formula<T> formula)`

- `Matcher satisfiesMtl<T>(Formula<T> formula)` (Assumes this exists or `satisfiesLtl` handles both)
  - Used with `expect(trace, satisfiesLtl(formula))`
  - Used with `expect(trace, isNot(satisfiesLtl(formula)))`

## 5. Cookbook & Best Practices

*(This section would provide practical advice and code snippets)*

### Integrating with State Management (Riverpod Example)

*(Show the external recording setup using `container.listen`)*

### Designing Effective `AppSnap` Types

*(Immutability, relevant state, `==`/`hashCode`)*

### Common LTL/MTL Patterns

- **Response:** `G(request -> F(response))`

- **Safety (Invariant):** `G(!errorState)`
- **Liveness:** `G(action -> F(completion))`
- **Timed Response:** `G(request -> F[0, 5s](response))`
- **No Flicker:** `G(loading -> G(!error))`

### Testing Asynchronous Operations

*(Using `pumpAndSettle`, ensuring listeners capture all intermediate states)*

### Handling Transient Events (`loginClicked`)

*(Using a boolean flag in `AppSnap` that is true only for one snapshot)*

### Performance Considerations

*(Minimize `AppSnap` size, recording frequency vs detail, impact on tests)*

## 6. More Examples

*(Brief descriptions and links to potential future example directories)*

### Form Validation Flow

*(e.g., Submit button enabled only `G(formValid -> submitEnabled)`)*

### Animation Sequence Verification

*(e.g., `G(animationStart -> F(phase1) && F(phase2) && F(animationEnd))` with timing)*

### Network Request Lifecycle

*(e.g., `G(requestSent -> F(responseReceived || requestFailed))`)*

## 7. Troubleshooting

- **Formula doesn't evaluate as expected:** Check proposition definitions (`state` vs `event`), operator semantics, trace contents.
- **Test fails unexpectedly:** Verify `AppSnap` captures correct state, listener records all relevant transitions, `pumpAndSettle` is used correctly.
- **Dependency Issues:** Ensure consistent use of `path` dependencies if working locally.

---

This documentation provides a comprehensive guide. For specific API details always refer to the source code and Dartdoc comments.
