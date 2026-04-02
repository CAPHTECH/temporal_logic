# temporal_logic_flutter

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
<!-- [![pub package](https://img.shields.io/pub/v/temporal_logic_flutter.svg)](https://pub.dev/packages/temporal_logic_flutter) -->
<!-- [![Build Status](...)](...) -->

`temporal_logic_flutter` is the integration package for using temporal logic from Flutter streams, widgets, and tests.
It re-exports the supported public APIs from `temporal_logic_core` and `temporal_logic_mtl`, and adds stream checkers, widgets, trace recording, and test helpers.

## Features

* **Stream checkers**: `StreamLtlChecker`, `StreamMtlChecker`, `StreamSustainedStateChecker`
* **Widgets**: `LtlCheckerWidget`, `MtlCheckerWidget`, `SustainedStateCheckerWidget`
* **Trace utilities**: `TraceRecorder`
* **Test support**: `satisfiesLtl` is available from `temporal_logic_flutter_test.dart`
* **Shared control types**: `CheckStatus`, `StreamEvaluationStart`

## Getting Started

Add Flutter and the temporal logic packages to `pubspec.yaml`.

```yaml
dependencies:
  flutter:
    sdk: flutter
  temporal_logic_core: ^0.1.1
  temporal_logic_mtl: ^0.3.0
  temporal_logic_flutter: ^0.1.2
```

Then run `flutter pub get`.

## Usage

### LTL widget

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:temporal_logic_core/temporal_logic_core.dart';
import 'package:temporal_logic_flutter/temporal_logic_flutter.dart';

class Demo extends StatelessWidget {
  const Demo({super.key});

  @override
  Widget build(BuildContext context) {
    final isReady = state<bool>((s) => s, name: 'isReady');
    final spec = eventually(isReady);

    return LtlCheckerWidget<bool>(
      stream: Stream<bool>.periodic(const Duration(seconds: 1), (_) => true),
      formula: spec,
      evaluationStart: StreamEvaluationStart.beginning,
      builder: (context, result) => Text(result ? 'ready' : 'waiting'),
    );
  }
}
```

### MTL widget

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:temporal_logic_core/temporal_logic_core.dart';
import 'package:temporal_logic_flutter/temporal_logic_flutter.dart';

class TimedDemo extends StatelessWidget {
  const TimedDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final response = state<String>((s) => s == 'response', name: 'response');
    final spec = EventuallyTimed(
      response,
      TimeInterval.upTo(const Duration(seconds: 1)),
    );

    return MtlCheckerWidget<String>(
      stream: Stream<TimedValue<String>>.value(
        TimedValue(timestamp: Duration.zero, value: 'request'),
      ),
      formula: spec,
      initialValue: TimedValue(timestamp: Duration.zero, value: 'request'),
      builder: (context, holds, details) => Tooltip(
        message: details.reason ?? (holds ? 'holds' : 'fails'),
        child: Icon(
          holds ? Icons.check_circle : Icons.cancel,
        ),
      ),
    );
  }
}
```

### TraceRecorder in tests

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:temporal_logic_core/temporal_logic_core.dart';
import 'package:temporal_logic_flutter/temporal_logic_flutter.dart';
import 'package:temporal_logic_flutter/temporal_logic_flutter_test.dart';

testWidgets('widget follows the LTL rule', (tester) async {
  final recorder = TraceRecorder<bool>();
  recorder.initialize();
  recorder.record(true);
  recorder.record(true);

  final trace = recorder.trace;
  final formula = eventually(state<bool>((s) => s));

  expect(trace, satisfiesLtl(formula));
  expect(evaluateTrace(trace, formula).holds, isTrue);
});
```

## Notes

* The `builder` of `LtlCheckerWidget` receives a `bool`.
* The `builder` of `MtlCheckerWidget` receives a `bool` and an `EvaluationResult`.
* `StreamEvaluationStart.beginning` evaluates from the start of the accumulated trace, while `current` evaluates from the most recent event.
* `TraceRecorder` is an explicit recording utility for tests or application code. Call `initialize` and `record` yourself.
* Use `package:temporal_logic_flutter/temporal_logic_flutter.dart` for runtime code and `package:temporal_logic_flutter/temporal_logic_flutter_test.dart` for tests, and avoid importing from `src/` directly.
* `temporal_logic_flutter_test.dart` re-exports `temporal_logic_flutter.dart` together with the matcher helpers.
