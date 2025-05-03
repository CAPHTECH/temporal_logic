# Flutter/Dartの時相論理パッケージ - 詳細なドキュメント

`temporal_logic_core`、`temporal_logic_mtl`、および`temporal_logic_flutter` パッケージの詳細なドキュメントへようこそ。このガイドでは、Dart と Flutter アプリケーションの動作を指定し検証するために時相論理を使用する際の概念、API、およびベストプラクティスについて、包括的な理解を提供することを目的としています。特に、複雑な状態遷移やタイミング要件を持つアプリケーションに焦点を当てています。

**対象読者：** Flutter/Dart アプリケーションの順序依存または時間依存の動作に対してより堅牢なテストを書きたい開発者。

**目次：**

- [Flutter/Dartの時相論理パッケージ - 詳細なドキュメント](#flutterdartの時相論理パッケージ---詳細なドキュメント)
  - [1. 導入](#1-導入)
    - [なぜ時相論理か？](#なぜ時相論理か)
    - [パッケージ概要](#パッケージ概要)
    - [初めての LTL テスト(ログインフロー例)](#初めての-ltl-テストログインフロー例)
  - [3. 基本概念](#3-基本概念)
    - [トレースとタイムスタンプ](#トレースとタイムスタンプ)
    - [状態のスナップショット(`AppSnap`)](#状態のスナップショットappsnap)
    - [命題： `state` vs `event`](#命題-state-vs-event)
    - [線形時制論理 (LTL) の基礎](#線形時制論理-ltl-の基礎)
    - [メトリック時制論理(MTL)の基本](#メトリック時制論理mtlの基本)
  - [4. API リファレンス](#4-api-リファレンス)
    - [`temporal_logic_core` API](#temporal_logic_core-api)
      - [Formula](#formula)
      - [AtomicProposition](#atomicproposition)
      - [論理演算子(`and`， `or`， `not`， `implies`)](#論理演算子and-or-not-implies)
      - [LTL 演算子 (`next`， `always`， `eventually`， `until`， `release`)](#ltl-演算子-next-always-eventually-until-release)
      - [ヘルパー関数(`state`， `event`)](#ヘルパー関数state-event)
    - [`temporal_logic_mtl` API](#temporal_logic_mtl-api)
      - [TimeInterval](#timeinterval)
      - [タイムド演算子 (`alwaysTimed`， `eventuallyTimed`)](#タイムド演算子-alwaystimed-eventuallytimed)
      - [評価 (`evaluateMtlTrace`)](#評価-evaluatemtltrace)
    - [`temporal_logic_flutter` API](#temporal_logic_flutter-api)
      - [TraceRecorder](#tracerecorder)
      - [マッチャー (`satisfiesLtl`)](#マッチャー-satisfiesltl)
  - [5. クックブック \& ベストプラクティス](#5-クックブック--ベストプラクティス)
    - [状態管理との統合 (Riverpod 例)](#状態管理との統合-riverpod-例)
    - [効果的な `AppSnap` タイプの設計](#効果的な-appsnap-タイプの設計)
    - [一般的な LTL/MTL パターン](#一般的な-ltlmtl-パターン)
    - [非同期操作のテスト](#非同期操作のテスト)
    - [一時的なイベントの処理 (`loginClicked`)](#一時的なイベントの処理-loginclicked)
    - [パフォーマンスに関する考慮事項](#パフォーマンスに関する考慮事項)
  - [6. 追加の例](#6-追加の例)
    - [フォーム検証フロー](#フォーム検証フロー)
    - [アニメーションシーケンス検証](#アニメーションシーケンス検証)
    - [ネットワークリクエストライフサイクル](#ネットワークリクエストライフサイクル)
  - [7. トラブルシューティング](#7-トラブルシューティング)

---

## 1. 導入

### なぜ時相論理か？

現代のアプリケーション、特にUIが豊富なFlutterアプリでは、複雑なイベントのシーケンス、状態の変更、タイミングが関与します。伝統的なテスト手法(静的なスナップショットや最終結果に焦点を当てるもの)では、順序の誤り、タイミングの問題、予期しない状態の相互作用から生じるバグを検出するのが困難です。

時制論理(LTLとMTL)は、*時間経過*に沿った状態のシーケンス全体を記述し検証するための形式的で正確な言語を提供します。

- **LTL(線形時制論理)：** イベントと状態の*順序*に関するプロパティを指定します(例：「ログイン試行は*最終的に*成功したログイン状態またはエラー状態のいずれかに移行しなければならない」)。
- **MTL(メトリック時制論理)： LTLに*定量的時間制約*を追加します(例：「データが取得された後、*3秒以内*に読み込みインジケーターが消える必要がある」)。

これらのパッケージを使用することで、次のようなことが可能です：

- **複雑な動作を明確に指定： 意図した時系列とタイミング制約を曖昧さなく定義できます。
- **テストカバレッジの向上： 複雑な時間シナリオ、レース条件、中間状態をターゲットにしたテストを設計できます。
- **微妙なバグの検出： 一時的な不正状態(UIのちらつき)、必要なシーケンスの違反、または他の方法では見逃される可能性があるタイミング失敗を検出できます。

### パッケージ概要

- **`packages/temporal_logic_core`**： 基礎的なインターフェース、LTL式構築、基本トレース構造。
- **`packages/temporal_logic_mtl`**： MTLの実装、タイムドオペレーターとタイムドトレースの評価を追加。
- **`packages/temporal_logic_flutter`**： Flutter固有の統合、状態シーケンスのキャプチャ用の`TraceRecorder`と`flutter_test`マッチャー(`satisfiesLtl`、`satisfiesMtl`)。

### 初めての LTL テスト(ログインフロー例)

`examples/login_flow_ltl` は実践的な出発点を提供します。以下のテスト(`test/widget_test.dart` で外部記録を使用)は、ログイン試行後の特定の状態変化シーケンスを検証する方法を示しています：

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login_flow_ltl_example/main.dart'; // あなたのアプリ
import 'package:temporal_logic_core/temporal_logic_core.dart';
import 'package:temporal_logic_flutter/temporal_logic_flutter.dart';

// 検証対象のアプリケーション状態のスナップショットを表します。
// 不変で、==/hashCode を実装する必要があります。
class AppSnap {
  final bool isLoading;
  final bool isOnHomeScreen;
  final bool hasError;
  final bool loginClicked; // 一時的なイベントフラグ

  AppSnap({
    required this.isLoading,
    required this.isOnHomeScreen,
    required this.hasError,
    required this.loginClicked,
  });

  // 実際のアプリ状態(例：Riverpod状態)から作成するためのファクトリコンストラクタ
  factory AppSnap.fromAppState(AppState state, {bool loginClicked = false}) {
    return AppSnap(
      isLoading: state.isLoading,
      isOnHomeScreen: state.currentScreen == AppScreen.home,
      hasError: state.errorMessage != null,
      loginClicked: loginClicked, // イベントをキャプチャ
    );
  }
  // == と hashCode の実装...
}

void main() {
  testWidgets('Successful login flow satisfies LTL formula', (tester) async {
    // 1. セットアップ： 状態のスナップショットを時間経過とともにキャプチャするためのレコーダーを作成。
    final recorder = TraceRecorder<AppSnap>();
    final container = ProviderContainer(); // Riverpod による状態管理を仮定
    addTearDown(container.dispose);
    recorder.initialize(); // タイムトラッキングを開始

    // 2. レコーディング： 初期状態をキャプチャし、その後の状態変更を監視。
    final initialState = container.read(appStateProvider);
    recorder.record(AppSnap.fromAppState(initialState)); // 初期スナップショットを記録
    container.listen<AppState>(appStateProvider, (prev, next) {
      // 関連する状態変更をすべて記録
      recorder.record(AppSnap.fromAppState(next));
    });

    // 3. UI の設定
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.pumpAndSettle(); // 初期UIの構築を許可

    // 4. ユーザー操作のシミュレーション
    await tester.enterText(find.byKey(const Key('email')), 'valid@email.com');
    // タップ前に、*intent*または*event*を示す特別なスナップショットを記録
    final currentStateBeforeClick = container.read(appStateProvider);
    recorder.record(
        AppSnap.fromAppState(currentStateBeforeClick, loginClicked: true));
    await tester.tap(find.byKey(const Key('login')));
    await tester.pumpAndSettle(); // 非同期操作と状態の変更が完了し、記録されるのを待つ

    // 5. プロポジションの定義： AppSnapに関する基本的な真偽の陈述。
    // 期間にわたって成立する条件には `state` を使用します。
    final loading =
        state<AppSnap>((s) => s.isLoading, name: 'loading');
    final home =
        state<AppSnap>((s) => s.isOnHomeScreen, name: 'home');
    final error = state<AppSnap>((s) => s.hasError, name: 'error');
    // `event` を、特定の時点(通常はトランジションのトリガー)を示す条件に使用します。
    final loginClicked =
        event<AppSnap>((s) => s.loginClicked, name: 'loginClicked');

    // 6. LTL 式を定義： 期待される時系列の動作を指定します。
    // 「グローバルに (G)、loginClickedが発生した場合、必ず (->)
    //  次の状態 (X) で読み込み中であり、かつ
    //  最終的に (F) ホーム画面に到達し、かつ
    //  グローバルに (G) エラーが発生しない。」
    // G(loginClicked -> (X loading && F home && G ！error))
    final formula = always(loginClicked.implies(next(loading)
        .and(eventually(home))
        .and(always(error.not()))));

    // 7. 検証： 記録されたAppSnapsのシーケンス(トレース)が式を満たすかどうかを確認する。
    final trace = recorder.trace;
    // temporal_logic_flutter からカスタムマッチャーを使用
    expect(trace, satisfiesLtl(formula)); // または satisfiesMtl
  });
}
```

## 3. 基本概念

### トレースとタイムスタンプ

- **Trace** (`Trace<T>`) は、時間経過に伴うアプリケーションの状態スナップショット (`T`) の順序付きシーケンスを表すコアデータ構造です。関連する状態変更のログや履歴と考えることができます。
- トレースの各要素は **TraceEvent<T>** で、以下の要素を含みます：
- `value`： 状態スナップショット (`T`) 自体。
  - `timestamp`： このスナップショットが記録された時刻(`Duration` 単位で、記録開始からの経過時間)。
- `TraceRecorder` は、`record()` が呼び出された際に、内部の `TimeProvider`(デフォルトは壁時計時間)に基づいてタイムスタンプを自動的に割り当てます。

### 状態のスナップショット(`AppSnap`)

- `Trace<T>` 内の汎用型 `T`(慣習的に `AppSnap` または類似の名前で命名されることが多い)は、アプリケーションの状態の特定の時点における **簡素化され、不変のスナップショット** を表します。これには、検証対象の時間的特性に関連する情報のみが含まれます。
- **なぜ専用の `AppSnap`？
  - **焦点： 検証に必要な特定の状態の側面を隔離し、アプリケーションの全体状態から関連のない詳細(例： 複雑な UI モデル、関連のないデータ)を無視します。
- **不変性： 記録された状態が固定され、後から変更できないことを保証し、信頼性の高いトレース評価に不可欠です。
- **シンプルさ： 命題を定義しやすくし、簡素化された `AppSnap` 構造のみを操作するためです。
  - **分離： メインアプリケーションの状態管理クラスの複雑さから、時制論理テストを分離します。
- **`AppSnap`の設計原則：
- 式に必要なブールフラグ、列挙型、または単純な値のみを含めます。
- 最小限に抑えつつ、十分な機能を提供します。
  - **特に重要： 不変性を確保し、`==`および`hashCode`を正しく実装し、トレース内での比較を適切に行えるようにします。

### 命題： `state` vs `event`

時制論理式は、単一の状態スナップショット(`AppSnap`)に関する真/偽の根本的な主張である**原子命題**を基盤としています。重要な点は、条件が継続的な*状態*を表すか、一時的な*イベント*を表すかを判断することです。

- **`state<T>(Predicate<T> predicate， ｛String？ name｝)`**：
- **目的： アプリケーションが特定の構成またはフェーズ(期間)にある間、条件が成立する`AtomicProposition`を作成します。
  - **`predicate`： 状態スナップショット `state` が条件を満たす場合に `true` を返す関数 `(T state) => bool`。
- **`name`： デバッグ用のオプションの説明名。
- **例： `final isLoading = state<AppSnap>((s) => s.isLoading， name： 'Is Loading')；`
  - **関連項目：** セクション3 - 命題： `state` と `event` の概念的な詳細。

- **`event<T>(Predicate<T> predicate， ｛String？ name｝)`**：
- **目的： 特定の時点での発生またはトリガーを表す `AtomicProposition` を作成します。
  - **`predicate`： `(T state) => bool` 型の関数で、状態のスナップショット `state` がイベントの発生を表す場合、`true` を返します。通常、この述語は特定の スナップショット用に設定された一時的なフラグをチェックします。
- **`name`： デバッグ用のオプションの説明名。
  - **例： `final loginClicked = event<AppSnap>((s) => s.loginClicked， name： 'Login Clicked Event')；`
- **関連項目： セクション 3 - 命題： `state` と `event` および セクション 5 - 一時的なイベントの処理で、概念的および実践的な詳細を確認してください。

**`state` と `event` の選択：

| 機能        | `state<T>`                                     | `event<T>`                                         |
| -------------- | ：--------------------------------------------- | ：------------------------------------------------- |
| **表すもの** | 期間にわたって成立する条件(フェーズ) | 特定の時点での発生(トリガー)       |
| **典型的な使用例**| `isLoading`， `isLoggedIn`， `hasError`          | `buttonClicked`， `requestSent`， `itemAdded`        |
| **述語**  | *複数の*連続したスナップショットで真 | *単一の*スナップショットで真であることが多い |
| **LTL 焦点**  | 期間中*during* 真であるもの               | 何かが起こる*at the moment* 真であるもの   |

この選択は、`next` (X)、`always` (G)、`eventually` (F) などの時制演算子が式を解釈する方法を大幅に左右します。これらの演算子は、トレースにおけるこれらの命題の真/偽の評価のシーケンスに基づいて動作するためです。

### 線形時制論理 (LTL) の基礎

LTLは、トレース内の状態の線形シーケンスに沿って性質を推論します。これにより、状態間の時間的な関係を表現できます。`temporal_logic_core`(`Formula`の拡張メソッドとして利用可能)が提供する主要な演算子：

- **`next(formula)` (X)**： 「次の状態において、`formula`は真でなければならない。」(1ステップ先を見る)。
- **`always(formula)` (G)**： 「この時点以降(現在の状態を含む)、`formula`は常に真でなければならない。」(不変性プロパティ)。
- **`eventually(formula)` (F)**： 「この時点以降(現在の状態を含む)、`formula`は必ず真になる。」(生存性プロパティ、何か良いことが最終的に起こる)。
- **`until(formula1， formula2)` (U)**： "`formula1` は、`formula2` が真になる時点まで*少なくとも 真のまま継続しなければなりません。さらに、`formula2` は*必ず 真になる必要があります。」
- **`release(formula1， formula2)` (R)**： 「`formula2` は、`formula1` が初めて真になる時点まで真でなければならない。`formula1` が真にならない場合、`formula2` は永遠に真でなければならない。」(Until の双対；他の条件によって解放されない限り、条件が成立し続けることを保証するために使用される)。
- 標準論理演算子(`and`， `or`， `not`， `implies`)は、これらの時制演算子と命題を組み合わせます。

### メトリック時制論理(MTL)の基本

MTL は LTL に明示的な時間制約を時制演算子に追加し、物事が*どのくらいの時間*かかるかを推論できるようにします。`temporal_logic_mtl` によって提供されます。

- **`TimeInterval(Duration start， Duration end， ｛bool startInclusive， bool endInclusive｝)`**： 現在の状態のタイムスタンプを基準とした正確な時間窓を定義します。
- **`alwaysTimed(formula， TimeInterval interval)` (G[a，b])**： 「`formula` は、現在の時刻から指定された `interval` 内のタイムスタンプを持つすべての将来の状態において真でなければならない。」(例：「次の5秒間、エラーフラグはfalseでなければならない」)
- **`eventuallyTimed(formula， TimeInterval interval)` (F[a，b])**： 「`formula` は、現在の時刻から指定された `interval` 内のタイムスタンプを持つ将来の状態で真になる必要があります。」 (例： 「2秒以内に成功メッセージが表示される必要があります」)。
- 評価には意味のあるタイムスタンプを持つ`Trace`(通常は`TraceRecorder`によって自動的に処理される)が必要であり、`evaluateMtlTrace`関数を使用します。

## 4. API リファレンス

### `temporal_logic_core` API

#### Formula<T>

すべての時制論理式(LTL)の抽象基底クラス。トレース内の特定の時点での真偽値を評価できる文を表します。

#### AtomicProposition<T>

`Formula` の最もシンプルな形式。単一の状態スナップショット `T` に関する基本の真/偽の文を表し、述語関数を使用して評価されます。`state<T>` と `event<T>` はこのクラスのインスタンスを生成します。

- `bool predicate(T state)`： 指定された状態において命題が真であるかを判定する関数。
- `String name`： 命題の記述的な名前(オプション)。デバッグや評価結果の理解に役立ちます。

#### 論理演算子(`and`， `or`， `not`， `implies`)

これらの演算子は、既存の式を組み合わせてより複雑な論理式を作成します。通常、`Formula<T>` オブジェクトの拡張メソッドとして使用されます。

- **`formula1.and(formula2)`**： トレース内の特定のポイントで、*両方*の `formula1` と `formula2` が真である場合にのみ真となる新しい式を作成します。
- **意味論：** 標準的な論理積 (∧)。
- **例： `isLoading.and(networkUnavailable)`

- **`formula1.or(formula2)`**： トレース内の特定のポイントで、*いずれか `formula1` または `formula2`(または両方)が真である場合に真となる新しい式を作成します。
- **意味論： 標準的な論理和(∨)。
  - **例： `isError.or(isWarning)`

- **`formula.not()`**： トレース内の特定のポイントで、元の `formula` が *false* である場合にのみ真となる新しい式を作成します。
- **意味論： 標準的な論理否定 (¬ または ！)。
  - **例：** `isLoggedIn.not()`

- **`formula1.implies(formula2)`**： 論理的含意を表す新しい式を作成します。トレース内のポイントで真となるのは、`formula1` が偽である場合、または`formula1` と`formula2` の両方が真である場合です。`formula1` が真で`formula2` が偽である場合のみ偽となります。
  - **意味論： 材料含意 (→)。`formula1.not().or(formula2)` と同等です。
- **例： `loginAttempted.implies(isLoading.eventually())` (ログインが試行された場合、最終的に読み込みが発生する必要があります)。

#### LTL 演算子 (`next`， `always`， `eventually`， `until`， `release`)

これらは、時間経過に伴う状態のシーケンスについて推論する基本的な時制演算子です。

- **`formula.next()`** または `next(formula)`:
  - **シンボル:** X `formula`
  - **意味:** `formula` は、トレース内の*直後の*状態において真でなければならない。現在の状態がトレースの最終状態の場合、`next` は通常偽とみなされる(次の状態が存在しないため)。
  - **例:** `requestSent.implies(next(responsePending))` (リクエストが送信された場合、次の状態ではレスポンスが待機中である必要がある)。

- **`formula.always()`** または `always(formula)`:
  - **シンボル:** G `formula`
  - **意味論:** `formula` は、トレース内の *現在の* 状態および *以降のすべての* 状態において、トレースの終了まで真でなければならない。
  - **例:** `loggedIn.implies(always(sessionValid))` (ログイン後、セッションはトレースの残りの期間中有効でなければならない)。
  - **一般的な用途:** 安全性を表現するプロパティや不変条件(悪いことが決して起こらないことを保証する)。

- **`formula.eventually()`** または `eventually(formula)`:
  - **シンボル:** F `formula`
  - **意味:** `formula` は、トレース内のいずれかの時点(現在の状態または将来の状態)で真でなければならない。
  - **例:** `buttonPressed.implies(eventually(operationComplete))` (ボタンが押された場合、操作は後で完了しなければならない)。
  - **一般的な用途:** 生存性プロパティの表現(良いことが最終的に起こるべきである)。

- **`formula1.until(formula2)`** または `until(formula1, formula2)`:
  - **シンボル:** `formula1` U `formula2`
  - **意味:** `formula1` は、現在の状態から *少なくとも* `formula2` が真になる状態まで継続的に真でなければならない。重要な点は、`formula2` は*必ず* 現在の状態以降に真になる必要がある。
  - **例:** `waitingForInput.until(inputReceived)` ('waiting'状態が'inputReceived'が真になるまで継続的に維持され、かつ'inputReceived'は最終的に発生しなければならない)。

- **`formula1.release(formula2)`** または `release(formula1, formula2)`:
  - **シンボル:** `formula1` R `formula2`
  - **意味:** `formula2` は、現在の状態から *および含む* `formula1` が初めて真になる時点まで、継続的に真でなければならない。`formula1` がトレースの残りの部分で真にならない場合、`formula2` はトレースの残りの全期間にわたって真でなければならない。`formula2` は、`formula1` が真になるまで(`formula1` が真になる場合)*少なくとも* 真でなければなりません。これは `until` の論理的双対です。
  - **例:** `errorOccurred.release(operationInProgress)` (操作はエラーが発生するまで少なくとも 'in progress' の状態を維持する必要があります。エラーが発生しない場合、操作は 'in progress' の状態を維持し続けます。) 通常、条件(`formula2`)が、ある解放条件(`formula1`)が発生するまで成立しなければならないことを表すために使用されます。

#### ヘルパー関数(`state`， `event`)

これらのファクトリ関数は、`AtomicProposition`インスタンスを作成する主な方法であり、式の基本構成要素を形成します。

- **`state<T>(Predicate<T> predicate， ｛String？ name｝)`**：
  - **目的： アプリケーションが特定の構成またはフェーズ(期間)にある間、条件が成立する`AtomicProposition` を作成します。
- **`predicate`： 状態スナップショット `state` が条件を満たす場合、`true` を返す関数 `(T state) => bool`。
- **`name`： デバッグ用のオプションの説明名。
  - **例： `final isLoading = state<AppSnap>((s) => s.isLoading， name： 'Is Loading')；`
- **関連項目： セクション 3 - 命題： `state` と `event` の概念的な違い。

- **`event<T>(Predicate<T> predicate， ｛String？ name｝)`**：
  - **目的： 特定の時点での発生またはトリガーを表す `AtomicProposition` を作成します。
- **`predicate`： `(T state) => bool` 型の関数で、状態のスナップショット `state` がイベントの発生を表す場合、`true` を返します。通常、このプレディケートは、特定の スナップショット用に設定された一時的なフラグをチェックします。
  - **`name`： デバッグ用のオプションの説明名。
- **例： `final loginClicked = event<AppSnap>((s) => s.loginClicked， name： 'Login Clicked Event')；`
- **関連項目： セクション 3 - 命題： `state` と `event` および セクション 5 - 一時的なイベントの処理で、概念的および実践的な詳細を確認してください。

### `temporal_logic_mtl` API

このパッケージは `temporal_logic_core` を拡張し、メトリック時制論理(MTL)機能を追加し、式に明示的な時間制約を含めることを可能にします。

#### TimeInterval

タイムド MTL 演算子(`alwaysTimed` や `eventuallyTimed` など)で使用される時間ウィンドウを定義するクラスです。現在の状態の評価時点のタイムスタンプを基準とした範囲を指定します。

- **コンストラクター：** `TimeInterval(Duration start， Duration end， ｛bool startInclusive = true， bool endInclusive = false｝)`
- **`start`**： 区間の開始 `Duration`(現在の時刻に対する相対位置)。
- **`end`**： 区間の終了 `Duration`(現在の時刻に対する相対位置)。
  - **`startInclusive`**： `start` と等しいタイムスタンプがインターバルに含まれるかどうか。デフォルトは `true`。
  - **`endInclusive`**： `end` と等しいタイムスタンプが間隔に含まれるかどうか。デフォルトは `false`。
- **解釈： 間隔 `[start， end)` (デフォルト) は、時間 `t` が `start <= t < end` を満たすことを意味します。`endInclusive` が true の場合、`start <= t <= end` になります。
- **例：
  - `TimeInterval(Duration.zero， Duration(seconds： 5))` は `[0s， 5s)` を表します - 現在の時刻から5秒後まで(ただし5秒は含まれません)。
  - `TimeInterval(Duration(seconds： 2)， Duration(seconds： 10)， endInclusive： true)` は `[2s， 10s]` を表します - 2秒から10秒まで(10秒を含む)。
  - `TimeInterval(Duration(seconds： 1)， Duration(seconds： 1))` は単一の瞬間 `t = 1s` を表します(`startInclusive` が true で、`endInclusive` がデフォルトで false であるため)。

#### タイムド演算子 (`alwaysTimed`， `eventuallyTimed`)

これらの演算子は、LTL の対応する演算子(`always`、`eventually`)に `TimeInterval` 制約を追加して拡張します。

- **`formula.alwaysTimed(interval)`** または `alwaysTimed(formula， interval)`：
- **シンボル：** G[`interval`] `formula`(例： G[0， 5s] `formula`)
  - **意味論： `formula` は、トレース内のタイムスタンプ `t_future` が `t_current + interval.start <= t_future < t_current + interval.end` を満たすすべての将来の状態において真でなければなりません(`interval` のフラグに基づいて包含性を調整します)。インターバル内に状態が存在しない場合、オペレーターは空虚に真です。
  - **例：** `dataFetched.implies(loadingIndicatorVisible.not().alwaysTimed(TimeInterval(Duration.zero， Duration(seconds： 1))))` (データが取得された場合、取得後 0 秒から 1 秒までのインターバル全体において、ローディングインジケーターは *表示されてはならない*)。

- **`formula.eventuallyTimed(interval)`** または `eventuallyTimed(formula， interval)`：
- **シンボル：** F[`interval`] `formula` (例： F[2s， 5s] `formula`)
  - **意味： `formula` は、トレース内のタイムスタンプ `t_future` が `t_current + interval.start <= t_future < t_current + interval.end` を満たす *少なくとも1つの* 将来の状態において真でなければならない(包含性を考慮して調整)。インターバル内の状態が式を満たさない場合、またはインターバル内に状態が存在しない場合、オペレーターは偽となる。
  - **例：** `requestSent.implies(responseReceived.eventuallyTimed(TimeInterval(Duration.zero， Duration(seconds： 3))))` (リクエストが送信された場合、3秒以内にレスポンスが受信されなければならない)。

#### 評価 (`evaluateMtlTrace`)

これは、`temporal_logic_mtl` で MTL 式を満たすタイムドトレースを検証するために使用されるコア関数です。

- **シグネチャ：** `EvaluationResult evaluateMtlTrace<T>(Trace<T> trace， Formula<T> formula， ｛int startIndex = 0｝)`
- **目的： 指定された `formula`(LTL と MTL 演算子を含む可能性あり)が、`trace` の状態 `startIndex` から評価を開始して真となるかどうかを評価します。
- **パラメーター：
- `trace`： 状態のスナップショットとタイムスタンプのシーケンスを含む `Trace<T>` オブジェクト。
  - `formula`： 評価対象の `Formula<T>`(`alwaysTimed` や `eventuallyTimed` などのタイムド演算子を含む可能性あり)。
- `startIndex`： 評価を開始するトレース内のインデックス。デフォルトは `0`(トレースの開始位置)。
- **返り値：** `EvaluationResult` オブジェクト。
- `bool holds`： `startIndex` から始まるトレースに対して式が成立する場合に `true`、そうでない場合に `false`。
- `String？ reason`： `holds` が `false` の場合、式が失敗した理由を説明する文字列を含む可能性があります(例： どのサブ式がどのインデックスまたは時間で失敗したか)。テストの失敗をデバッグするのに役立ちます。
- **使用方法： この関数を直接呼び出すこともできますが、Flutter テストでは通常、`temporal_logic_flutter` が提供する `satisfiesMtl` マッチャーを使用します。このマッチャーは内部でこの関数を呼び出します。

### `temporal_logic_flutter` API

このパッケージは、主に `flutter_test` を使用して Flutter アプリケーションに時制論理テストを統合するためのユーティリティを提供します。

#### TraceRecorder<T>

Flutter 統合用に設計されたヘルパークラスです。実行中のアプリケーションまたはシミュレーションから `Trace<T>` をキャプチャするプロセスを簡素化し、タイムスタンプを自動的に処理します。

- **コンストラクター： `TraceRecorder(｛TimeProvider timeProvider = const WallClockTimeProvider()｝)`
  - `timeProvider`： `record` が呼び出された際に現在のタイムスタンプを取得するためのオプションの `TimeProvider`。デフォルトは `WallClockTimeProvider` で、システムのリアルタイムを使用します。テスト目的では、時間の進行を確定的に制御するためにカスタム `FakeTimeProvider` を注入できます。
- **メソッド：
  - `void initialize()`： レコーダーをリセットし、既存のトレースイベントをクリアし、`timeProvider`に基づいて開始時刻を記録します。各テストまたは記録セッションの開始時に呼び出す必要があります。
  - `void record(T state)`： 指定された `state` スナップショットをキャプチャし、`timeProvider` から取得した現在のタイムスタンプと関連付け、内部トレースに `TraceEvent<T>` として追加します。
- `void dispose()`： 必要なクリーンアップ処理を実行します(現在は最小限ですが、テストでは `addTearDown` を使用して呼び出すのが良い practice です)。
- **ゲッター：**
  - `Trace<T> get trace`： 最後の `initialize()` 呼び出し以降に記録されたすべての `TraceEvent<T>` インスタンスを含む `Trace<T>` オブジェクトを返します。
- **典型的な使用例 (Flutter テスト)：**

1. `TraceRecorder<AppSnap>()` をインスタンス化します。
2. テストの開始時に `recorder.initialize()` を呼び出します。
    3. 状態管理リスナー(Riverpod の `container.listen` など)またはテストインタラクション内の手動呼び出しを使用して、関連する状態変更が発生したりイベントをマークする必要があるたびに `recorder.record(AppSnap.fromAppState(...))` を呼び出します。
4. インタラクション後、`recorder.trace` にアクセスし、`satisfiesLtl` マッチャーと共に `expect` ステートメントに渡しします。
    5. `addTearDown` を使用して `recorder.dispose()` を呼び出します。

#### マッチャー (`satisfiesLtl`)

カスタム `flutter_test` マッチャーで、時制論理の評価を `expect` ステートメントに直接統合し、テストの読みやすさを向上させます。

- **`Matcher satisfiesLtl<T>(Formula<T> formula)`**
  - **目的：** 指定された `Trace<T>` が与えられた LTL `formula` を満たすかどうかを確認する `Matcher` を作成します。
  - **仕組み：** 内部では、このマッチャーは `expect` に渡されたトレースに対して LTL 評価関数 (`temporal_logic_core` の `evaluateTrace` など) を呼び出します。
  - **使用方法：**

      ```dart
      final trace = recorder.trace;
      final ltlFormula = always(isSuccess.implies(isError.not()));
      expect(trace, satisfiesLtl(ltlFormula));

      // 否定形も可能です：
      expect(failedTrace, isNot(satisfiesLtl(ltlFormula)));
      ```

  - **失敗時の出力：** マッチが失敗した場合、通常は説明的なエラーメッセージが提供され、多くの場合、基盤となる `EvaluationResult` から理由を含み、トレース内で式が違反した場所と理由を示します。
  - **❗ ウィジェットテストに関する重要な注意：** このマッチャーは便利ですが、Flutter ウィジェットテスト、特に複雑なフォーミュラ (例: `P.and(eventually(Q))`) や `TraceRecorder` によって動的に生成されたトレースを使用する場合、一貫性のない動作 (ちらつき) を示すことがあります。これは、テスト環境の非同期性とマッチャーとの相互作用に起因する可能性が高いです。**ウィジェットテストで信頼性の高いテストを行うためには、`temporal_logic_core` の `evaluateTrace` を直接呼び出して結果をアサートすることを強く推奨します。** 詳細は以下のクックブックの「ウィジェットテストでのテスト」セクションを参照してください。

## 5. クックブック \& ベストプラクティス

このセクションでは、プロジェクトで時制論理パッケージを効果的に使用する実践的なアドバイス、パターン、コードスニペットを提供します。

### 状態管理との統合 (Riverpod 例)

Flutter テストでトレースをキャプチャする最も一般的な方法は、状態管理ソリューションの変更を監視し、関連する状態更新が発生した際に `AppSnap` を記録することです。以下は Riverpod を使用した詳細な例です：

**前提条件：**

- Riverpodの`StateNotifierProvider`(例： `appStateProvider`)があり、メインアプリケーションの状態(`AppState`)を公開しています。
- `AppSnap`クラスがあり、ファクトリコンストラクタ`AppSnap.fromAppState(AppState state， ｛bool transientEventFlag = false｝)`を備えています。

**テスト設定：**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temporal_logic_flutter/temporal_logic_flutter.dart'
    as tlFlutter;
import 'package:temporal_logic_core/temporal_logic_core.dart' as tlCore;
// AppState、AppSnap、プロバイダー、およびメインアプリウィジェットをインポート
// ...

void main() {
  testWidgets('Example Riverpod Integration Test', (tester) async {
    // 1. レコーダーとプロバイダーコンテナを作成
    final recorder = tlFlutter.TraceRecorder<AppSnap>();
    // テスト用に状態を隔離するための新しいコンテナを作成
    final container = ProviderContainer();
    // テスト終了時にコンテナを破棄する
    addTearDown(container.dispose);

    // 2. レコーダーの初期化(タイムトラッキングを開始)
    recorder.initialize();

    // 3. リスナーを登録する前に初期状態を記録
    // プロバイダーから初期状態を直接読み込む
    final initialState = container.read(appStateProvider);
    recorder.record(AppSnap.fromAppState(initialState));

    // 4. 状態の変更を監視
    // container.listenを使用してAppStateの変更に反応する
    container.listen<AppState>(
      appStateProvider, // 監視対象のプロバイダー
      (previousState, newState) {
        // 重要： AppState が変更された際に newState を記録する。
        // AppSnap.fromAppState ファクトリはスナップショット用の
        // 関連するブール値/列挙値を抽出する責任を負う。
        recorder.record(AppSnap.fromAppState(newState));
      },
      // オプション： fireImmediately： true (初期状態を別途記録していない場合)
      // オプション： プロバイダーのエラーを処理するための onError
    );

    // 5. テストコンテナでウィジェットツリーをプッシュ
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MyApp(), // ルートウィジェット
      ),
    );
    // 初期ビルドと状態の安定化を許可
    await tester.pumpAndSettle();

    // --- テストインタラクション ---
    // 例： ログインボタンをタップする動作をシミュレート

    // 一時的なイベント用にオプションですが推奨：
    // イベントトリガー直前の状態をイベントフラグを設定して記録
    final stateBeforeClick = container.read(appStateProvider);
    recorder.record(AppSnap.fromAppState(stateBeforeClick, loginClicked: true));

    // ボタンを検索してタップ(プロバイダー経由でAppStateを更新すると仮定)
    await tester.tap(find.byKey(const Key('login')));

    // 非同期操作と状態更新の propagation を待つ
    await tester.pumpAndSettle();

    // --- 検証 ---
    final trace = recorder.trace;
    final formula = always(/* ... あなたの LTL/MTL 式 ... */);

    expect(trace, satisfiesLtl(formula));

    // レコーダーは必要に応じてaddTearDown経由で自動的に破棄されますが、
    // コンテナの破棄が通常より重要な部分です。
  });
}
```

**重要なポイント：**

- **状態の隔離：** テスト専用の `ProviderContainer` を使用します。
- **初期状態： *listen 前に状態を記録し、T=0 をキャプチャします。
- **listen フック： `container.listen` は、以降の状態を自動的に記録するコアメカニズムです。
- **`AppSnap` ファクトリ： `AppSnap.fromAppState` ロジックは、検証に必要な簡素化されたスナップショットに変換するために、複雑な `AppState` を変換する上で不可欠です。
- **一時的なイベント： ボタンクリックや類似の一時的なイベントは、イベントが発生する直前にまたはその瞬間に、特定のフラグを設定した `AppSnap` を手動で記録して処理します(セクション5 - 一時的なイベントの処理を参照)。
- **`pumpAndSettle`： 相互作用後に liberally 使用し、相互作用によってトリガーされたすべての状態変更がリスナーによって処理され記録されることを確認します。

このパターンは、プロバイダーが露出する `AppState` に状態変更が反映されている限り、テストロジックを状態変更の具体的な実装から分離します。

### 効果的な `AppSnap` タイプの設計

`AppSnap` クラス(または状態スナップショット型 `T` の任意の名称)は、時系列論理テストのセットアップにおいて最も重要な要素です。適切に設計された `AppSnap` は、テストを明確で堅牢かつメンテナンスしやすいものにします。以下の原則を遵守してください：

- **目的の再確認： `AppSnap` は、特定のテストまたはテストスイートで評価する時間的性質を評価するために必要な情報のみを含む、アプリケーション状態の*簡略化されたビュー*です。アプリケーションの全体状態を再現するものではありません。

- **不変性が重要：
  - **なぜ？** 時刻論理は、*固定*された状態のシーケンスを評価することに依存しています。スナップショットが記録後に変更可能であれば、評価は無意味かつ予測不能になります。
- **どのように？** すべてのフィールドを`final`として宣言します。`AppSnap`内に保持されるオブジェクトも不変であること(または不変として扱うこと、例えば変更可能な場合は参照ではなくデータをコピーする)を確認します。
  - **利点： 各`TraceEvent`が特定の時刻における一意で不変の状態を表すことを保証します。

- **関連性(最小限だが十分)：
- **なぜ？ `AppSnap`に不要な状態情報を含めると、理解が困難になり、関連のない変更が記録を引き起こす可能性が増加し、パフォーマンスにわずかな影響を与える可能性があります。
  - **どのように？** 作成する各時系列式に対して、依存する特定のブール条件または列挙値を特定します。`AppSnap` に含めるフィールドは、これらの条件を導出するために必要なもののみに限定します。例えば、`user ！= null` のみを気にする場合、`User` オブジェクト全体ではなく、ブール型の`isLoggedIn` フィールドを含めます。
  - **メリット： テストを集中させ、トレースのノイズを削減し、命題定義を簡素化します。

- **状態論理を導出する、重複を避ける：**
- **なぜ？** アプリケーションの状態(例：Riverpod、Blocなど)は唯一の真実のソースです。`isLoading`や`hasError`を決定する論理を`AppSnap`ファクトリやテストセットアップ内で再実装すると、論理の重複と潜在的な不一致が発生します。
  - **どのように？** ファクトリコンストラクタ(例：`AppSnap.fromAppState(AppState state)`)を使用して`AppSnap`インスタンスを作成し、実際のアプリケーション状態オブジェクトを入力として渡します。このファクトリ内で、実際の状態オブジェクトから必要なプロパティを読み取り、`AppSnap`の簡素化されたフィールドにマッピングします。
  - **メリット： `AppSnap` が記録時のソースオブザトゥルース状態を正確に反映し、論理の重複を回避します。

- **`==` と `hashCode` を正しく実装する：
- **なぜ？ 評価エンジンは、スナップショットを比較して安定した状態、サイクル、または命題が一致するかどうかを検出する場合があります。これらの比較には正しい等価性チェックが不可欠です。
- **どのように？
  - `equatable` パッケージを使用して、簡単かつ信頼性の高い実装を実現します。
- または、`==` と `hashCode` を手動でオーバーライドし、すべてのフィールドを比較し、契約(`a == b` であれば `a.hashCode == b.hashCode`)を満たすようにします。
- **メリット：** 状態の安定性や反復を含む一時的な式の評価を信頼性高く保証します。

**例構造：**

```dart
import 'package:equatable/equatable.dart';

// 状態管理から取得した AppState クラスを仮定
class AppState {
  final User? currentUser;
  final bool networkFetchIsLoading;
  final String? lastErrorMessage;
  final List<Item> items;
  // ... その他の状態フィールド
}

// 簡略化したスナップショットクラス
class AppSnap extends Equatable {
  final bool isLoggedIn;
  final bool isLoading;
  final bool hasError;
  final int itemCount;
  final bool transientLoginClick; // イベントのマーク用

  const AppSnap({
    required this.isLoggedIn,
    required this.isLoading,
    required this.hasError,
    required this.itemCount,
    this.transientLoginClick = false, // デフォルトは false
  });

  // 実際の状態から作成するファクトリ
  factory AppSnap.fromAppState(AppState state, {bool loginClicked = false}) {
    return AppSnap(
      isLoggedIn: state.currentUser != null,
      isLoading: state.networkFetchIsLoading,
      hasError: state.lastErrorMessage != null &&
          state.lastErrorMessage!.isNotEmpty,
      itemCount: state.items.length,
      transientLoginClick: loginClicked, // 渡された値を使用
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

これらの原則に従うことで、アプリケーションの状態と時制論理検証の形式要件を効果的に橋渡しする`AppSnap` タイプを作成できます。

### 一般的な LTL/MTL パターン

時制論理式は、システムの動作の根本的な性質を表現する反復的なパターンに従うことがよくあります。これらのパターンを理解することは、効果的なテストを策定するのに役立ちます。以下に、一般的なパターンとその典型的な LTL/MTL 表現を示します：

(`request`， `response`， `errorState`， `action`， `completion`， `loading`， `formValid`， `submitEnabled` などの標準的な命題が `AppSnap` に基づいて定義されているものと仮定します)

- **レスポンス(最終的に)：**「ある条件(`request`)は、最終的に別の条件(`response`)に続く必要があります。」
- **意味：`request`が発生した場合、システムは`response`がいつか発生することを保証します。*いつ*ではなく、*必ず*発生することを示しています。
  - **式：** `always(request.implies(eventually(response)))`
- **LTL：** `G(request -> F response)`
- **使用例：** アクションが期待される結果に導くことを検証する(例： データの送信が最終的に成功確認に導く、確認応答が受信されるなど)

- **応答(次)： "`request`が発生した場合、`response`は次の状態において必ず発生しなければならない。」
- **意味： 効果(`response`)は、原因(`request`)に続く状態遷移において即時でなければならない。
- **式： `always(request.implies(next(response)))`
- **LTL： `G(request -> X response)`
  - **使用例： 同期アクション後の即時状態更新のテスト(例： ボタンをクリックするとすぐに別の機能が有効になる)。

- **安全(Never / Invariant)： "特定の望ましくない状態(`errorState`)は決して発生してはならない。」
- **意味： 式がチェックされる時点から実行トレース全体において、`errorState` 条件は常に false でなければならない。
  - **式：** `always(errorState.not())`
- **LTL：** `G(！errorState)`
- **使用例：** 重要な安全制約を強制し、禁止状態が到達不能であることを保証する(例： ユーザーは管理画面を表示してはならない、システムはデッドロック状態に陥ってはならない)。

- **生存性(最終的に)： "アクションがトリガーされた場合、その完了は最終的に発生しなければならない。」
- **意味： アクションが発生した後、システムは最終的に進捗し、完了状態に達しなければならない。これは終了または最終的な成功を保証する。
- **式： `always(action.implies(eventually(completion)))`
  - **LTL：** `G(action -> F completion)`
- **使用例： プロセスが停止しないことを保証し、リクエストが最終的に処理され、進行状況インジケーターが最終的に消える。

- **Timed Response (MTL)： "`request`が発生した場合、`response`は特定の時間間隔(例： 5秒)以内に発生しなければならない。」
  - **意味： 基本のレスポンスパターンにリアルタイム制約を追加します。
- **式： `always(request.implies(response.eventuallyTimed(TimeInterval(Duration.zero， Duration(seconds： 5)))))`
- **MTL： `G(request -> F[0s， 5s] response)`
  - **使用例： パフォーマンス要件のテスト、タイムアウト、指定された期間内に完了するアニメーション、ユーザーフィードバックの即時表示。

- **フラッカーなし / フェーズ中の安定性： 「特定のフェーズ条件(`loading`)が真である間、望ましくない一時的な条件(`error`)は決して真になってはならない。」
- **意味： 特定の操作中の安定性を保証します。`error`条件は、`loading`条件が真である限り禁止されます。
  - **式1 (厳格)：** `always(loading.implies(error.not()))`
- **LTL： `G(loading -> ！error)` (エラーは*決して* trueになってはならない)
- **式2 (Untilを使用)： `always(loading.implies(error.not().until(loading.not())))`
  - **LTL：** `G(loading -> (！error U ！loading))` (loading が開始されると、error は loading が false になるまで少なくとも false のまま維持されなければならない)
- **使用例：** ロード中の一時的なエラーメッセージの防止、トランジション中の UI 一貫性の確保、プロセス中に特定のアクションが無効化されていることを検証する。

- **状態順序：** "状態 `phaseA` は、`phaseC` が発生する前に必ず`phaseB` に続いていなければならない。」
- **意味：** 主要な状態の特定のシーケンスを強制する。
- **式 (概念的 - 厳格さに応じて精緻化が必要)：** `always(phaseA.implies(phaseC.not().until(phaseB)))`
  - **LTL：** `G(phaseA -> (！phaseC U phaseB))`
- **使用例： ウィザード、マルチステッププロセス、セットアップフェーズが完了する前にオペレーションフェーズが開始されないことを確認する。

これらのパターンは出発点を提供します。複雑な動作は、論理演算子(`and`、`or`、`implies`、`not`)を使用してこれらのパターンを組み合わせる必要があります。

### 非同期操作のテスト

Flutterアプリケーションは、ネットワークリクエスト、データベースアクセス、複雑なアニメーションなど、非同期操作(`Future`、`Stream`)に依存しています。これらの操作の周辺における時系列動作をテストするには、`flutter_test`内で慎重な処理が必要です。

**課題：**

- **中間状態： 非同期操作は複数の状態変更を伴うことが多く(例： `initial -> loading -> success` や `initial -> loading -> error`)。正確な時間的検証のため、*すべての*関連する中間状態を捕捉することが重要です。
- **タイミング： MTL テストでは、これらの状態変更がトリガーとなるアクションに対するタイミングが主要な焦点です。

**テクニック：**

1. **状態管理リスナー(主要な方法)： Riverpod の例(セクション 5.1)で示されるように、状態管理のリスナーメカニズム(`container.listen`、`bloc.stream.listen`)を使用するのが最も堅牢な方法です。リスナーは、状態オブジェクトが更新されるたびに自動的に `recorder.record()` を呼び出します。これは、同期的にトリガーされたか非同期的にトリガーされたかにかかわらず機能します。

2. **`tester.pumpAndSettle()`：** 非同期アクション (`tap`, `enterText`) をトリガーした後に重要です。Future/Stream/Timer/Animation が完了するのを許可し、検証前に後続の状態変更が記録されるようにします。

3. **一時的なイベントの処理：** `TraceRecorder` を使用して特定のイベントマーカーを手動で記録します (該当セクション参照)。

**ウィジェットテストにおける信頼性の高い LTL/MTL 検証：**

`satisfiesLtl` API の説明で述べたように、`expect` 内で `satisfiesLtl` マッチャーを使用すると、テスト環境との相互作用により、複雑なウィジェットテストシナリオで一貫性のない結果が生じる可能性があります。

**推奨される最も信頼性の高いアプローチは、`evaluateTrace` 関数 (`temporal_logic_core` から) を直接使用することです：**

```dart
// ウィジェットテストでの推奨アプローチ：
import 'package:temporal_logic_core/temporal_logic_core.dart';
import 'package:flutter_test/flutter_test.dart';
// ... 他のインポート ...

testWidgets('LTL プロパティを確実に検証する', (tester) async {
  // ... TraceRecorder のセットアップ、ウィジェットとの対話 ...
  await tester.pumpAndSettle(); // 状態が安定するのを保証

  final trace = recorder.trace;
  final formula = /* ... LTL フォーミュラを定義 ... */;

  // 1. evaluateTrace を直接呼び出す
  final EvaluationResult result = evaluateTrace(trace, formula);

  // 2. 結果の 'holds' プロパティをアサートする
  expect(
    result.holds,
    isTrue,
    reason: 'LTL フォーミュラは保持されるべきです。失敗理由: ${result.reason}',
  );

  // 回避： expect(trace, satisfiesLtl(formula));
});
```

この直接評価メソッドは、ウィジェットテスト環境内でのマッチャーの潜在的な不整合を回避し、より安定した信頼性の高いテストにつながります。

### 一時的なイベントの処理 (`loginClicked`)

ボタンクリック、ジェスチャー、単一の通知の受信、フォームの送信など、多くのイベントは、メインの状態で永続的に観測可能な変更を引き起こすのではなく、状態変更の*トリガー*として機能します。例えば、『ログイン』をクリックすると、すぐに非同期ネットワーク呼び出しがトリガーされ、状態が`loading`に後から変更される場合がありますが、『クリック』自体はその`AppState`に永続的に保存されません。

**課題：** メインの `AppState` がリスナー経由で変更された際にのみ `AppSnap` を記録する場合、イベントが発生した *正確な瞬間* を逃す可能性があります。これにより、イベントの即時的な結果に依存する式(例： `G(loginClicked -> X loading)`)の検証が困難または不可能になります(グローバルに、ログインがクリックされた場合、*次の*状態は loading でなければならない)。

**解決策： 明示的なイベント記録**

解決策は、テストコード内でイベントが発生した正確なタイミングで特別な `AppSnap` を手動で記録し、一時的なフラグでマークすることです。

**手順：**

1. **`AppSnap` に一時的なフラグを追加： `AppSnap` クラスに、このイベントをマークするための専用のブール型フィールドを追加します(例： `final bool loginClicked；`)。コンストラクター/ファクトリーで明示的に設定されない限り、デフォルト値を `false` に設定します。

```dart
// AppSnap クラス内
final bool transientLoginClick;

const AppSnap({
  // ... 他のフィールド
  this.transientLoginClick = false, // デフォルト値を false に設定
});

factory AppSnap.fromAppState(AppState state, {bool loginClicked = false}) {
  return AppSnap(
    // ... 状態から他のフィールドをマッピング ...
    transientLoginClick: loginClicked, // 渡された値を使用
  );
}
```

2. **テストでのトリガーの特定：** `flutter_test` コード内でイベントをシミュレートする行(例： `await tester.tap(...)`、`await tester.enterText(...)`)を特定します。

3. **記録*トリガー前*： *イベントをシミュレートする行の直前に*、現在のアプリケーション状態を読み取り、手動で `recorder.record()` を呼び出します。現在の状態を渡し、一時的なフラグを `true` に上書きします。

```dart
// --- テストインタラクション --- 
// タップアクション前の現在の状態を取得
final stateBeforeClick = container.read(appStateProvider);
    
    // *** イベントの発生を手動で記録 ***
recorder.record(AppSnap.fromAppState(stateBeforeClick, loginClicked: true)); 

// 実際のイベントをシミュレート
await tester.tap(find.byKey(const Key('loginButton')));
// pumpAndSettle などを実行
await tester.pumpAndSettle();
```

4. **暗黙のリセット：** *next* 回に `recorder.record()` が呼び出された場合(おそらくタップの consequence に反応する状態リスナーや、別の手動記録によって)、`AppSnap.fromAppState` ファクトリは *without* `loginClicked： true` を明示的に設定せずに呼び出され、フラグは次のスナップショットでデフォルトの `false` 値に自然にリセットされます。

5. **使用 `event<T>` 提案： 特定の transient フラグをチェックする一時的な論理命題を `tlCore.event<T>` を使用して定義します。

```dart
final loginClicked = tlCore.event<AppSnap>(
  (s) => s.transientLoginClick, 
  name： 'loginClickedEvent'
);
// 次に、次のような式で使用できます：
final formula = tlCore.always(loginClicked.implies(tlCore.next(isLoading)));
```

**なぜこれが機能する：** このテクニックは、テストフロー内でイベントが論理的に発生したとみなされる正確なポイントに一意のマーカーをトレースに挿入します。これにより、`X` (Next) のような時制演算子や、F[0， ...] (Eventually within 0 seconds...) のようなタイムド演算子が、イベントトリガー直後の状態を正確に推論できるようになります。

### パフォーマンスに関する考慮事項

時制論理テストは強力な検証機能を提供しますが、特にテストスイートの実行時間において、潜在的なパフォーマンス影響に注意が必要です。

- **トレース記録頻度：**
- **影響： アプリケーションの状態が非常に頻繁に変化し、リスナーが各変更ごとに `AppSnap` を記録する場合、非常に長いトレースが生成される可能性があります。
- **緩和策：
  - **選択的記録： 本当にすべての中間状態をキャプチャする必要があるかどうかを検討してください。状態リスナー内でフィルタリングやデバウンスを実施したり、特定の状態移行のみを記録したりする方法は受け入れ可能ですが、*注意が必要*です。これにより、捕捉したい一時的なバグが隠れる可能性があります。
- **効果的な `AppSnap`： 適切に設計された最小限の `AppSnap` は、*関連する*状態変更時のみ記録し、不要なトレースイベントを削減します。
  - **フォーカステスト：** アプリケーションのフローの大部分をカバーする巨大なテストではなく、より短いインタラクションシーケンスに焦点を絞ったテストを書き、トレースの長さを自然に制限します。

- **`AppSnap` 複雑さ：**
  - **影響： `AppSnap` インスタンスの作成(特に `fromAppState` ファクトリ内)では、実際の状態から読み込み新しいオブジェクトを構築します。このファクトリが複雑な計算や大規模なデータ構造の深部コピーを行う場合、`record()` が呼び出されるたびにオーバーヘッドが発生します。
  - **緩和策： `AppSnap.fromAppState` ファクトリを軽量化してください。単純なフィールド代入とブールチェックに限定し、ファクトリ内での深部コピーや複雑な計算を避けてください。

- **式評価の複雑さ：
- **影響： 特にネストされた時制演算子や非常に長いトレースに対するチェックを含む複雑な LTL/MTL 式の評価には計算リソースが必要です。
- **緩和策：
  - **よりシンプルな式： 可能な限り、よりシンプルで直接的な式を優先してください。複雑なプロパティを複数の小さな検証可能な式に分解できる場合はそうしてください。
- **トレースの長さ： 先ほど述べたように、トレースを適切に短く保つことで評価速度が向上します。
- **MTLの精度： MTLでは、非常に細かい粒度の`TimeInterval`を使用すると、より多くの状態をチェックする必要が生じる可能性があります。ただし、この影響は通常、全体のトレースの長さや式複雑さよりも小さくなります。

- **テスト実行時間：
- **全体的な影響： 上記の点は、`flutter_test` スイートの実行時間を増加させる可能性があります。
- **視点： テンポラルロジックテストは本質的にシーケンスを検証するため、単一の状態を確認するシンプルなユニットテストやウィジェットテストよりも、設定や相互作用がより多く必要です。テスト時間のわずかな増加は、検証能力の向上とのトレードオフとして価値がある場合が多いです。

**一般的な推奨事項：**

- 検証要件を満たす最もシンプルな `AppSnap` と記録戦略から開始してください。
- テストの遅延が顕著な場合、`AppSnap` の作成と式複雑度を最適化してください。
- パフォーマンスが critical 問題となった場合、テストをプロファイルしてください。ただし、検証の正確性と徹底性を最優先してください。

ほとんどの一般的な Flutter アプリケーションのテストシナリオでは、これらのパッケージの使用によるパフォーマンスオーバーヘッドは、複雑な一時的なバグを検出するメリットと比べて、通常は許容可能な範囲内です。

## 6. 追加の例

このセクションでは、一時論理テストが大きな価値を提供する可能性のあるアプリケーションのシナリオを概説します。(注：これらの例は現在概念的なもので、今後の実装が追加される可能性があります。)

### フォーム検証フロー

- **シナリオ： 複数のフィールド、リアルタイム検証、およびすべてのフィールドが有効な場合にのみ有効になる送信ボタンを備えたフォーム。
- **検証対象の時間的プロパティ：
- 「送信ボタンは、フォームが有効(`formValid`)でない限り、決して有効にならない(`submitEnabled.not()`)。」(安全性： `G(submitEnabled -> formValid)`)
  - 「無効なフィールド(`fieldXInvalid`)が修正されると、最終的に全体のフォーム有効ステータス(`formValid`)が真になる(他のフィールドが有効である場合)。」(ライブネス：`G(fieldXCorrection -> F(formValid))`)
  - 「送信後(`submitClicked`)、フォームは最終的にローディング状態(`loading`)に入り、その後成功(`success`)またはエラー(`error`)状態になります。」 (レスポンスシーケンス： `G(submitClicked -> F(loading.and(F(success.or(error)))))`)

### アニメーションシーケンス検証

- **シナリオ：** 複数の段階や異なる要素の協調した動きを含む複雑なUIアニメーション。
- **検証対象の時間的性質：**
- 「アニメーションが開始された場合(`animationStart`)、最終的に終了状態(`animationEnd`)に達しなければならない。」 (生存性： `G(animationStart -> F(animationEnd))`)
  - 「アニメーションのフェーズ2 (`phase2Active`) は、フェーズ1 (`phase1Active`) が終了するまで開始されない (`phase1Finished`)。」 (順序： `G(phase2Active -> X(！phase1Active.until(phase1Finished)))` - 簡略化)
  - 「アニメーション全体は500ミリ秒以内に完了する必要があります。」 (タイムドライブネス： `G(animationStart -> F[0ms， 500ms](animationEnd))`)
- 「要素A (`elementAPositioned`) はアニメーション終了後、最終位置に保持されます。」 (安定性： `G(animationEnd -> G(elementAPositioned))`)

### ネットワークリクエストライフサイクル

- **シナリオ：** サーバーからデータを取得する際の状態管理(ローディングインジケーターとエラー処理を含む)。
- **検証すべき時間的性質：
- 「リクエストが送信された(`requestSent`)場合、ローディングインジケーター(`isLoading`)は即座にまたは次の状態で真になる。」 (即時応答： `G(requestSent -> isLoading.or(X(isLoading)))`)
  - 「リクエストが送信された(`requestSent`)場合、最終的に成功状態(`success`)または失敗状態(`failure`)に到達しなければならない。」 (生存/完了： `G(requestSent -> F(success.or(failure)))`)
- "読み込みインジケーター(`isLoading`)は、リクエストが送信された後に最終的にfalseになる必要がある。」 (生存/終了： `G(requestSent -> F(isLoading.not()))`)
- 「リクエストが失敗した場合(`failure`)、ユーザーがアクションを実行するまで(`dismissError`)エラーメッセージ(`hasError`)が表示される。」 (状態保持： `G(failure -> hasError.until(dismissError))`)
  - 「リクエストは、10秒以内に成功応答を受け取らない場合、タイムアウト(`failure`状態に達する)する必要があります。」 (タイムドレスポンス： `G(requestSent.and(！success.eventuallyTimed(TimeInterval(Duration.zero， Duration(seconds:10))))) -> F(failure))`)

## 7. トラブルシューティング

一時論理テストの記述と実行時に遭遇する一般的な問題とデバッグ戦略を以下に示します：

- **式が期待通りに評価されない(テストが論理的に失敗する)：**
- **症状： `expect(trace， satisfiesLtl(formula))` が失敗するが、アプリケーション論理は正しいと信じている。
  - **命題定義の確認：**
    - **`state` vs `event`： 一時的にのみ成立する条件に `state` を使用しましたか、または持続する条件に `event` を使用しましたか？セクション 3 - 命題： `state` vs `event` およびセクション 4 - API リファレンスを確認してください。
    - **述語論理：** `state`/`event` 内の述語関数 `(s) => ...` が、`AppSnap` フィールドに基づいて条件を正しく反映していますか？述語内にプリント文を追加するか、別でテストしてください。
- **`AppSnap` マッピング：** `AppSnap.fromAppState` ファクトリが、実際のアプリケーション状態を命題で使用される`AppSnap` フィールドに正しくマッピングしていますか？このマッピング論理を確認してください。
  - **式論理の確認：**
- **演算子の意味論： LTL/MTL演算子(X， G， F， U， R， G[]， F[])の理解を再確認してください。表現したい性質に適切な演算子を使用していますか？セクション3および4を参照してください。
  - **演算子の優先順位/グループ化：** 論理演算子(`and`， `or`， `implies`)と時制演算子が意図した通りに結合されるように、括弧 `()` を使用してください。`A.implies(B.and(C))` は `A.implies(B).and(C)` と異なり、`A.implies(B.or(C))` は `A.implies(B).or(C)` と異なります。
- **簡素化：** 複雑な式の一部を一時的にコメントアウトして、どの部分式が失敗しているかを特定してください。
  - **可視化/シミュレーション：** 複雑なLTLの場合、状態シーケンスを紙にスケッチするか、オンラインのLTL可視化ツール/モデルチェッカー(抽象命題名を使用)を使用して、異なるシナリオでの式挙動を確認します。
- **トレースを確認：** 記録されたトレースは評価の基準となります。
  - **トレースの出力：** `expect`呼び出しの前に `print(recorder.trace.events.map((e) => '\$｛e.timestamp｝： \$｛e.value｝').join('\\n'))；`(または類似のコード)を追加し、記録された`AppSnap`オブジェクトとタイムスタンプの正確なシーケンスを確認します。
  - **手動でのトレース追跡：** プリントされたトレースを手動で追跡し、各ステップで式を評価します(特にマッチャーの出力で示された失敗ポイント周辺に注意)。期待と異なる点を探します。
- **タイムスタンプ (MTL)：** MTL 失敗の場合、プリントされたトレース内の `timestamp` 値に注意してください。タイムスタンプは期待通りに進んでいますか？関連するイベント間の期間は、`TimeInterval` の設定と一致していますか？

- **テストが予期せず失敗する(トレースが現実と一致しない)：**
- **症状：式は正しいように見えますが、テストが失敗するのは、記録されたトレースがテスト実行中のアプリケーションの動作を正確に反映していないためです。
- **AppSnapの作成を確認：上記と同様に、`AppSnap.fromAppState`がライブアプリケーションの状態を正しく変換していることを確認してください。
  - **レコーダーのリスニング/記録を確認：**
- **リスナーの設定： 状態リスナー(`container.listen`、`bloc.stream.listen`)は、初期状態が記録された後*after* ですが、インタラクションが始まる前*before* に正しく設定されていますか？
  - **リスナーが捕捉していない状態：** リスナーは*すべての*関連する中間状態を捕捉していますか？特に、状態の急激な変更や非同期操作時。状態管理ソリューションは、特定の条件下で中間状態をデバウンスまたはスキップする可能性があります。必要に応じて、リスナーがすべてのエミッションを捕捉していることを確認してください。
- **手動記録： 一時的なイベントを処理する場合、テストのインタラクションフローの*正確なタイミング*で`recorder.record(...)`を呼び出していますか？
  - **`pumpAndSettle`/`pump` 使用：
- **不十分なセッティング： 非同期作業や状態変更を引き起こすインタラクション(`tap`、`enterText` など)の*後*に `await tester.pumpAndSettle()` を実行していますか？非同期操作が連鎖している場合、複数の `pumpAndSettle` 呼び出しが必要になる場合があります。
  - **不正な `pump` 期間： `pump(duration)`を使用する場合、期間が予想される非同期処理の完了またはタイマーの発火に十分ですか？
- **`pump` と `pumpAndSettle` の混在： 違いを理解してください。`pump`は単に時間を進めます；`pumpAndSettle`はスケジュールされたすべての処理を完了させようとします。

- **依存関係の問題 / 設定エラー：
  - **症状： セットアップ中にテストが失敗する、`pub get` 問題、型エラー。
- **確認 `pubspec.yaml`： `temporal_logic_*` パッケージと Flutter/Dart SDK の制約が一致していることを確認してください。モノレポ内で作業している場合は、`path：` 依存関係を正しく使用してください。
  - **クリーンビルドの実行：** `flutter clean` と `flutter pub get` を実行して、キャッシュ関連の問題を解決します。
- **プロバイダースコープ：** 状態管理統合を使用している場合、テストウィジェットツリーが適切な `ProviderScope` (または `BlocProvider` など) で囲まれていることを確認してください。

---
