# 仕組み

[English](how-it-works.md) · 日本語

このページは、Doc Formatsが何を読み、何を動かし、何を保存するかと、`verify`が名指す全ての問題を説明します。
設計書は従うスキルのagentが書き、`skills/design-doc/scripts/`のscriptは確かめるだけです。

## 技のfile

| file | 持つもの |
|---|---|
| `SKILL.md` | スキルが出す中身と、書式で設計書を書く手順と、`verify`の回し方 |
| `agents/openai.yaml` | Codexがスキルをどう見せ、どう始めるか |
| `musubi.json` | musubiで出す中身です。`design`と`verify`を、どちらも版1.0.0で出します |
| `formats/design.md` | 設計書の枠 |
| `checks/design.json` | 従うスキルの例の設計書に`musubi check`が当てる決まりです。`## Open decisions`の見出しが在り、`Fill in:`の行が無いことを求めます |
| `scripts/design-doc.py` | 設計書を確かめる`verify` |
| `tests/test-design-doc.sh` | `verify`と書式と宣言とpluginの検査 |

## スキルが書式に従う形

従うスキルは、自分の節を`Fill in:`の案内ごと、`templates/sections.md`のような節のfileに持ちます。
そのスキルの`musubi.json`は、`design-doc/design`と`design-doc/verify`を、版の範囲と、最後に確かめた中身の指紋とともに名指します。`SKILL.md`は3行を持ちます。`design-doc`の書式`design`を読むこと、命令が入っていれば先に`musubi check`を回すこと、`design-doc`が入っていなければ止まることです。
agentは書式を写し、注釈の所へスキルの節を置き、全ての`Fill in:`の行を書き換え、節のfileを渡して`verify`を回します。

| file | どのplugin | 持つもの |
|---|---|---|
| `formats/design.md` | doc-formats | 題、前書き、決まりの1文、Open decisions |
| `templates/sections.md` | 従うスキル | スキル自身の節と、その案内 |
| `musubi.json` | 従うスキル | `design-doc/design`と`design-doc/verify`の範囲と指紋、`musubi check`が決まりを当てる例の設計書 |

書式かscriptが変わると指紋が変わり、従うスキルを確かめ直して指紋を書き換えるまで、`musubi check`は従う全てのスキルを断ります。

## verifyが名指すもの

`verify --sections <節のfile> [--dated "<節>"]... <設計書>`は、節のfileの囲みのcodeの外に在る2段目の見出しを、設計書が持つべき節としてその順に読み、最後にOpen decisionsを足します。

| 問題 | 出す行 |
|---|---|
| 求める節が設計書に無い | `missing: <section>` |
| 求める節が、後に来るはずの節より前に在る | `out of order: <section>` |
| 節が空行と見出しとHTMLの注釈だけを持つ | `empty: <section>` |
| 節か、最初の節より前の文に`Fill in:`が残る | `unfinished: <section>`か`unfinished: title` |
| `--dated`で名指した節が、実在のYYYY-MM-DDの日付を持たない | `no checked date: <section>` |
| 節が引くID (D9など) で始まる行が、Open decisionsの表に無い | `undefined decision: <ID>` |

求める節の間には、ほかの2段目の見出しが在ってもかまいません。
IDの文字に数えるのはOpen decisionsの表の行のIDの頭の文字だけなので、ERC-20やSR2025のような名前はIDとして読みません。

何も問題が無い時は`design-doc: ok (<n> sections)`の1行を出して0で終わり、問題が在る時は1件ごとに1行を出して1で終わります。
設計書か節のfileを読めない時、節のfileが節を持たないかOpen decisionsを持つ時、`--dated`が節のfileに無い節を名指した時は、理由を標準エラーに出して2で終わります。

## 何を動かし、どこへ繋ぐか

`verify`は渡した設計書と節のfileを読み、標準出力と標準エラーに出します。
出すのは節の名前とIDだけで、設計書の文は出しません。
ほかのプログラムを動かさず、どこにも繋ぎません。

## 何を保存するか

何も保存しません。設計書は、従うスキルかあなたが保存する所に置かれます。
