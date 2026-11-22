# techdebt-functions

| 条件 | 確かめ方 | 出元 |
|---|---|---|
| 引数の型に`{ a: string }`を持ち1行目の中で閉じる66行のTypeScriptの関数を、66行の長い関数として数える | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"braces: a TypeScript function with an object type in its parameters is measured"`が通る | #295 |
| 戻り値の型に`{ b: number }`を持つ66行のTypeScriptの関数を、66行の長い関数として数える | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"braces: a TypeScript function with an object return type is measured"`が通る | #295 |
| 引数が複数行にまたがり、その中に型の波括弧を持つ68行の関数を、68行の長い関数として数える | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"braces: a function whose parameters span lines with object types is measured"`が通る | #295 |
| 引数に型の波括弧を持つ66行の矢印関数を、66行の長い関数として数える | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"braces: an arrow function with an object type in its parameters is measured"`が通る | #295 |
| 複数行のテンプレート文字列の中で`${...}`が行をまたぎ、その中に入れ子のテンプレート文字列を持つ関数の終わりの行を、関数の本当の終わりの行として読む。形はmusubiの`site/build.ts`の`skillPage()`に倣う | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"braces: a template literal whose expressions span lines does not end a function early"`が通る | #295 |
| 複数行のテンプレート文字列の中に在る波括弧を、関数の波括弧として数えない | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"braces: braces inside a multi-line template literal are not counted"`が通る | #295 |
| 引数に`map[string]struct{}`を持つ66行のGoの関数を、66行の長い関数として数える | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"braces: a Go function with struct{} in its parameters is measured"`が通る | #295 |
| 戻り値の型が`interface{}`の66行のGoの関数を、66行の長い関数として数える | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"braces: a Go function returning interface{} is measured"`が通る | #295 |
| Goの生文字列が行をまたぐ時、その中の波括弧を数えない | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"braces: braces inside a Go raw string across lines are not counted"`が通る | #295 |
| 頭に`<'a>`と`&'a str`のライフタイムを持つ66行のRustの関数を、66行の長い関数として数える | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"braces: a Rust function with lifetimes in its signature is measured"`が通る | #295 |
| Rustの文字列が行をまたぐ時、その中の波括弧を数えない | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"braces: braces inside a Rust string across lines are not counted"`が通る | #295 |
| Swiftの`"""`の文字列の中の波括弧を数えない | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"braces: braces inside a Swift multi-line string are not counted"`が通る | #295 |
| Javaの`"""`のテキストブロックの中の波括弧を数えない | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"braces: braces inside a Java text block are not counted"`が通る | #295 |
| Kotlinの`"""`の文字列の中の`${...}`が波括弧と引用符を持つ時も、文字列を本当の終わりまで読む | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"braces: a Kotlin raw string with a template is read to its end"`が通る | #295 |
| C#の`@"`で始まる複数行の文字列の中の波括弧を数えない | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"braces: braces inside a C# verbatim string are not counted"`が通る | #295 |
| Dartの`'''`の文字列の中の波括弧を数えない | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"braces: braces inside a Dart triple-quoted string are not counted"`が通る | #295 |
| C++の`R"(`で始まる生文字列の中の波括弧を数えない | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"braces: braces inside a C++ raw string are not counted"`が通る | #295 |
| PHPのヒアドキュメントの中の波括弧を数えない | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"braces: braces inside a PHP heredoc are not counted"`が通る | #295 |
| PHPの引用符の文字列が行をまたぐ時、その中の波括弧を数えない | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"braces: braces inside a PHP string across lines are not counted"`が通る | #295 |
| 今数えている形のTypeScriptの70行の関数とGoの67行の関数を、今と同じ行数で数える | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"a long TypeScript function is measured by braces"`と`"a long Go function is measured by braces"`が通る | #295 |
| 短い関数と1行の関数を、長い関数として数えない | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"a short function is not listed"`が通る | #295 |
| Rustの文字の`'"'`と`'{'`を、文字列の始まりとも関数の波括弧とも読まない | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"braces: Rust char literals with a quote or a brace are not strings"`が通る | #295 |
| PHPの`#`の注記に引用符が1つだけ在っても、その後の関数の行数が変わらない | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"braces: a lone quote in a PHP # comment does not hide later functions"`が通る | #295 |
| JavaScriptの正規表現に引用符が1つだけ在っても、その後の関数の行数が変わらない | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"braces: a lone quote in a JavaScript regular expression does not hide later functions"`が通る | #295 |
| 変更履歴と仕組みの説明の英語と日本語が、型の中の波括弧と複数行の文字列の中の波括弧を数えないことを書く | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"the changelog and how-it-works describe braces in types and multi-line strings"`が通る | #295 |
