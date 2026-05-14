"""Generate voice samples so dev can pick a Supertonic voice for the plugin.

Run from venv:
    .venv-supertonic/Scripts/python.exe scripts/generate-samples.py

Produces audio/samples/<voice>-<slug>.wav for each (voice, phrase) pair so
you can A/B them before committing the full phrase set with the chosen
voice via generate-audio.py.
"""

from pathlib import Path

from supertonic import TTS

VOICES = ["M1", "M2", "M3", "F1", "F2"]
PHRASES = [
    ("permission-needed", "Permission needed"),
    ("claude-done", "Claude is done"),
    ("bash-permission-git", "Bash permission needed: git"),
]

OUT = Path(__file__).resolve().parent.parent / "audio" / "samples"
OUT.mkdir(parents=True, exist_ok=True)


def main() -> None:
    tts = TTS(auto_download=True)
    for voice in VOICES:
        style = tts.get_voice_style(voice_name=voice)
        for slug, text in PHRASES:
            wav, _ = tts.synthesize(text, voice_style=style, lang="en")
            path = OUT / f"{voice}-{slug}.wav"
            tts.save_audio(wav, str(path))
            print(f"wrote {path.relative_to(OUT.parent.parent)}")


if __name__ == "__main__":
    main()
