# temporal_logic_mtl

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
<!-- [![pub package](https://img.shields.io/pub/v/temporal_logic_mtl.svg)](https://pub.dev/packages/temporal_logic_mtl) -->
<!-- [![Build Status](...)](...) -->

`temporal_logic_mtl` は `temporal_logic_core` の上に Metric Temporal Logic (MTL) を追加します。
時間区間つきの演算子と、`Trace<T>` に対する `evaluateMtlTrace` を公開します。

## Features

* **Time intervals**: `TimeInterval`, `TimeInterval.exactly`, `TimeInterval.upTo`, `TimeInterval.atLeast`, `TimeInterval.always`
* **Timed operators**: `EventuallyTimed`, `AlwaysTimed`, `UntilTimed`, `ReleaseTimed`, `WeakUntilTimed`
* **Unified evaluation**: `evaluateMtlTrace` は MTL だけでなく、pure LTL の `Formula` も評価できます
* **Core re-exports**: `Formula`, `Trace`, `TraceEvent`, `TimedValue`, `EvaluationResult`, LTL の builder DSL も再公開します

## Getting Started

`pubspec.yaml` に `temporal_logic_core` と `temporal_logic_mtl` を追加します。

```yaml
dependencies:
  temporal_logic_core: ^0.1.1
  temporal_logic_mtl: ^0.3.0
```

その後 `flutter pub get` または `dart pub get` を実行します。

## Usage

```dart
import 'package:temporal_logic_core/temporal_logic_core.dart';
import 'package:temporal_logic_mtl/temporal_logic_mtl.dart';

void main() {
  final request = state<String>((s) => s == 'request', name: 'request');
  final response = state<String>((s) => s == 'response', name: 'response');

  final spec = always(
    request.implies(
      EventuallyTimed(
        response,
        TimeInterval(
          const Duration(milliseconds: 3),
          const Duration(milliseconds: 5),
        ),
      ),
    ),
  );

  final trace = Trace([
    TraceEvent(timestamp: const Duration(milliseconds: 0), value: 'idle'),
    TraceEvent(timestamp: const Duration(milliseconds: 1), value: 'request'),
    TraceEvent(timestamp: const Duration(milliseconds: 4), value: 'response'),
  ]);

  final result = evaluateMtlTrace(trace, spec);
  print(result.holds);
  print(result.reason);
}
```

## Notes

* `evaluateMtlTrace` は timed trace を前提に評価します。
* pure LTL の `Formula` を渡した場合も、そのまま評価できます。
* 利用時は `package:temporal_logic_mtl/temporal_logic_mtl.dart` を正規の入口として使い、`src/` への直接 import は避けます。
* 旧来の `checkEventuallyWithin`、`checkAlwaysWithin`、`checkUntilWithin` は削除しました。移行例は [MIGRATION.md](../../MIGRATION.md) にまとめています。
