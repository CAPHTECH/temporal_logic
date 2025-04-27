# Flutter & Dart 用 Temporal Logic パッケージ - 詳細ドキュメント

`temporal_logic_core`, `temporal_logic_mtl`, `temporal_logic_flutter` パッケージの詳細ドキュメントへようこそ。このガイドは、Dart および Flutter アプリケーションの振る舞いを指定し検証するために時間論理を使用するための概念、API、ベストプラクティスについての包括的な理解を提供することを目的としています。

**目次:**

- [Flutter \& Dart 用 Temporal Logic パッケージ - 詳細ドキュメント](#flutter--dart-用-temporal-logic-パッケージ---詳細ドキュメント)
  - [1. はじめに](#1-はじめに)
    - [なぜ時間論理なのか?](#なぜ時間論理なのか)
    - [パッケージ概要](#パッケージ概要)
  - [2. はじめに (Getting Started)](#2-はじめに-getting-started)
    - [インストール](#インストール)
    - [最初の LTL テスト (ログインフローの例)](#最初の-ltl-テスト-ログインフローの例)
  - [3. 中心となる概念](#3-中心となる概念)
    - [トレースとタイムスタンプ](#トレースとタイムスタンプ)
    - [状態スナップショット (`AppSnap`)](#状態スナップショット-appsnap)
    - [プロポジション: `state` vs `event`](#プロポジション-state-vs-event)
    - [線形時相論理 (LTL) の基礎](#線形時相論理-ltl-の基礎)
    - [計量時相論理 (MTL) の基礎](#計量時相論理-mtl-の基礎)
  - [4. API リファレンス](#4-api-リファレンス)
    - [`temporal_logic_core` API](#temporal_logic_core-api)
      - [Formula](#formula)
      - [AtomicProposition](#atomicproposition)
      - [論理演算子 (`and`, `or`, `not`, `implies`)](#論理演算子-and-or-not-implies)
      - [LTL 演算子 (`next`, `always`, `eventually`, `until`, `release`)](#ltl-演算子-next-always-eventually-until-release)
      - [ヘルパー関数 (`state`, `event`)](#ヘルパー関数-state-event)
    - [`temporal_logic_mtl` API](#temporal_logic_mtl-api)
      - [TimeInterval](#timeinterval)
      - [時間付き演算子 (`alwaysTimed`, `eventuallyTimed`)](#時間付き演算子-alwaystimed-eventuallytimed)
      - [評価 (`evaluateMtlTrace`)](#評価-evaluatemtltrace)
    - [`temporal_logic_flutter` API](#temporal_logic_flutter-api)
      - [TraceRecorder](#tracerecorder)
      - [マッチャー (`satisfiesLtl`, `satisfiesMtl`)](#マッチャー-satisfiesltl-satisfiesmtl)
  - [5. クックブック \& ベストプラクティス](#5-クックブック--ベストプラクティス)
    - [状態管理との統合 (Riverpod の例)](#状態管理との統合-riverpod-の例)
    - [効果的な `AppSnap` 型の設計](#効果的な-appsnap-型の設計)
    - [一般的な LTL/MTL パターン](#一般的な-ltlmtl-パターン)
    - [非同期操作のテスト](#非同期操作のテスト)
    - [一時的なイベントの扱い (`loginClicked`)](#一時的なイベントの扱い-loginclicked)
    - [パフォーマンスに関する考慮事項](#パフォーマンスに関する考慮事項)
  - [6. その他の例](#6-その他の例)
    - [フォームバリデーションフロー](#フォームバリデーションフロー)
    - [アニメーションシーケンス検証](#アニメーションシーケンス検証)
    - [ネットワークリクエストライフサイクル](#ネットワークリクエストライフサイクル)
  - [7. トラブルシューティング](#7-トラブルシューティング)

---

## 1. はじめに

### なぜ時間論理なのか?

現代のアプリケーション、特に UI が豊富な Flutter アプリは、イベント、状態変化、タイミングの複雑なシーケンスを伴います。不正な順序、タイミングの問題、予期しない状態インタラクションから生じるバグは、静的な状態や最終結果に焦点を当てた従来のテスト手法では捉えにくいことがあります。

時間論理 (LTL および MTL) は、*時間を通じた*プロパティを正確に記述し検証するための形式言語を提供します。

- **LTL (線形時相論理):** イベントと状態の*順序*に関するプロパティを指定します (例: 「イベント A の後には*最終的に*状態 B が続かなければならない」)。
- **MTL (計量時相論理):** LTL を拡張し、*定量的な時間制約*を追加します (例: 「イベント A の後には*5秒以内*に状態 B が続かなければならない」)。

これらのパッケージを使用すると、次のことが可能になります:

- **振る舞いを明確に指定:** 意図した時間的振る舞いを曖昧さなく定義します。
- **テスト容易性の向上:** 複雑な時間的シナリオや競合状態を対象としたテストを設計します。
- **微妙なバグの検出:** 一時的な不正状態 (ちらつき) や要求されたシーケンスの違反などの問題を検出します。

### パッケージ概要

- **`packages/temporal_logic_core`**: 基本的なインターフェース、LTL 式の構築、基本的なトレース構造を提供します。
- **`packages/temporal_logic_mtl`**: MTL の実装、時間付き演算子、時間付きトレースの評価を追加します。
- **`packages/temporal_logic_flutter`**: Flutter 固有の統合、状態シーケンスをキャプチャするための `TraceRecorder`、および `flutter_test` マッチャー (`satisfiesLtl`, `satisfiesMtl`) を含みます。

## 2. はじめに (Getting Started)

### インストール

`pubspec.yaml` に依存関係を追加します。このモノレポ内での開発では、`path` 依存関係を使用します:

```yaml
# パッケージを使用するアプリ/例のための例
dependencies:
  flutter:
    sdk: flutter
  # 必要なパッケージを追加:
  temporal_logic_flutter:
    path: ../packages/temporal_logic_flutter # 必要に応じてパスを調整

# 必要に応じて、推移的な依存関係もパスを使用するようにします:
dependency_overrides:
  temporal_logic_core:
    path: ../packages/temporal_logic_core # 必要に応じてパスを調整
  temporal_logic_mtl:
    path: ../packages/temporal_logic_mtl # 必要に応じてパスを調整

dev_dependencies:
  flutter_test:
    sdk: flutter
```

`flutter pub get` を実行します。

### 最初の LTL テスト (ログインフローの例)

`examples/login_flow_ltl` は実用的な出発点を提供します。以下はそのテスト (`test/widget_test.dart`、外部記録を使用) の本質です:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login_flow_ltl_example/main.dart'; // あなたのアプリ
import 'package:temporal_logic_core/temporal_logic_core.dart' as tlCore;
import 'package:temporal_logic_flutter/temporal_logic_flutter.dart' as tlFlutter;

void main() {
  testWidgets('Successful login flow satisfies LTL formula', (tester) async {
    // 1. レコーダーとコンテナのセットアップ (アプリコードの変更なし)
    final recorder = tlFlutter.TraceRecorder<AppSnap>();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    recorder.initialize();

    // 2. 初期状態の記録 & 変更のリスニング
    final initialState = container.read(appStateProvider); // Riverpod を想定
    recorder.record(AppSnap.fromAppState(initialState));
    container.listen<AppState>(appStateProvider, (prev, next) {
      recorder.record(AppSnap.fromAppState(next));
    });

    // 3. ウィジェットの Pump
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.pumpAndSettle();

    // 4. インタラクションのシミュレーション
    await tester.enterText(find.byKey(const Key('email')), 'valid@email.com');
    await tester.tap(find.byKey(const Key('login')));
    await tester.pumpAndSettle(); // 状態変化が記録されるのを待つ

    // 5. プロポジション & 式の定義
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

    // 6. トレースの検証
    final trace = recorder.trace;
    expect(trace, tlFlutter.satisfiesLtl(formula));
  });
}
```

*(このセクションは概要を提供します。後続のセクションで概念と API の詳細を説明します)*

## 3. 中心となる概念

### トレースとタイムスタンプ

- **Trace** (`Trace<T>`) は、時間を通じたアプリケーション状態 (`T`) のシーケンスを表します。
- トレース内の各要素は **TraceEvent<T>** であり、状態 (`value`) とそのタイムスタンプ (`timestamp`) を含みます。
- タイムスタンプは通常、記録開始からの時間または固定エポックを表す `Duration` オブジェクトです。
- `TraceRecorder` は `record()` が呼び出されると自動的にタイムスタンプを割り当てます。

### 状態スナップショット (`AppSnap`)

- `Trace<T>` のジェネリック型 `T` は、検証したいプロパティに関連するアプリケーション状態のスナップショットを表します。
- これは多くの場合、不変なカスタムクラス (例の `AppSnap` など) であり、実際のアプリケーション状態 (例: Riverpod の `AppState`) から派生したブール値フラグや enum 値を含みます。
- **設計原則:** 時間論理式に必要な状態側面のみを含めます。最小限でありながら十分なものにします。不変にし、`==` と `hashCode` を実装します。

### プロポジション: `state` vs `event`

時間論理式は、状態スナップショットに関する基本的な真偽文である **Atomic Propositions (原子命題)** に基づいて構築されます。

- **`tlCore.state<T>(Predicate<T> predicate, {String? name})`**:
  - アプリケーションが特定の状態にある*間*保持される条件を表します。
  - `predicate` 関数は、与えられた状態スナップショット `T` に対して条件が保持される場合に `true` を評価します。
  - 例: `final loading = tlCore.state<AppSnap>((s) => s.isLoading);` (スナップショットで `isLoading` が true のときは常に True)。
- **`tlCore.event<T>(Predicate<T> predicate, {String? name})`**:
  - 特定の時点*で発生する何かを表し、多くの場合、状態の*開始*やアクションの発生を示します。
  - 技術的には*現在の*状態に対して `predicate` を評価しますが、LTL 式におけるその解釈はしばしば遷移や発生に関連します。
  - (例の `loginClicked` のように) 一時的なフラグやシグナルをキャプチャするために使用されます。これはボタンタップ直後の単一のスナップショットでのみ true でした。
  - **主な違い:** `state` は通常、期間を表し、`event` は瞬間的な発生または状態の開始を表します。この選択は、`next` や `always` のような演算子が式をどのように解釈するかに影響します。

### 線形時相論理 (LTL) の基礎

LTL は、状態の線形シーケンス (トレース) に沿ったプロパティについて推論します。`temporal_logic_core` によって提供される主要な演算子 (`Formula` の拡張メソッドとして使用):

- **`next(formula)` (X)**: `formula` はトレースの*次の*状態で保持されなければなりません。
- **`always(formula)` (G)**: `formula` は*現在の*状態および*すべての将来の*状態で保持されなければなりません。
- **`eventually(formula)` (F)**: `formula` は*現在の*状態または*いくつかの将来の*状態で保持されなければなりません。
- **`until(formula1, formula2)` (U)**: `formula1` は `formula2` が保持される*まで少なくとも*保持されなければなりません。`formula2` は現在または将来の状態で保持されなければなりません。
- **`release(formula1, formula2)` (R)**: `formula2` は `formula1` が最初に保持される時点*まで、そしてそれを含めて*保持されなければなりません。`formula1` が決して保持されない場合、`formula2` は永遠に保持されなければなりません。(Until の双対)。
- 標準的な論理演算子 (`and`, `or`, `not`, `implies`) がこれらを組み合わせます。

### 計量時相論理 (MTL) の基礎

MTL は、時間演算子に時間制約を追加することで LTL を拡張します。`temporal_logic_mtl` によって提供されます。

- **`TimeInterval(Duration start, Duration end, {bool startInclusive, bool endInclusive})`**: 時間ウィンドウを定義します。
- **`alwaysTimed(formula, TimeInterval interval)` (G[a,b])**: `formula` は、現在時刻に対して指定された `interval` 内のすべての将来の状態で保持されなければなりません。
- **`eventuallyTimed(formula, TimeInterval interval)` (F[a,b])**: `formula` は、現在時刻に対して指定された `interval` 内のいくつかの将来の状態で保持されなければなりません。
- 評価には、意味のあるタイムスタンプを持つ `Trace` と `evaluateMtlTrace` 関数が必要です。

## 4. API リファレンス

*(このセクションには、Dartdoc に似た、各クラスと関数の詳細な説明が含まれますが、より物語的になる可能性があります)*

### `temporal_logic_core` API

#### Formula<T>

*(すべての式の抽象基底クラス)*

#### AtomicProposition<T>

*(状態 T に関する基本的な真偽文を表す)*

- `bool predicate(T state)`
- `String name`

#### 論理演算子 (`and`, `or`, `not`, `implies`)

- `formula1.and(formula2)`

- `formula1.or(formula2)`
- `formula.not()`
- `formula1.implies(formula2)`

#### LTL 演算子 (`next`, `always`, `eventually`, `until`, `release`)

- `formula.next()` または `tlCore.next(formula)`

- `formula.always()` または `tlCore.always(formula)`
- `formula.eventually()` または `tlCore.eventually(formula)`
- `formula1.until(formula2)` または `tlCore.until(formula1, formula2)`
- `formula1.release(formula2)` または `tlCore.release(formula1, formula2)`

#### ヘルパー関数 (`state`, `event`)

- `tlCore.state<T>(...)`

- `tlCore.event<T>(...)`

### `temporal_logic_mtl` API

#### TimeInterval

- `Duration start`

- `Duration end`
- `bool startInclusive`
- `bool endInclusive`

#### 時間付き演算子 (`alwaysTimed`, `eventuallyTimed`)

- `formula.alwaysTimed(interval)` または `tlMtl.alwaysTimed(formula, interval)`

- `formula.eventuallyTimed(interval)` または `tlMtl.eventuallyTimed(formula, interval)`

#### 評価 (`evaluateMtlTrace`)

- `EvaluationResult evaluateMtlTrace<T>(Trace<T> trace, Formula<T> formula, {int startIndex = 0})`

- `EvaluationResult` のプロパティ: `bool holds`, `String? reason`

### `temporal_logic_flutter` API

#### TraceRecorder<T>

- `TraceRecorder({Duration interval = const Duration(milliseconds: 100), TimeProvider timeProvider = const WallClockTimeProvider()})` (注意: 現在の例では手動記録のために `interval: Duration.zero` を使用)

- `void initialize()`
- `void record(T state)`
- `Trace<T> get trace`
- `void dispose()`

#### マッチャー (`satisfiesLtl`, `satisfiesMtl`)

- `Matcher satisfiesLtl<T>(Formula<T> formula)`

- `Matcher satisfiesMtl<T>(Formula<T> formula)` (これが存在するか、`satisfiesLtl` が両方を処理すると仮定)
  - `expect(trace, satisfiesLtl(formula))` で使用
  - `expect(trace, isNot(satisfiesLtl(formula)))` で使用

## 5. クックブック & ベストプラクティス

*(このセクションでは、実践的なアドバイスとコードスニペットを提供します)*

### 状態管理との統合 (Riverpod の例)

*(`container.listen` を使用した外部記録セットアップを示す)*

### 効果的な `AppSnap` 型の設計

*(不変性、関連する状態、`==`/`hashCode`)*

### 一般的な LTL/MTL パターン

- **応答:** `G(request -> F(response))`

- **安全性 (不変条件):** `G(!errorState)`
- **活性 (Liveness):** `G(action -> F(completion))`
- **時間付き応答:** `G(request -> F[0, 5s](response))`
- **ちらつきなし:** `G(loading -> G(!error))`

### 非同期操作のテスト

*(`pumpAndSettle` の使用、リスナーがすべての中間状態をキャプチャすることの確認)*

### 一時的なイベントの扱い (`loginClicked`)

*(単一のスナップショットでのみ true になる `AppSnap` 内のブール値フラグの使用)*

### パフォーマンスに関する考慮事項

*(`AppSnap` サイズの最小化、記録頻度 vs 詳細度、テストへの影響)*

## 6. その他の例

*(簡単な説明と、将来の可能性のある例ディレクトリへのリンク)*

### フォームバリデーションフロー

*(例: 送信ボタンは `G(formValid -> submitEnabled)` の場合にのみ有効)*

### アニメーションシーケンス検証

*(例: `G(animationStart -> F(phase1) && F(phase2) && F(animationEnd))`、タイミング付き)*

### ネットワークリクエストライフサイクル

*(例: `G(requestSent -> F(responseReceived || requestFailed))`)*

## 7. トラブルシューティング

- **式が期待通りに評価されない:** プロポジション定義 (`state` vs `event`)、演算子の意味論、トレース内容を確認します。
- **テストが予期せず失敗する:** `AppSnap` が正しい状態をキャプチャしているか、リスナーが関連するすべての遷移を記録しているか、`pumpAndSettle` が正しく使用されているかを確認します。
- **依存関係の問題:** ローカルで作業している場合は、`path` 依存関係が一貫して使用されていることを確認します。

---

このドキュメントは包括的なガイドを提供します。特定の API の詳細については、常にソースコードと Dartdoc コメントを参照してください。
