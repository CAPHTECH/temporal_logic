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

- 現在のコードベースは、テストの厚さと振る舞い固定の観点ではかなり健全です。`core`、`mtl`、`flutter` の各パッケージでテストはすべて通過し、分析時点の静的解析結果は warning 2 件だけでした。
- 一方で、保守性の観点では 2 つの構造的な負債が見つかりました。最も大きいのは `temporal_logic_mtl` 側で、`mtl_operators.dart` が AST、LTL/MTL の評価器、互換用の旧 API を 1 ファイルに抱えています。次が `temporal_logic_flutter` 側で、LTL/MTL のストリームチェッカーとウィジェットがほぼ同じライフサイクル処理を別実装で持っています。
- 今回の結論は、「今すぐ挙動を直す必要はないが、次に機能追加や API 整理を進める前に、評価器の責務分割とチェッカーの共通化を先に行うと、以後の変更コストが大きく下がる」です。

### Overall Health Score

**80 / 100**

判定理由:
- 正しさのベースラインは強い。3 パッケージのテストが通過している。
- ただし、単一責務と重複削減の観点では局所的に大きな負債がある。
- もっとも大きいファイルがしきい値を超えており、将来の仕様追加時に二重修正が起きやすい。

### Priority Breakdown

- Critical: 1
- Medium: 2
- Low: 2

## Baseline

### 検証結果

| 項目 | 結果 |
|------|------|
| `flutter analyze` | warning 2 件 |
| `temporal_logic_core` tests | 全件通過 |
| `temporal_logic_mtl` tests | 全件通過 |
| `temporal_logic_flutter` tests | 全件通過 |

### 静的解析で確認した warning

| ファイル | 行 | 内容 |
|------|---:|------|
| `packages/temporal_logic_flutter/lib/src/stream_ltl_checker.dart` | 85 | 不要な non-null assertion |
| `packages/temporal_logic_flutter/lib/src/stream_mtl_checker.dart` | 64 | 不要な non-null assertion |

### しきい値に対する要点

今回の基準は refactoring スキルの `design-standards.md` を参考にしています。ただし、その基準は TypeScript 向けの記述が多いため、Dart では次の項目を主に使いました。

- ファイル長しきい値: 400 行
- 単一責務の目安: 1 つの主要責務と補助責務 1 つまで
- import 数や循環依存より、公開面と重複実装を重視

## Findings by Priority

### Critical 1: MTL 評価器が巨大ファイル化し、LTL 評価器との重複修正を招きやすい

**対象**:
- `packages/temporal_logic_mtl/lib/src/mtl_operators.dart`
- `packages/temporal_logic_core/lib/src/evaluator.dart`

**評価軸**

| 指標 | 値 | 根拠 |
|------|---:|------|
| Complexity | 5/5 | `mtl_operators.dart` が 635 行で、しきい値 400 を超過 |
| Coupling | 4/5 | `core` の LTL 評価ロジックを `mtl` 側で再実装している |
| Bug Risk | 4/5 | 評価ロジックの分岐が多く、直近の変更も入っている |
| Coverage Confidence | 5/5 | parity test、property-based test、matrix test が厚い |
| Blast Radius | 5/5 | `evaluateMtlTrace` は export 済みで、README、ドキュメント、Flutter 側、テストから参照されている |
| Effort | 4/5 | 分割自体は中規模だが、評価契約を崩さない整理が必要 |

**優先度**: Critical

**観測根拠**

- `packages/temporal_logic_mtl/lib/src/mtl_operators.dart` は 635 行で、ワークスペース最大の production ファイル。
- 同ファイルには次の 3 つの責務が混在しています。
  - MTL AST 定義
  - LTL と MTL をまとめた評価器
  - 非推奨の旧スタンドアロン関数
- `_evaluateRecursive` は [evaluator.dart](/Users/rizumita/Workspace/caphtech.public/temporal_logic/packages/temporal_logic_core/lib/src/evaluator.dart#L138) の `_evaluateFormula` と、`AtomicProposition` から `Release` までの LTL 分岐をほぼ別実装で持っています。
- `evaluateMtlTrace` は README、英日ドキュメント、Flutter 側のウィジェットとストリームチェッカー、`mtl` パッケージの各種テストから広く参照されています。

**詳細**

- [mtl_operators.dart](/Users/rizumita/Workspace/caphtech.public/temporal_logic/packages/temporal_logic_mtl/lib/src/mtl_operators.dart#L202) には、LTL の `switch` 分岐と MTL の `switch` 分岐が連続して並んでいます。
- [evaluator.dart](/Users/rizumita/Workspace/caphtech.public/temporal_logic/packages/temporal_logic_core/lib/src/evaluator.dart#L138) でも同種の `switch` を持っているため、LTL 仕様の修正時に `core` と `mtl` の両方を触る必要があります。
- `And`、`Or`、`Release` などは失敗理由の組み立て方も少し異なっており、将来の説明文や診断情報の改善時に差分が広がる可能性があります。

**互換性を維持する案**

- `evaluateMtlTrace` の公開シグネチャはそのまま残す。
- `mtl_operators.dart` を `mtl_ast.dart`、`mtl_evaluator.dart`、`mtl_legacy_helpers.dart` のように分割する。
- LTL の共通評価部分は `core` 側の内部ヘルパーへ寄せるか、少なくとも `mtl` 側では薄いアダプタにする。
- 旧ヘルパーは非推奨のまま隔離し、公開 export しない現状を維持する。

**整理を優先する案**

- `evaluateMtlTrace` を「LTL 評価器 + MTL 拡張ディスパッチ」という形に再設計する。
- `core` 側の評価ロジックを単一の再利用可能コンポーネントにし、`mtl` は時間制約分だけを担当する。
- 非推奨ヘルパーは次の major で削除候補にする。

**最初に着手するなら何を分割するか**

- `mtl_operators.dart` から非推奨ヘルパー 3 関数を先に分離する。
- 次に `_evaluateRecursive` の LTL 部分だけを独立させ、`core` の評価器との差分を見える形にする。

### Medium 1: LTL と MTL のストリームチェッカーがライフサイクル実装を重複保持している

**対象**:
- `packages/temporal_logic_flutter/lib/src/stream_ltl_checker.dart`
- `packages/temporal_logic_flutter/lib/src/stream_mtl_checker.dart`

**評価軸**

| 指標 | 値 | 根拠 |
|------|---:|------|
| Complexity | 3/5 | 173 行と 136 行で、単体としては中程度 |
| Coupling | 4/5 | 初期評価、購読開始、エラー処理、破棄が重複 |
| Bug Risk | 3/5 | 両方とも直近コミットが同一で、同じ種類の修正が波及している |
| Coverage Confidence | 5/5 | 個別テストと parity test がある |
| Blast Radius | 4/5 | どちらも public export され、対応する widget から利用される |
| Effort | 2/5 | 内部共通化だけなら比較的着手しやすい |

**優先度**: Medium

**観測根拠**

- 2 ファイルの差分を確認すると、コンストラクタ内の初期評価、`_startListening()`、`_publishErrorAndClose()`、`_evaluateAndNotify()`、`dispose()` が同型です。
- 両ファイルとも 2026-04-02 の同一コミット `a1e003d` で更新されており、実際に同じ問題を平行修正している履歴が見えます。
- analyzer warning も 2 ファイルに対称に出ており、重複の存在を補強しています。

**詳細**

- [stream_ltl_checker.dart](/Users/rizumita/Workspace/caphtech.public/temporal_logic/packages/temporal_logic_flutter/lib/src/stream_ltl_checker.dart#L56) と [stream_mtl_checker.dart](/Users/rizumita/Workspace/caphtech.public/temporal_logic/packages/temporal_logic_flutter/lib/src/stream_mtl_checker.dart#L34) は、入力型と結果型が違うだけで、制御フローはほぼ同じです。
- この形のまま機能を増やすと、次のような修正が二重になります。
  - エラー伝播の統一
  - 初期結果の発行タイミングの変更
  - 完了時の close 条件の変更
  - メモリ削減や trace 保持戦略の変更

**互換性を維持する案**

- `StreamLtlChecker` と `StreamMtlChecker` の public API は残す。
- 内部に共通の購読ライフサイクルヘルパーを導入し、型変換と評価関数だけを差し替える。
- 結果型の違いは維持し、LTL だけ `bool`、MTL は `EvaluationResult` のままにする。

**整理を優先する案**

- 内部表現を `EvaluationResult` に統一し、LTL 側は `holds` だけを公開する薄いラッパにする。
- さらに進めるなら、1 つのジェネリックな `StreamFormulaChecker` に集約し、LTL/MTL は factory や typedef で提供する。

**最初に着手するなら何を分割するか**

- `scheduleMicrotask` での初期結果発行と `_publishErrorAndClose()` を共通化する。

### Medium 2: ウィジェット層でも LTL/MTL の分割が重複として現れており、将来の API 統合判断を難しくしている

**対象**:
- `packages/temporal_logic_flutter/lib/src/ltl_checker_widget.dart`
- `packages/temporal_logic_flutter/lib/src/mtl_checker_widget.dart`
- `packages/temporal_logic_flutter/lib/temporal_logic_flutter.dart`

**評価軸**

| 指標 | 値 | 根拠 |
|------|---:|------|
| Complexity | 2/5 | 各ファイル単体は小さめ |
| Coupling | 3/5 | 対応する checker の二重構造をそのまま受け継いでいる |
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

**扱い**

- 互換性を重視するなら、別ファイルへ隔離して「内部互換資産」と明示する。
- 整理を優先するなら、次の major で削除候補にできます。

### Low 2: チェッカー 2 本に同じ analyzer warning が出ており、小さなノイズが残っている

**対象**:
- `packages/temporal_logic_flutter/lib/src/stream_ltl_checker.dart`
- `packages/temporal_logic_flutter/lib/src/stream_mtl_checker.dart`

**評価軸**

| 指標 | 値 | 根拠 |
|------|---:|------|
| Complexity | 1/5 | 小修正で消せる |
| Coupling | 1/5 | 局所修正 |
| Bug Risk | 1/5 | 直接の振る舞い影響は小さい |
| Coverage Confidence | 5/5 | テストあり |
| Blast Radius | 2/5 | 公開型ではないが、対象ファイルは public class |
| Effort | 1/5 | 即時対応可能 |

**優先度**: Low

**扱い**

- 単独で取り組む価値は低いです。
- ただし Medium 1 に着手する時に一緒に解消すると、重複整理の完了条件が分かりやすくなります。

## Metrics Summary

### 主要ファイルの規模と変更履歴

| ファイル | LOC | コミット数 | 備考 |
|------|---:|---:|------|
| `packages/temporal_logic_mtl/lib/src/mtl_operators.dart` | 635 | 5 | ワークスペース最大。しきい値超過 |
| `packages/temporal_logic_core/lib/src/evaluator.dart` | 335 | 3 | `mtl` 側と意味上の重複あり |
| `packages/temporal_logic_core/lib/src/ast.dart` | 325 | 3 | 大きいが責務は比較的まとまっている |
| `packages/temporal_logic_flutter/lib/src/mtl_checker_widget.dart` | 174 | 3 | widget 側の重複候補 |
| `packages/temporal_logic_flutter/lib/src/stream_ltl_checker.dart` | 173 | 4 | checker 側の重複候補 |
| `packages/temporal_logic_flutter/lib/src/ltl_checker_widget.dart` | 150 | 3 | widget 側の重複候補 |
| `packages/temporal_logic_flutter/lib/src/stream_mtl_checker.dart` | 136 | 5 | checker 側の重複候補 |

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
| `StreamLtlChecker` | README、CHANGELOG、widget、専用 test、parity test |
| `StreamMtlChecker` | README、CHANGELOG、widget、専用 test、parity test |

## Top Files Requiring Attention

| Rank | ファイル | 優先度 | 主な理由 |
|------|------|------|------|
| 1 | `packages/temporal_logic_mtl/lib/src/mtl_operators.dart` | Critical | 巨大化、責務混在、`core` との重複 |
| 2 | `packages/temporal_logic_core/lib/src/evaluator.dart` | Critical に連動 | LTL 評価の重複元 |
| 3 | `packages/temporal_logic_flutter/lib/src/stream_ltl_checker.dart` | Medium | MTL 側とライフサイクル重複 |
| 4 | `packages/temporal_logic_flutter/lib/src/stream_mtl_checker.dart` | Medium | LTL 側とライフサイクル重複 |
| 5 | `packages/temporal_logic_flutter/lib/src/mtl_checker_widget.dart` | Medium | widget 層でも分岐が継続 |
| 6 | `packages/temporal_logic_flutter/lib/src/ltl_checker_widget.dart` | Medium | widget 層でも分岐が継続 |
| 7 | `packages/temporal_logic_mtl/lib/src/time_interval.dart` | Low | 直接問題はないが evaluator 分割時の接続点 |
| 8 | `packages/temporal_logic_core/lib/src/ast.dart` | Low | 大きいが比較的凝集している |
| 9 | `packages/temporal_logic_flutter/lib/src/stream_sustained_state_checker.dart` | Low | checker 共通化時に設計比較対象になる |
| 10 | `packages/temporal_logic_flutter/lib/temporal_logic_flutter.dart` | Low | export 面の整理判断が集中する |

## Recommended Refactoring Sequence

1. `mtl_operators.dart` を AST、評価器、旧ヘルパーに分ける
2. LTL 共通評価の責務を `core` と `mtl` で再整理する
3. `StreamLtlChecker` と `StreamMtlChecker` の内部ライフサイクルを共通化する
4. widget 層の初期結果計算と再初期化パターンを共通化する
5. export 面を見直し、将来の統一 API をどう見せるかを決める

## すぐに実装へ移るなら

### 最初の実装単位

- Step 1: `mtl_operators.dart` から旧ヘルパー 3 関数を別ファイルへ分離
- Step 2: `stream_ltl_checker.dart` と `stream_mtl_checker.dart` の初期結果発行とエラー終了処理を共通化

### 先に守るべき振る舞い固定

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
