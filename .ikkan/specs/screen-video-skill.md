# screen-video-skill

| 条件 | 確かめ方 | 出元 |
|---|---|---|
| `SKILL.md`は、撮る前に目的と見る人と長さを聞き、画面を開いて押せる物を読んで流れのfileを`.screen-video/flows/`に書き、通しの台本の頁を本人に見せて答えを受けるまで録画の命令を打たない手順を持つ。質問の道具が無いagentでの聞き方も書く | `bash plugins/screen-video/skills/screen-video/tests/test-screen-video.sh`の検査`"SKILL.md plans the flow and shows the storyboard before recording"`が通る | #337 |
| 流れのfileを確かめる命令`check`は、正しい流れを通し、送信と支払いの印が付いた操作を番号と費用の書き付きで挙げる | `bash plugins/screen-video/skills/screen-video/tests/test-screen-video.sh`の検査`"check accepts a flow and lists its marked steps"`が通る | #337 |
| `check`は、知らない操作、押す所の書き方が無い操作、パスワードを流れに直に書いた入力を、操作の番号と理由付きで拒み、終わり方1を返す | `bash plugins/screen-video/skills/screen-video/tests/test-screen-video.sh`の検査`"check refuses unknown steps, missing targets, and literal secrets"`が通る | #337 |
| 通しの命令`rehearse`は録画せず、操作ごとの画と、画と字幕と操作を並べた台本の頁`storyboard.html`を置き場に書く。頁は英語と日本語を切り替えられる | `bash plugins/screen-video/skills/screen-video/tests/test-screen-video.sh`の検査`"rehearse writes a storyboard with a frame for each step"`が通る | #337 |
| `rehearse`は、送信と支払いの印が付いた最初の操作の手前で止まり、その操作を行わない | `bash plugins/screen-video/skills/screen-video/tests/test-screen-video.sh`の検査`"rehearse stops before the first marked step"`が通る | #337 |
| `rehearse`は、画面に見つからない押す所を、操作の番号と書き方付きで挙げ、終わり方1を返す | `bash plugins/screen-video/skills/screen-video/tests/test-screen-video.sh`の検査`"rehearse names a target it cannot find"`が通る | #337 |
| 録画の命令`record`は、印の付いた操作を持つ流れを`--confirm-effects`無しでは撮らずに拒み、その操作を行わない | `bash plugins/screen-video/skills/screen-video/tests/test-screen-video.sh`の検査`"record refuses marked steps without confirmation"`が通る | #337 |
| `record`は流れを撮り、`raw.mp4`、操作ごとの字幕を焼いた`captioned.mp4`、待ちを詰めて操作へ寄る`edited.mp4`、`timeline.json`、`captions.srt`を置き場に書く | `bash plugins/screen-video/skills/screen-video/tests/test-screen-video.sh`の検査`"record writes the raw, captioned, and edited videos and the timeline"`が通る | #337 |
| 流れの`outputs`が`9:16`と`gif`を持つ時、`record`は1080×1920の`vertical.mp4`と`edited.gif`も書く。持たない時は書かない | `bash plugins/screen-video/skills/screen-video/tests/test-screen-video.sh`の検査`"record writes the vertical video and the GIF only when the flow asks"`が通る | #337 |
| 流れの`mask`に書いた要素は、録画の中でぼかされ、同じ頁のぼかさない文字より細部が無い | `bash plugins/screen-video/skills/screen-video/tests/test-screen-video.sh`の検査`"masked elements are blurred in the recording"`が通る | #337 |
| 押した時刻から録画の中で押した結果が映るまでの、3回押した中央値が、1画前から0.12秒後の間に入る | `bash plugins/screen-video/skills/screen-video/tests/test-screen-video.sh`の検査`"press times line up with the video"`が通る | #337 |
| 流れの`login`が名指すenv fileから読んだIDとパスワードは、標準出力、標準エラー、`timeline.json`、`storyboard.html`のどれにも出ない | `bash plugins/screen-video/skills/screen-video/tests/test-screen-video.sh`の検査`"login values never appear in output or files"`が通る | #337 |
| 残したログインの状態を流れの`login.session`で使って、ログインが要る頁を撮れる。状態のfileは本人だけが読み書きできる (権限600) | `bash plugins/screen-video/skills/screen-video/tests/test-screen-video.sh`の検査`"a saved session signs in and stays private"`が通る | #337 |
| 置き場の既定は`~/.local/share/screen-video/<project>/<流れの名前>/` (`SCREEN_VIDEO_HOME`で根を変えられる) で、`--out`で変えられる | `bash plugins/screen-video/skills/screen-video/tests/test-screen-video.sh`の検査`"videos go to the data folder unless --out is given"`が通る | #337 |
| 置き場に動画の記録でないfileかフォルダが在る時、`record`は消さずに止める | `bash plugins/screen-video/skills/screen-video/tests/test-screen-video.sh`の検査`"record refuses to clear a folder holding other files"`が通る | #337 |
| 本人が撮った録画から、`scenes`が場面の画と止まった間を切り出し、AIが書いた`captions.json`から`render`が字幕付きの動画と止まった間を詰めた動画を作る。`captions.json`が無い時は作らずに拒む | `bash plugins/screen-video/skills/screen-video/tests/test-screen-video.sh`の検査`"scenes and render caption a recording the user made"`が通る | #337 |
| PCの`ffmpeg`が`libx264`を持つ時はそれを使い、持たない時と無い時はデータの場所の`ffmpeg-static`を使う | `bash plugins/screen-video/skills/screen-video/tests/test-screen-video.sh`の検査`"a capable system ffmpeg is preferred over the bundled one"`が通る | #337 |
| 空のデータの場所で`setup`を回すと、`node/`の下へ`playwright-core`と`ffmpeg-static`を入れ、2回目は入れ直さない | `bash plugins/screen-video/skills/screen-video/tests/test-screen-video.sh`の検査`"setup installs the runtime into the data folder once"`が通る | #337 |
| 検査が開く頁は、検査がこのPCで出す頁だけで、外のサイトへ繋がない | `bash plugins/screen-video/skills/screen-video/tests/test-screen-video.sh`の検査`"tests open only pages they serve on this machine"`が通る | #337 |
| プラグインのfileは、元の製品の名前とドメインと筋書きの語を含まない。検査は語をそのまま持たず、語の指紋 (SHA-256) だけを持つ | `bash plugins/screen-video/skills/screen-video/tests/test-screen-video.sh`の検査`"the plugin names nothing from the product it came from"`が通る | #337 |
| `plugins/screen-video/`が2つの`plugin.json`、READMEの日英、`CHANGELOG.md`、`LICENSE`、`assets/icon.svg`、`docs/how-it-works.md`の日英、`SKILL.md`と`agents/openai.yaml`を持ち、marketplaceと根のREADMEの日英が載せ、`AGENTS.md`の依存の決まりが例外として名指す | `bash scripts/check.sh`が終了0で、.claude-plugin/marketplace.jsonがscreen-videoの行を持つ | #337 |
| ほかのプラグインのfileとmarketplaceの既存の行は変わらない | `bash scripts/check.sh`が終了0で、`git diff --stat origin/main -- plugins`がplugins/screen-video/の下だけを挙げる | #337 |
