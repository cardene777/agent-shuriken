# Third-party notices

This plugin includes the following third-party material.
Every data file the plugin bundles is listed here.

## Kenney UI Audio

| Item | Value |
|---|---|
| File in this plugin | `skills/screen-video/data/sounds/mouseclick1.ogg` |
| File in this plugin | `skills/screen-video/data/sounds/mouserelease1.ogg` |
| File in this plugin | `skills/screen-video/data/sounds/switch12.ogg` |
| File in this plugin | `skills/screen-video/data/sounds/switch13.ogg` |
| File in this plugin | `skills/screen-video/data/sounds/switch14.ogg` |
| Source | UI Audio by Kenney (kenney.nl/assets/ui-audio), the files of the same names in `Audio/` of the pack |
| SHA-256 of the pack | `946fc23a63d535d693eb31b2eabb80c8c28d6351e2186b344ceb71b2cb1d5eb6` |
| SHA-256 of `mouseclick1.ogg` | `ece1210c62ccae6c9ea4f4c59466d9d453d6b357c7d4b1a6c31196e5e6fea1bf` |
| SHA-256 of `mouserelease1.ogg` | `23cb78cea76d8f1bb1266af228101a09b5d62063f4ac87ead15b1d395c6181f0` |
| SHA-256 of `switch12.ogg` | `dab0c21eacb6536724d139c27c0d60c932c87171752dc8d24d7a826694377f94` |
| SHA-256 of `switch13.ogg` | `54d1e63b907274bb415a8de7f652194756a8eeab4079a7cf769ec153b93a436a` |
| SHA-256 of `switch14.ogg` | `c640b370738c816eda3d1196d8a8dda7130825b4094f3bb3cbba22a9f6f9b7c9` |
| Copied on | 2026-11-22 |
| License | Creative Commons Zero (CC0 1.0) |

The five sounds are unmodified copies.
`scripts/lib/sound.mjs` plays `mouseclick1.ogg` and `mouserelease1.ogg` at each click and one of the three `switch` sounds at each key typed, in the sound of the edited videos.
Kenney asks for no credit, and the pack's license text says credit to Kenney or kenney.nl would be nice; this section gives it.
To update them, download the pack again, copy the same files from `Audio/`, and update the hashes and the date above.

## What screen-video downloads on first use

These are not bundled. They are installed into the data folder the first time they are needed, and the README says what each one is.

| What | When | Where it comes from |
|---|---|---|
| `playwright-core` and `ffmpeg-static` | The first run of any command | npm, at the versions in `scripts/screen-video.sh` |
| `kokoro-js` and the Kokoro-82M model (Apache-2.0) | The first narrated English flow with a local voice | npm, and the model from Hugging Face on its first use |
| VOICEVOX CORE (MIT), its downloader, ONNX Runtime, the Open JTalk dictionary, and the voice model | The first narrated Japanese flow with a local voice, once the user has agreed to the voice model's terms | The VOICEVOX CORE releases on GitHub, through pip and the downloader |

Videos narrated by a VOICEVOX voice name it as `VOICEVOX:<character>` on their end card and in `credits.txt`, as the voice's terms ask.
