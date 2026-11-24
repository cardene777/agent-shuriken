# Remotion Explainerの仕組み

[English](how-it-works.md) · 日本語

このページは、`remotion-motion-plan`と`remotion-frame-checks`の確かめる仕組みが、それぞれ何を読み、どう決め、何を書くかを説明します。
確かめる仕組みは8つのNode.jsのスクリプトで、4つが`skills/remotion-motion-plan/scripts/`に、4つが`skills/remotion-frame-checks/scripts/`にあり、Node.js 18以降に初めから入っている部品だけを使います。

## 確かめる仕組みの動き方

どの仕組みも、コマンドで名指したファイルだけを読みます。
標準出力には、`check`、`decision`、`issueCount`、`issues`を持つJSONを1つ出します。
`issues`の1つずつは、破った決まりの`rule`、対象の`element`か`scene`か`frame`か一覧の`entry`、説明の`message`を持ちます。

| 終わりのコード | 意味 |
|---|---|
| 0 | ファイルが通り、`decision`は`pass`です |
| 1 | ファイルを直す必要があり、`decision`は`revise`です |
| 2 | 呼び方が誤っているか、ファイルを読めませんでした。理由を標準エラーに出し、標準出力には何も出しません |

## 振り付け

`check-choreography.mjs`は`storyboard/choreography-plan.json`を読みます。
場面ごとに、場面、カメラ、物、動きの区切りの項目がそろっているかを見てから、場面を止まった絵でなく場面にする3つの点を見ます。

| 決まり | 決め方 |
|---|---|
| `no-late-introduction` | どの物の`introducedAt`も`entry`です |
| `no-state-change` | どの物の`resultState`も`entryState`と同じです |
| `motion-variety` | 動きの区切りの種類が2つより少ないです |

計画の全体では、場面ごとの見せ方の型を前の場面と比べ、横へ運ぶ場面を数えて2つまでに抑え、使った型を数えます。
型は4つ以上、場面が4つより少ない計画では場面と同じ数だけ要ります。
`finalMotionParity`の6つのキーは、どれも`true`である必要があります。

## 続いた振り付け

`check-continuous-choreography.mjs`は`storyboard/continuous-choreography-plan.json`を読み、場面を順にたどります。

| 決まり | 決め方 |
|---|---|
| `handoff-not-carried` | 場面の`entryFrom`の主役が、前の場面の`exitTo`の主役でも`becomes`でもありません |
| `persistent-subject-share` | `persistentSubjects`のどれかを主役に並べる場面が半分より少ないです |
| `repeated-axis` | 場面と前の場面の`primaryAxis`が、`none`以外で同じです |
| `three-scenes-without-change` | 続いた3つの場面に、`continuityMode`が`object-transform`か`container-reveal`か`spatial-reframe`の物も、`cameraRelation`が`push-in`か`pull-out`か`orbit`の物もありません |
| `summary-new-subject` | 役割が`summary`の場面が、前のどの場面も並べず、どの物もなっていない主役を並べます |

## 動きの言葉

`check-motion-language.mjs`は`storyboard/motion-language-plan.json`と、あなたの動きの根拠の一覧を読みます。
一覧の項目をIDで引けるようにし、場面ごとの動きと作り方を取り決めの一覧と比べます。
どの項目も挙げない場面は`missing-evidence`、一覧に無いIDを挙げる場面は`unknown-evidence`、挙げた項目に主な動きを持つ`verified`の項目が無い場面は`unverified-evidence`です。
隣り合う場面は同じ主な動きを使えず、8つ以上の場面の計画は6種類の主な動きを使い、`object-handoff`を主な動きにする場面は2つまでです。

## 動きの根拠

`check-motion-evidence.mjs`はコマンドで名指した一覧を読みます。
スキルは一覧を、`~/.local/share/remotion-explainer/`か`REMOTION_EXPLAINER_HOME`が名指すフォルダに`motion-evidence-library.json`として置きます。
項目ごとに、重ならないID、`verified`か`candidate`の状態、場所と題とhttpかhttpsのアドレスを持つ出所、範囲と説明を持つ1つ以上の見た記録、見せる動き、`useWhen`、`avoidWhen`、`reviewedAt`の日付が要ります。
確かめ済みの項目の見た記録は、どれも`00:13-00:45`や`1:02:10-1:02:30`のような時間の範囲を持つ必要があります。
確かめ済みにできるのは、実際に再生した動画だけだからです。
空の一覧は通りますが、一覧から何も挙げない計画は通りません。

## SVGの図形

`check-svg-geometry.mjs`は`storyboard/svg-geometry.json`を読みます。
要素と接続点を全部拾ってから、5つの組を順に確かめます。

| 組 | 決め方 |
|---|---|
| 要素と接続点 | 要素ごとにid、役割、正の大きさの範囲があるかを見ます。接続点ごとに、要素の中にあり、名指した縁から許す誤差の内にあるかを見ます。誤差は既定で1画素です |
| 線 | 最初の点が始まりの接続点から、最後の点が終わりの接続点から、許す誤差の内にあるかを見ます。道筋の線分を1つずつ、避けるべき要素の範囲と比べます。線分の端が範囲の中にあるか、範囲の4つの辺のどれかと交わる時に、通ったと決めます |
| 間隔 | 組ごとに、範囲が重ならず、2つの箱の一番近い距離が決めた間隔以上あるかを見ます |
| 着く所 | 着くフレームで届いた点が目的の接続点から許す誤差の内にあり、最後の範囲が目的の区域に収まるかを見ます |
| 見直し | 見直しの倍率に1と0.5があり、フレームが3つ以上名指されているかを見ます |

## 配置

`check-layout.mjs`は`storyboard/layout-spec.json`を読みます。
要素は、許されていない限り安全な範囲の中にある必要があり、字幕の場所に触れてよいのは字幕だけです。
間隔はSVGの図形と同じ決め方で見ます。
揃える組は、上の位置、下の位置、幅、高さ、または左から並べた隣どうしの隙間を比べ、ずれが許す誤差より大きいと通しません。
道筋は箱として扱い、避けるべき要素の範囲と重なってはいけません。
動画の画面を表す要素は縦横の比を持ち、0.02より大きくずれると通しません。

`--audit-dir <folder>`を付けると、そのフォルダに3つのファイルも書きます。
どれも配置のファイルのSHA-256を持つため、見直しの時にその記録が今のファイルの物かが分かります。

| ファイル | 中身 |
|---|---|
| `layout-samples.json` | 配置のファイルにある見直しのフレームと要素 |
| `collision-audit.json` | 間隔の決まりごとに、測った距離と判定 |
| `spatial-route-audit.json` | 道筋と避けるべき要素の組ごとの判定 |

## 時間の境目

`check-timing-boundary.mjs`は、`<frame>=<file>`の形で渡したPNGのフレーム、背景の色、出始めか消え際のフレームを読みます。
PNGはNode.jsの`zlib`で読みます。
先頭の印を確かめ、画像のデータをつなげて展開し、5種類の行の変換を元に戻します。
読めるのは8ビットでインターレースの無い画像で、色の種類は全部読み、パレットと透明の指定も読みます。
それ以外のPNGでは2で終わります。

画素は、透明度が0.02より大きく、赤、緑、青のどれかが背景と3より大きく違う時に、映っていると数えます。
フレームを番号の順に並べ、次の問題を出します。

| 決まり | 決め方 |
|---|---|
| `missing-boundary-frame` | 境目の2つ前から2つ後までのフレームのどれかが渡されていません |
| `premature-visible-pixels` | `--start`の時、出始めかそれより前のフレームに映る画素があります |
| `late-visible-pixels` | `--end`の時、消え際かそれより後のフレームに映る画素があります |
| `short-lived` | 映る画素を持つフレームの続きが3フレーム以下で、その前と後に何も映らないフレームがあります |
| `flicker` | 何も映らないフレームが、映る画素を持つフレームの続き2つの間にあります |

結果には、フレームごとの映る画素の数と、読んだフレーム全部のSHA-256も入ります。
`--out <file>`を付けると、同じJSONをそのファイルに書き、要ればフォルダも作ります。

## 場面の4つの層

`check-scene-layers.mjs`は`storyboard/scene-design-layers.json`を読みます。
場面ごとに、id、その場面が答える見る人の問い、4つの層が要ります。
カタログから選んだ層は項目と変えた所を名指し、独自の層は理由を書き、`none`で省いてよいのは文字の層だけです。
場面ごとの輪郭の系統、空間の組み方、見せ方の3つを前の場面と比べ、3つとも同じ時は通しません。

## 読む物と書く物と送る物

| 種類 | 中身 |
|---|---|
| 読む物 | コマンドで名指したファイル |
| 書く物 | 確かめる仕組みが書くのは、`--audit-dir`か`--out`が指す所の記録だけです。計画は`storyboard/`に、一覧の項目はデータのフォルダに、エージェントが書きます |
| 動かす物 | 自分だけです。フレームの書き出しは、あなたのプロジェクトでRemotionが行います |
| 送る物 | 確かめる仕組みはネットにつなぎません。動画を探す時は、動きの種類を表す一般的な言葉だけを使います |
| 残す物 | 動きの根拠の一覧を、あなただけが読めるようにデータのフォルダに置き、あなたが消すまで残します。ほかはプロジェクトの外に何も残しません |
