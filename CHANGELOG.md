# Changelog

All notable changes to `claude-tts-attention-alert` will be documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-05-12

### Initial release

- **TTS speech** of the actual Claude notification message, with keyword-mapped short action phrases ("Permission needed", "Claude has a question", "Claude is waiting", etc.).
- **Edge-pulse overlay** — 4-edge WPF frame around the primary monitor, click-through, always-on-top.
  - Notification: gold, loops until VSCode (running this Claude session) gets foreground focus.
  - Stop: dodger blue, 3 quick pulses.
- **Escalation** for unresponded notifications — Gold → DarkOrange → Red at 20s/40s with a fresh TTS phrase.
- **Auto-duck media** — pauses Spotify, YouTube, VLC, podcast apps around the TTS speak call via Windows `GlobalSystemMediaTransportControlsSessionManager`. Resumes automatically.
- **PreToolUse:AskUserQuestion hook** — fires the same alert when Claude is about to ask an in-window question (Claude Code's native `Notification` event doesn't cover this).
- **Forensic log** of every event to `~/.claude/cache/notifications.log` with timestamp + type + message.
- **No Windows balloon toast** — avoids OS-side notification chime; only TTS-based audio.
- **VBS shim** (`run-hidden.vbs`) for launching PowerShell without a console flash and outside the parent Node Job Object.
- **PowerShell scripts** invoked via `-EncodedCommand` (base64) to sidestep cmd → wscript → powershell quoting issues.

### Environment variables

| Variable | Effect |
| :--- | :--- |
| `CLAUDE_NOTIFY_DISABLED=1` | Disable the Notification + AskUserQuestion hook entirely |
| `CLAUDE_NOTIFY_TTS_DISABLED=1` | Disable just TTS for Notification |
| `CLAUDE_NOTIFY_TTS_TEXT="..."` | Override the spoken phrase |
| `CLAUDE_STOP_NOTIFY_DISABLED=1` | Disable the Stop hook entirely |
| `CLAUDE_STOP_TTS_DISABLED=1` | Disable just TTS for Stop |
| `CLAUDE_STOP_TTS_TEXT="..."` | Override the Stop spoken phrase |
| `CLAUDE_NOTIFY_DUCK_DISABLED=1` | Skip pausing Spotify/YouTube/etc around TTS |

[Unreleased]: https://github.com/PettHa/claude-tts-attention-alert/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/PettHa/claude-tts-attention-alert/releases/tag/v0.1.0
