# リファクタリング分析レポート

**対象リポジトリ**: `temporal_logic`
**分析日**: 2026-04-02
**対象範囲**: ワークスペース全体。ただし優先度判定は `temporal_logic_core`、`temporal_logic_mtl`、`temporal_logic_flutter` の公開面と評価系を中心に実施
**確認した基準**:
- `mise exec -- flutter analyze`
- `mise exec -- flutter test` in `packages/temporal_logic_core`
- `mise exec -- flutter test` in `packages/temporal_logic_mtl`
- `mise exec -- flutter test` in `packages/temporal_logic_flutter`
- `git log --format=format: --name-only | grep -v '^$' | sort | uniq -c | sort -rn`
- `rg` によるシンボル参照数、公開 export、重複箇所の確認

## Executive Summary

- 現在のコードベースは、正しさの観点ではかなり安定しています。`core`、`mtl`、`flutter` の各パッケージでテストはすべて通過し、静的解析も警告なしです。
- 大きかった構造負債は、すでに主要部分が解消済みです。`mtl_operators.dart` の分割、`evaluateTrace` / `evaluateMtlTrace` の共通化、`StreamLtlChecker` / `StreamMtlChecker` と widget ライフサイクルの共通化まで完了しています。
- package library を正規の公開入口として明文化し、公開 export は回帰テストで固定しました。旧来の MTL helper は削除し、移行案内も追加しています。
- 残る課題は、構造上の大きな負債ではなく、公開 API と changelog を今後も実装に同期し続ける運用です。

### Overall Health Score

**94 / 100**

判定理由:
- 正しさのベースラインは強い。3 パッケージのテストが通過している。
- 構造負債の大きい箇所はすでに主要部分が解消された。
- 残る課題は、公開面の整理と互換資産の扱いに集約されている。

### Priority Breakdown

- Critical: 0
- Medium: 0
- Low: 1

## Baseline

### 検証結果

| 項目 | 結果 |
|------|------|
| `flutter analyze` | 問題なし |
| `temporal_logic_core` tests | 全件通過 |
| `temporal_logic_mtl` tests | 全件通過 |
| `temporal_logic_flutter` tests | 全件通過 |

### 完了済み項目

- `mtl_operators.dart` の分割と `mtl_evaluator.dart` の整理は完了しています。
- `evaluateTrace` と `evaluateMtlTrace` の LTL 部分は shared helper に寄せられました。
- `StreamLtlChecker` / `StreamMtlChecker` と `LtlCheckerWidget` / `MtlCheckerWidget` のライフサイクル共通化は完了しています。
- `checker_parity_test.dart`、`checker_widget_parity_test.dart`、`evaluation_result_parity_test.dart` で、pure LTL の parity と widget の再初期化条件が固定されています。
- README は現行の export とコンストラクタに合わせて更新済みです。
- `public_api_exports_test.dart` で、`core`、`mtl`、`flutter` の公開入口を固定しています。
- `MIGRATION.md`、root `README.md`、各パッケージの `CHANGELOG.md` を更新し、利用者向けの移行案内を整えました。

### しきい値に対する要点

今回の基準は refactoring スキルの `design-standards.md` を参考にしています。ただし、その基準は TypeScript 向けの記述が多いため、Dart では次の項目を主に使いました。

- ファイル長しきい値: 400 行
- 単一責務の目安: 1 つの主要責務と補助責務 1 つまで
- import 数や循環依存より、公開面と重複実装を重視

## Completed Work

### 1. MTL 評価器の分割と整理

- `mtl_operators.dart` は AST と評価器と旧 API を抱え込む形から分割済みです。
- 現在は `mtl_ast.dart` と `mtl_evaluator.dart` に責務が分かれ、`evaluateMtlTrace` は package library から直接公開されています。
- LTL の評価ロジックは core 側の共通 helper に寄せられ、二重修正のリスクが大きく下がりました。

### 2. Stream checker と widget の共通化

- `StreamLtlChecker` / `StreamMtlChecker` は lifecycle を共通基盤に寄せています。
- `LtlCheckerWidget` / `MtlCheckerWidget` も `initState`、再初期化、破棄処理、`StreamBuilder` の扱いを共有しています。
- これにより、LTL と MTL の UI と stream 層の重複はほぼ解消されています。

### 3. Evaluator 一本化

- `EvaluationResult` を内部ファイルへ分離し、`evaluateTrace` は shared helper を経由する形に整理済みです。
- pure LTL に対しては `evaluateTrace` と `evaluateMtlTrace` の詳細結果も揃っています。

### 4. README 同期

- `temporal_logic_core`、`temporal_logic_mtl`、`temporal_logic_flutter` の README を、現在の export とコンストラクタに合わせて更新済みです。
- Flutter README からは古い `checker:` や `statusStream` の前提を外しました。

### 5. 公開 API 方針の固定と旧来ヘルパーの削除

- `temporal_logic_core.dart`、`temporal_logic_mtl.dart`、`temporal_logic_flutter.dart`、`temporal_logic_flutter_test.dart` を stable public entry point として明文化しました。
- `temporal_logic_mtl.dart` は compatibility facade ではなく、timed evaluator と timed AST を直接公開する形に整理しました。
- `checkEventuallyWithin`、`checkAlwaysWithin`、`checkUntilWithin` は削除し、移行先を `MIGRATION.md` にまとめました。

## Current Focus

### Low 1: 公開 API と変更履歴の同期を維持する

**対象**:
- `README.md`
- `MIGRATION.md`
- `packages/*/CHANGELOG.md`

**評価軸**

| 指標 | 値 | 根拠 |
|------|---:|------|
| Complexity | 1/5 | 実装の複雑さは低い |
| Coupling | 2/5 | ドキュメントと公開面の同期が中心 |
| Bug Risk | 1/5 | 主に案内のずれを防ぐ作業 |
| Coverage Confidence | 4/5 | 公開 export はテストで固定済み |
| Blast Radius | 3/5 | 利用者向けの案内には影響する |
| Effort | 1/5 | 小さく継続できる |

**優先度**: Low

**最初に着手するなら何を分割するか**

- release 前チェックに changelog と migration の更新確認を加える。
- package library 以外の import が増えていないかを `rg` で点検する。

## Metrics Summary

### 主要ファイルの規模と変更履歴

| ファイル | LOC | コミット数 | 備考 |
|------|---:|---:|------|
| `packages/temporal_logic_mtl/lib/src/mtl_evaluator.dart` | 160 | 1 | timed 拡張の中心 |
| `packages/temporal_logic_flutter/lib/src/mtl_checker_widget.dart` | 156 | 3 | 共通基盤の上で `EvaluationResult` を UI に橋渡しする薄いラッパー |
| `packages/temporal_logic_mtl/lib/src/mtl_ast.dart` | 144 | 1 | MTL AST の主な定義 |
| `packages/temporal_logic_core/lib/src/evaluator.dart` | 137 | 4 | core LTL の入口 |
| `packages/temporal_logic_flutter/lib/src/ltl_checker_widget.dart` | 135 | 3 | 共通基盤の上で `bool` 結果を UI に橋渡しする薄いラッパー |
| `packages/temporal_logic_flutter/lib/src/formula_stream_checker_base.dart` | 109 | 2 | stream checker の共通基盤 |
| `packages/temporal_logic_flutter/lib/src/stream_ltl_checker.dart` | 90 | 4 | trace 共通基盤を使う LTL checker |
| `packages/temporal_logic_core/lib/src/evaluation_result.dart` | 73 | 1 | result 型の分離先 |
| `packages/temporal_logic_flutter/lib/src/stream_mtl_checker.dart` | 71 | 5 | trace 共通基盤を使う timed checker |

### 補足

- 以前は `mtl_operators.dart` が高い分岐密度を持つ中心的な負債でしたが、現在は軽量な compatibility facade へ縮小されています。
- stream checker と widget も共通基盤に寄せられたため、現在の論点は複雑度より公開面と互換資産の管理に移っています。

### 参照の広さ

| シンボル | 参照範囲 |
|------|------|
| `evaluateMtlTrace` | README、`mtl` の tests、Flutter widget、Flutter checker、example test |
| `StreamLtlChecker` | README、widget、専用 test、parity test |
| `StreamMtlChecker` | README、widget、専用 test、parity test |

## Recommended Refactoring Sequence

1. changelog と migration を release ごとに更新する
2. package library 以外の import が広がっていないかを定期確認する
3. 公開 export の回帰テストを新しい入口追加時に更新する

## すぐに実装へ移るなら

### 最初の実装単位

- Step 1: release 前チェックに `MIGRATION.md`、root `README.md`、`packages/*/CHANGELOG.md` の更新確認を入れる
- Step 2: export を追加したときは `public_api_exports_test.dart` も同時に更新する

### 先に守るべき振る舞い固定

- `packages/temporal_logic_mtl/test/evaluation_result_parity_test.dart`
- `packages/temporal_logic_mtl/test/semantics_matrix_test.dart`
- `packages/temporal_logic_mtl/test/pbt_properties_test.dart`
- `packages/temporal_logic_flutter/test/checker_parity_test.dart`
- `packages/temporal_logic_flutter/test/checker_widget_parity_test.dart`
- `packages/temporal_logic_flutter/test/checker_widget_reinitialization_test.dart`
- `packages/temporal_logic_flutter/test/stream_ltl_checker_test.dart`
- `packages/temporal_logic_flutter/test/stream_mtl_checker_test.dart`
- `packages/temporal_logic_flutter/test/ltl_checker_widget_test.dart`
- `packages/temporal_logic_flutter/test/mtl_checker_widget_test.dart`

## Assumptions

- 今回の成果物には、公開面の回帰テスト、旧来 helper の削除、変更履歴と移行案内の整備が含まれます。
- TypeScript 向け基準は、そのままの数値ではなく、Dart 向けに LOC、責務分離、公開面、重複実装の観点へ読み替えて使いました。
- 優先度は「壊れているか」よりも、「次の変更で二重修正や API 分岐が増えるか」を重視して付けました。
