# リファクタリング分析レポート

**対象リポジトリ**: `temporal_logic`
**分析日**: 2026-04-02
**対象範囲**: ワークスペース全体。ただし優先度判定は `temporal_logic_mtl` と `temporal_logic_flutter` の評価系を中心に実施
**確認した基準**:
- `mise exec -- flutter analyze`
- `mise exec -- flutter test` in `packages/temporal_logic_core`
- `mise exec -- flutter test` in `packages/temporal_logic_mtl`
- `mise exec -- flutter test` in `packages/temporal_logic_flutter`
- `git log --format=format: --name-only | grep -v '^$' | sort | uniq -c | sort -rn`
- `rg` によるシンボル参照数、公開 export、重複箇所の確認

## Executive Summary

- 現在のコードベースは、正しさの観点ではかなり安定しています。`core`、`mtl`、`flutter` の各パッケージでテストはすべて通過し、静的解析も警告なしになりました。
- 直近で大きかった構造負債はすでに解消済みです。`mtl_operators.dart` の分割、`evaluateTrace` / `evaluateMtlTrace` の共通化、`StreamLtlChecker` / `StreamMtlChecker` と widget ライフサイクルの共通化まで完了しています。
- 次の優先課題は、stream checker の trace 保持と評価前処理の共通化をさらに進めること、pure LTL の parity と metadata をテストでより強く固定すること、そして公開 API の整理方針を固めることです。

### Overall Health Score

**90 / 100**

判定理由:
- 正しさのベースラインは強い。3 パッケージのテストが通過している。
- 構造負債の大きい箇所はすでに主要部分が解消された。
- 残る課題は、ストリーム層の trace 持ち方と、公開 API をどこまでまとめるかの判断に集約されている。

### Priority Breakdown

- Critical: 0
- Medium: 2
- Low: 2

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
- `evaluateTrace` と `evaluateMtlTrace` の LTL 部分は共通 helper に寄せられました。
- `StreamLtlChecker` / `StreamMtlChecker` と `LtlCheckerWidget` / `MtlCheckerWidget` のライフサイクル共通化は完了しています。
- 以前の analyzer warning 2 件は解消済みです。

### しきい値に対する要点

今回の基準は refactoring スキルの `design-standards.md` を参考にしています。ただし、その基準は TypeScript 向けの記述が多いため、Dart では次の項目を主に使いました。

- ファイル長しきい値: 400 行
- 単一責務の目安: 1 つの主要責務と補助責務 1 つまで
- import 数や循環依存より、公開面と重複実装を重視

## Completed Work

### 1. MTL 評価器の分割と整理

- `mtl_operators.dart` は AST と評価器と旧 API を抱え込む形から分割済みです。
- 現在は `mtl_ast.dart`、`mtl_evaluator.dart`、`mtl_legacy_helpers.dart` に責務が分かれ、`evaluateMtlTrace` は薄い入口になっています。
- LTL の評価ロジックは core 側の共通 helper に寄せられ、二重修正のリスクが大きく下がりました。

### 2. Stream checker と widget の共通化

- `StreamLtlChecker` / `StreamMtlChecker` は lifecycle を共通基盤に寄せています。
- `LtlCheckerWidget` / `MtlCheckerWidget` も `initState`、再初期化、破棄処理、`StreamBuilder` の扱いを共有しています。
- これにより、LTL と MTL の UI と stream 層の重複は「残りの trace 組み立て差分」にほぼ絞られました。

### 3. Evaluator 一本化

- `EvaluationResult` を内部ファイルへ分離し、`evaluateTrace` は shared helper を経由する形に整理済みです。
- pure LTL に対しては `evaluateTrace` と `evaluateMtlTrace` の詳細結果も揃っています。

## Current Focus

### Medium 1: Stream checker の trace 共通化をもう一段進める

**対象**:
- `packages/temporal_logic_flutter/lib/src/stream_ltl_checker.dart`
- `packages/temporal_logic_flutter/lib/src/stream_mtl_checker.dart`

**評価軸**

| 指標 | 値 | 根拠 |
|------|---:|------|
| Complexity | 3/5 | 2 つの checker は簡潔だが、内部 trace の持ち方がまだ別 |
| Coupling | 4/5 | 初期評価、追記、評価開始位置の組み立てが重複 |
| Bug Risk | 3/5 | 片方だけ修正すると parity が崩れやすい |
| Coverage Confidence | 5/5 | checker と widget のテストは既にある |
| Blast Radius | 4/5 | public export 済みで利用範囲が広い |
| Effort | 3/5 | trace 型の差を吸収する設計が必要 |

**優先度**: Medium

**最初に着手するなら何を分割するか**

- trace の構築と `evaluate` 呼び出しを分ける共通 helper を追加する。
- LTL と MTL の違いは「入力型」と「結果型」だけに縮める。

### Medium 2: parity テストを metadata まで含めて強化する

**対象**:
- `packages/temporal_logic_flutter/test/checker_parity_test.dart`
- `packages/temporal_logic_mtl/test/evaluation_result_parity_test.dart`
- `packages/temporal_logic_core/test/evaluator_test.dart`

**評価軸**

| 指標 | 値 | 根拠 |
|------|---:|------|
| Complexity | 2/5 | テストの追加で固定できる |
| Coupling | 3/5 | core / mtl / flutter の境界をまたぐ |
| Bug Risk | 3/5 | metadata の差分は回帰しやすい |
| Coverage Confidence | 5/5 | 既存の parity / property-based テストが厚い |
| Blast Radius | 3/5 | public API には触れない |
| Effort | 2/5 | ケース追加が中心 |

**優先度**: Medium

**最初に着手するなら何を分割するか**

- `holds` だけではなく `reason` と位置情報を比較する共通アサーションを追加する。
- `StreamEvaluationStart.current` と `beginning` の両方で一致を確認する。

### Low 1: 公開 API 整理の方針を明確にする

**対象**:
- `packages/temporal_logic_flutter/lib/temporal_logic_flutter.dart`
- `packages/temporal_logic_mtl/lib/temporal_logic_mtl.dart`
- `packages/temporal_logic_core/lib/temporal_logic_core.dart`

**評価軸**

| 指標 | 値 | 根拠 |
|------|---:|------|
| Complexity | 2/5 | export の整理が中心 |
| Coupling | 3/5 | 3 パッケージの見え方に影響する |
| Bug Risk | 2/5 | 振る舞いより見せ方の変更が主 |
| Coverage Confidence | 4/5 | export 追加の軽いテストがある |
| Blast Radius | 4/5 | 利用者の import 面に直結する |
| Effort | 2/5 | 方針決定後は小さく進められる |

**優先度**: Low

**最初に着手するなら何を分割するか**

- まず `flutter` の export 面を「公開したいもの」と「内部の互換資産」に分けて一覧化する。
- その上で、次の major で削る候補を明示する。

### Low 2: 旧 MTL ヘルパーの扱いを最終整理候補にする

**対象**:
- `packages/temporal_logic_mtl/lib/src/mtl_legacy_helpers.dart`
- `packages/temporal_logic_mtl/lib/temporal_logic_mtl.dart`

**評価軸**

| 指標 | 値 | 根拠 |
|------|---:|------|
| Complexity | 2/5 | 各ファイル単体は小さめ |
| Coupling | 3/5 | legacy helper と export の関係がまだ残っている |
| Bug Risk | 2/5 | 現時点で不具合は見えないが、拡張時に差分が生じやすい |
| Coverage Confidence | 4/5 | widget test がある |
| Blast Radius | 4/5 | `temporal_logic_flutter.dart` から export 済み |
| Effort | 2/5 | checker 側の整理に合わせて段階的に直せる |

**優先度**: Medium

**観測根拠**

- [ltl_checker_widget.dart](/Users/rizumita/Workspace/caphtech.public/temporal_logic/packages/temporal_logic_flutter/lib/src/ltl_checker_widget.dart) と [mtl_checker_widget.dart](/Users/rizumita/Workspace/caphtech.public/temporal_logic/packages/temporal_logic_flutter/lib/src/mtl_checker_widget.dart) は、`initState`、初期結果計算、`didUpdateWidget`、`dispose`、`StreamBuilder` をそれぞれ別実装で持っています。
- 現在の export 面では `StreamLtlChecker`、`StreamMtlChecker`、`LtlCheckerWidget`、`MtlCheckerWidget` を別々に公開しています。
- builder の引数は LTL 側が `bool`、MTL 側が `bool + EvaluationResult` で異なり、将来の統合方針を先に決めないと UI API が分岐したまま増えます。

**互換性を維持する案**

- 現行の 2 種類の widget を残す。
- 内部だけを共通化し、builder 署名の違いはラッパで吸収する。
- `temporal_logic_flutter.dart` の export は変えない。

**整理を優先する案**

- `EvaluationResult` を UI 側の共通結果型に寄せ、LTL widget も詳細結果を扱える設計にそろえる。
- `FormulaCheckerWidget` のような共通 widget を内部に持ち、公開 API は段階的に統一する。

**最初に着手するなら何を分割するか**

- checker 生成と `didUpdateWidget` の再初期化処理を共通化する。

### Low 1: 非推奨の旧 MTL ヘルパーは公開面から外れており、分離または削除候補として扱いやすい

**対象**:
- `packages/temporal_logic_mtl/lib/src/mtl_operators.dart`
- `packages/temporal_logic_mtl/lib/temporal_logic_mtl.dart`

**評価軸**

| 指標 | 値 | 根拠 |
|------|---:|------|
| Complexity | 2/5 | 単体は小さい |
| Coupling | 2/5 | 現在の公開 export には含まれていない |
| Bug Risk | 2/5 | 参照箇所がほぼない |
| Coverage Confidence | 1/5 | repo 内利用はゼロ |
| Blast Radius | 1/5 | main library export から外れている |
| Effort | 1/5 | 分離だけなら低コスト |

**優先度**: Low

**観測根拠**

- `checkEventuallyWithin`、`checkAlwaysWithin`、`checkUntilWithin` は [mtl_operators.dart](/Users/rizumita/Workspace/caphtech.public/temporal_logic/packages/temporal_logic_mtl/lib/src/mtl_operators.dart#L507) に残っています。
- ただし [temporal_logic_mtl.dart](/Users/rizumita/Workspace/caphtech.public/temporal_logic/packages/temporal_logic_mtl/lib/temporal_logic_mtl.dart#L50) では export がコメントアウトされており、repo 内参照も定義箇所しか見つかりませんでした。

**優先度**: Low

**扱い**

- すでに非公開の互換資産として隔離されているため、次の major での削除候補として扱います。
- 直近での優先順位は低く、公開 API 整理の判断が固まったあとでよいです。

## Metrics Summary

### 主要ファイルの規模と変更履歴

| ファイル | LOC | コミット数 | 備考 |
|------|---:|---:|------|
| `packages/temporal_logic_mtl/lib/src/mtl_evaluator.dart` | 160 | 1 | LTL 共通化済みだが timed 拡張の中心 |
| `packages/temporal_logic_flutter/lib/src/mtl_checker_widget.dart` | 156 | 3 | widget 側の重複候補 |
| `packages/temporal_logic_mtl/lib/src/mtl_ast.dart` | 144 | 1 | MTL AST の主な定義 |
| `packages/temporal_logic_core/lib/src/evaluator.dart` | 137 | 4 | core LTL の入口 |
| `packages/temporal_logic_flutter/lib/src/ltl_checker_widget.dart` | 135 | 3 | widget 側の重複候補 |
| `packages/temporal_logic_flutter/lib/src/formula_stream_checker_base.dart` | 109 | 2 | stream checker の共通基盤 |
| `packages/temporal_logic_mtl/lib/src/mtl_legacy_helpers.dart` | 98 | 1 | 旧 API の隔離先 |
| `packages/temporal_logic_flutter/lib/src/stream_ltl_checker.dart` | 90 | 4 | checker 側の重複候補 |
| `packages/temporal_logic_core/lib/src/evaluation_result.dart` | 73 | 1 | result 型の分離先 |
| `packages/temporal_logic_flutter/lib/src/stream_mtl_checker.dart` | 71 | 5 | checker 側の重複候補 |

### 主要候補の分岐密度

| ファイル | `if` | `for` | `try` | コメント |
|------|---:|---:|---:|------|
| `mtl_operators.dart` | 63 | 40 | 1 | 評価分岐と旧 API を同居 |
| `evaluator.dart` | 29 | 24 | 0 | LTL 評価の本体 |
| `stream_ltl_checker.dart` | 13 | 1 | 2 | 例外処理含む購読ライフサイクル |
| `stream_mtl_checker.dart` | 7 | 2 | 2 | 例外処理含む購読ライフサイクル |

### 参照の広さ

| シンボル | 参照範囲 |
|------|------|
| `evaluateMtlTrace` | README、英日ドキュメント、`mtl` の tests、Flutter widget、Flutter checker、example test |
| `StreamLtlChecker` | README、widget、専用 test、parity test |
| `StreamMtlChecker` | README、widget、専用 test、parity test |

## Top Files Requiring Attention

| Rank | ファイル | 優先度 | 主な理由 |
|------|------|------|------|
| 1 | `packages/temporal_logic_flutter/lib/src/stream_ltl_checker.dart` | Medium | trace 共通化の主対象 |
| 2 | `packages/temporal_logic_flutter/lib/src/stream_mtl_checker.dart` | Medium | trace 共通化の主対象 |
| 3 | `packages/temporal_logic_flutter/lib/src/mtl_checker_widget.dart` | Medium | parity を維持しながら UI を整理したい |
| 4 | `packages/temporal_logic_flutter/lib/src/ltl_checker_widget.dart` | Medium | parity を維持しながら UI を整理したい |
| 5 | `packages/temporal_logic_flutter/lib/temporal_logic_flutter.dart` | Low | export 面の整理判断が集中する |
| 6 | `packages/temporal_logic_mtl/lib/src/mtl_evaluator.dart` | Low | timed 拡張の中心、今後の仕様追加点 |
| 7 | `packages/temporal_logic_flutter/lib/src/formula_stream_checker_base.dart` | Low | 共通基盤だが、さらに整理余地あり |
| 8 | `packages/temporal_logic_core/lib/src/evaluator.dart` | Low | 共通化済み、残る調整点の確認対象 |
| 9 | `packages/temporal_logic_core/lib/src/evaluation_result.dart` | Low | result 型の分離先、export 契約の確認対象 |
| 10 | `packages/temporal_logic_mtl/lib/src/mtl_legacy_helpers.dart` | Low | 旧 API の最終整理候補 |

## Recommended Refactoring Sequence

1. `StreamLtlChecker` と `StreamMtlChecker` の trace 構築を共通化する
2. parity test を `reason` と位置情報まで含めて強化する
3. widget 層の初期結果計算と再初期化パターンをさらに揃える
4. export 面を見直し、将来の統一 API をどう見せるかを決める
5. 旧 MTL ヘルパーの削除時期を major 単位で決める

## すぐに実装へ移るなら

### 最初の実装単位

- Step 1: `stream_ltl_checker.dart` と `stream_mtl_checker.dart` の trace 構築を共通 helper に寄せる
- Step 2: `checker_parity_test.dart` と `evaluation_result_parity_test.dart` を metadata まで含めて拡張する

### 先に守るべき振る舞い固定

- `packages/temporal_logic_mtl/test/evaluation_result_parity_test.dart`
- `packages/temporal_logic_mtl/test/semantics_matrix_test.dart`
- `packages/temporal_logic_mtl/test/pbt_properties_test.dart`
- `packages/temporal_logic_flutter/test/checker_parity_test.dart`
- `packages/temporal_logic_flutter/test/stream_ltl_checker_test.dart`
- `packages/temporal_logic_flutter/test/stream_mtl_checker_test.dart`
- `packages/temporal_logic_flutter/test/ltl_checker_widget_test.dart`
- `packages/temporal_logic_flutter/test/mtl_checker_widget_test.dart`

## Assumptions

- 今回の成果物はコード修正ではなく分析レポートです。
- TypeScript 向け基準は、そのままの数値ではなく、Dart 向けに LOC、責務分離、公開面、重複実装の観点へ読み替えて使いました。
- 優先度は「壊れているか」よりも、「次の変更で二重修正や API 分岐が増えるか」を重視して付けました。
