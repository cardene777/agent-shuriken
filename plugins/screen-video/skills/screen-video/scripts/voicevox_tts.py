"""Reads lines aloud with VOICEVOX CORE and writes one WAV file for each.

voice.mjs runs this with the Python of the virtual environment it made in the data folder, where
VOICEVOX CORE is installed:

    python -I voicevox_tts.py <core folder> <jobs.json>

The core folder holds what the VOICEVOX downloader fetched: onnxruntime/, dict/, and models/.
jobs.json holds {"model": <number of the .vvm file>, "style": <style id>, "lines": [{"text", "file"}]}.
Nothing is sent anywhere: the voice is made on this machine.
"""

import json
import sys
from pathlib import Path

from voicevox_core.blocking import Onnxruntime, OpenJtalk, Synthesizer, VoiceModelFile


def main() -> None:
    core = Path(sys.argv[1])
    jobs = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
    library = core / "onnxruntime" / "lib" / Onnxruntime.LIB_VERSIONED_FILENAME
    runtime = Onnxruntime.load_once(filename=str(library))
    dictionary = next((core / "dict").glob("open_jtalk_dic_utf_8-*"))
    synthesizer = Synthesizer(runtime, OpenJtalk(str(dictionary)))
    with VoiceModelFile.open(core / "models" / "vvms" / f"{jobs['model']}.vvm") as model:
        synthesizer.load_voice_model(model)
    for line in jobs["lines"]:
        Path(line["file"]).write_bytes(synthesizer.tts(line["text"], jobs["style"]))


if __name__ == "__main__":
    main()
