"""Pre-bake the plugin's static TTS phrases as WAVs via Supertonic.

Run from venv after picking a voice:
    .venv-supertonic/Scripts/python.exe scripts/generate-audio.py --voice M1

Output goes to audio/*.wav, which is committed to the repo so end-users do
not download the 99M ONNX model. Re-run only when the phrase set or voice
changes.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from supertonic import TTS

STATIC_PHRASES: dict[str, str] = {
    "plan-ready": "Plan ready",
    "permission-needed": "Permission needed",
    "claude-idle": "Claude is idle",
    "claude-waiting": "Claude is waiting",
    "claude-question": "Claude has a question",
    "claude-done": "Claude is done",
    "claude-still-needs": "Claude still needs you",
    "bash-permission": "Bash permission needed",
}

BASH_VERBS = [
    "rm", "git", "npm", "docker", "cd", "ls", "cat",
    "node", "python", "curl", "ssh", "mv", "cp",
]


def all_phrases() -> dict[str, str]:
    phrases = dict(STATIC_PHRASES)
    for verb in BASH_VERBS:
        phrases[f"bash-permission-{verb}"] = f"Bash permission needed: {verb}"
    return phrases


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--voice", default="M1", help="Supertonic voice id (M1-M5 / F1-F5)")
    parser.add_argument(
        "--out",
        type=Path,
        default=Path(__file__).resolve().parent.parent / "audio",
        help="Output directory",
    )
    args = parser.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)
    tts = TTS(auto_download=True)
    style = tts.get_voice_style(voice_name=args.voice)

    for slug, text in all_phrases().items():
        wav, _ = tts.synthesize(text, voice_style=style, lang="en")
        path = args.out / f"{slug}.wav"
        tts.save_audio(wav, str(path))
        print(f"wrote {path.relative_to(args.out.parent)}: {text!r}")


if __name__ == "__main__":
    main()
