# temporal_logic_core

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
<!-- [![pub package](https://img.shields.io/pub/v/temporal_logic_core.svg)](https://pub.dev/packages/temporal_logic_core) -->
<!-- [![Build Status](...)](...) -->

`temporal_logic_core` は、命題論理と Linear Temporal Logic (LTL) の共通基盤を提供します。
AST、Trace、評価結果、そして `evaluateTrace` / `evaluateLtl` の入口をまとめて公開します。

## Features

* **AST**: `Formula`, `AtomicProposition`, `Not`, `And`, `Or`, `Implies`, `Next`, `Always`, `Eventually`, `Until`, `WeakUntil`, `Release`
* **Trace model**: `Trace`, `TraceEvent`, `TimedValue`
* **Evaluation**: `evaluateTrace` による trace ベースの評価と、`evaluateLtl` による簡易 LTL 評価
* **Result details**: `EvaluationResult` に `holds`, `reason`, `relatedIndex`, `relatedTimestamp` を保持
* **Builder DSL**: `state`, `event`, `next`, `always`, `eventually`, `until`, `weakUntil`, `release`

## Getting Started

`pubspec.yaml` に追加します。

```yaml
dependencies:
  temporal_logic_core: ^0.1.0
```

その後 `flutter pub get` または `dart pub get` を実行します。

## Usage

```dart
import 'package:temporal_logic_core/temporal_logic_core.dart';

void main() {
  final isPositive = state<int>((s) => s > 0, name: 'isPositive');
  final isEven = state<int>((s) => s % 2 == 0, name: 'isEven');
  final formula = always(isPositive.implies(isEven));

  final trace = Trace.fromList([2, 4, 6, 7, 8]);
  final result = evaluateTrace(trace, formula);

  print(result.holds);
  print(result.reason);
  print(result.relatedIndex);
  print(result.relatedTimestamp);
}
```

`Trace.fromList` は順序に基づいて trace を作るときに便利です。timestamp を明示したい場合は `Trace([TraceEvent(...), ...])` を使います。

## Notes

* `evaluateTrace` は trace 上の本体の評価入口です。
* `evaluateLtl` は「状態列だけを見たい」場合の補助関数です。
* `EvaluationResult` は public API として再公開されています。
