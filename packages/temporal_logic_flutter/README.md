# temporal_logic_flutter

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
<!-- [![pub package](https://img.shields.io/pub/v/temporal_logic_flutter.svg)](https://pub.dev/packages/temporal_logic_flutter) -->
<!-- [![Build Status](...)](...) -->

`temporal_logic_flutter` は、Flutter の stream や widget から temporal logic を扱うための統合パッケージです。
`temporal_logic_core` と `temporal_logic_mtl` の公開 API を再公開しながら、stream checker、widget、trace recorder、test matcher をまとめて提供します。

## Features

* **Stream checkers**: `StreamLtlChecker`, `StreamMtlChecker`, `StreamSustainedStateChecker`
* **Widgets**: `LtlCheckerWidget`, `MtlCheckerWidget`, `SustainedStateCheckerWidget`
* **Trace utilities**: `TraceRecorder`
* **Test support**: `temporal_logic_flutter_test.dart` から `satisfiesLtl` matcher を利用可能
* **Shared control types**: `CheckStatus`, `StreamEvaluationStart`

## Getting Started

`pubspec.yaml` に Flutter と temporal logic の依存関係を追加します。

```yaml
dependencies:
  flutter:
    sdk: flutter
  temporal_logic_core: ^0.1.1
  temporal_logic_mtl: ^0.3.0
  temporal_logic_flutter: ^0.1.2
```

その後 `flutter pub get` を実行します。

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

* `LtlCheckerWidget` の `builder` は `bool` を受け取ります。
* `MtlCheckerWidget` の `builder` は `bool` と `EvaluationResult` を受け取ります。
* `StreamEvaluationStart.beginning` は蓄積 trace の先頭から評価し、`current` は最新イベントから評価します。
* `TraceRecorder` は widget ではなく、テストやアプリ側から明示的に `initialize` と `record` を呼ぶ記録ユーティリティです。
* アプリ本体は `package:temporal_logic_flutter/temporal_logic_flutter.dart`、テストは `package:temporal_logic_flutter/temporal_logic_flutter_test.dart` を正規の入口として使い、`src/` への直接 import は避けます。
* `temporal_logic_flutter_test.dart` は `temporal_logic_flutter.dart` と matcher を再公開します。
