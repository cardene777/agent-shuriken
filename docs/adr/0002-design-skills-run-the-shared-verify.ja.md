# 0002. 設計のスキルはdoc-formatsの共通のverifyを回す

## 決めたこと

evm-devの5つのスキルが1つの設計書の書式に従うようになった後、設計書の全ての節が埋まったかを確かめる検査をどこに置くか。

## 選んだ案

`doc-formats`のpluginの`design-doc`のスキルが`verify`のscriptを1つ持ち、musubiの中身`verify`として出し、指紋で固定する。
各設計のスキルは自分の節のfileをそれに渡し、自分のscriptには日付つきの項目を引く役目だけを残す。

## 却下した案

| 案 | 採らなかった理由 |
|---|---|
| 5つの`verify`の写しを残す | 240行ほどのほぼ同じscriptが5つ残り、直しを5回することになる |
| `verify`をmusubiのJSONの決まりに置き換える | musubiの命令が配られるまで、使う人が手元で設計書を確かめられない |

## 拠り所

- 5つのscriptの違いは、節の名前と項目の種類と日付を書く節だけである (`plugins/evm-dev/skills/*/scripts/*.py`)。
- `AGENTS.md`のpluginの決まりは各pluginを自分の中だけで閉じさせるので、共通のscriptにはplugin間のpathでなく、`design-doc`のスキルを名前で開いて届く。
- 課題#251の決めたことの表。

## 決めた日

2026-11-19
