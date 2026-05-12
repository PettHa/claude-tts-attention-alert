# tts-attention-alert

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform: Windows](https://img.shields.io/badge/platform-Windows%2010%2F11-0078d4)](https://github.com/PettHa/tts-attention-alert)
[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-plugin-da7756)](https://code.claude.com/docs/en/plugins)
[![Version](https://img.shields.io/github/v/release/PettHa/tts-attention-alert?include_prereleases&label=version)](https://github.com/PettHa/tts-attention-alert/releases)
[![GitHub stars](https://img.shields.io/github/stars/PettHa/tts-attention-alert?style=social)](https://github.com/PettHa/tts-attention-alert/stargazers)

A Claude Code plugin that demands your attention when Claude pauses, asks a question, or finishes a response — even when you're in another window or away from the desk.

**Windows only.** The plugin uses Windows-native APIs (System.Speech.Synthesis, WPF, GlobalSystemMediaTransportControlsSessionManager). On macOS / Linux all hooks short-circuit on `process.platform !== 'win32'`.

## What it does

When Claude:

- **Pauses for permission** (e.g. you're about to run `git push`)
- **Wants to run a Bash command not in your allowlist** — the "Allow this bash command?" modal
- **Asks a question** via `AskUserQuestion` or **presents a plan** via `ExitPlanMode`
- **Finishes a response**

…the plugin fires three reinforcing channels at once:

1. **🗣️ TTS speech** — Windows `System.Speech` reads the actual notification message, mapped to a short action phrase via keywords:
   - "permission" / "approve" / "allow" → *"Permission needed"*
   - "waiting" → *"Claude is waiting"*
   - "idle" → *"Claude is idle"*
   - "?" / "question" / "elicit" → *"Claude has a question"*
   - otherwise speaks the raw message
2. **🟡 Edge-pulse frame** — a thin colored band around your primary monitor pulses to grab your peripheral vision:
   - **Notification**: gold, loops until the VSCode window running this Claude session gets foreground focus (60s safety cap). Escalates **Gold → DarkOrange → Red** at 20s / 40s with a fresh TTS phrase ("Claude still needs you").
   - **Stop**: blue, three quick pulses then closes.
3. **🎵 Auto-duck media** — pauses Spotify, YouTube, VLC, podcast apps around the TTS speak call (Windows `GlobalSystemMediaTransportControlsSessionManager`) so the spoken phrase is audible even mid-song. Resumes automatically. Silent no-op if nothing is playing.

A forensic log of every event is appended to `~/.claude/cache/notifications.log` with timestamp, type, and message — so you can scroll back "what fired while I was in a meeting?".

## Why no balloon toast?

Windows' built-in toast system plays a default notification chime that can't be easily suppressed. We dropped the toast and rely on TTS + visual edge-pulse instead, giving full control over the audio.

## Why edge-pulse instead of FlashWindowEx?

`FlashWindowEx` is unreliable on Windows 11 + Electron windows (VSCode, Windows Terminal) — see [microsoft/terminal#8713](https://github.com/microsoft/terminal/issues/8713). The plugin renders its own WPF overlay so the visual cue is guaranteed to display.

## Install

Requires Claude Code with plugin support (`/plugin` command available).

```text
/plugin marketplace add PettHa/tts-attention-alert
/plugin install tts-attention-alert@tts-attention-alert
```

Then reload the window (`Developer: Reload Window` or restart Claude Code) so settings re-register the hooks.

To test locally before installing from GitHub:

```bash
claude --plugin-dir /path/to/tts-attention-alert
```

## Configuration (environment variables)

All optional. Set in your shell or `.env`:

| Variable | Effect |
| :--- | :--- |
| `CLAUDE_NOTIFY_DISABLED=1` | Disable the Notification + AskUserQuestion hook entirely |
| `CLAUDE_NOTIFY_TTS_DISABLED=1` | Disable just TTS for Notification (edge-pulse still fires) |
| `CLAUDE_NOTIFY_TTS_TEXT="..."` | Override the spoken phrase (skips keyword mapping) |
| `CLAUDE_STOP_NOTIFY_DISABLED=1` | Disable the Stop hook entirely |
| `CLAUDE_STOP_TTS_DISABLED=1` | Disable just TTS for Stop |
| `CLAUDE_STOP_TTS_TEXT="..."` | Override the Stop spoken phrase (default: *"Claude is done"*) |
| `CLAUDE_NOTIFY_DUCK_DISABLED=1` | Skip pausing Spotify/YouTube/etc around TTS |
| `CLAUDE_BASH_ALERT_DISABLED=1` | Disable just the Bash permission alert (other hooks still fire) |

## Bash permission alert (v0.2.0+)

Claude Code's `Notification` event does **not** fire for the in-window "Allow this bash command?" modal. To catch it, the plugin wires Claude Code's native [`PermissionRequest`](https://code.claude.com/docs/en/hooks) hook event with matcher `Bash` — the event fires exactly when the dialog is about to display, with the full payload:

```jsonc
{
  "hook_event_name": "PermissionRequest",
  "tool_name": "Bash",
  "tool_input": { "command": "rm -rf node_modules", "description": "..." },
  "permission_mode": "default",      // or "acceptEdits" / "bypassPermissions"
  "permission_suggestions": [ ... ]
}
```

No prediction, no allow-list simulation, no dangerous-pattern heuristics — just fire the alert. Spoken phrase is *"Bash permission needed: \<verb\>"* so urgent prompts are recognizable by ear without reading the full command aloud.

## Architecture

```
tts-attention-alert/
├── .claude-plugin/
│   ├── plugin.json                  ← manifest
│   └── marketplace.json             ← marketplace registration
├── hooks/
│   ├── hooks.json                   ← Notification + Stop + PreToolUse + PermissionRequest wiring
│   ├── notification-alert.js        ← Notification + AskUserQuestion + ExitPlanMode
│   ├── bash-permission-alert.js     ← PermissionRequest:Bash, fires on the actual modal
│   ├── stop-notify.js               ← fires when response ends
│   ├── edge-pulse.ps1               ← 4-edge WPF overlay (looping + escalation)
│   ├── run-hidden.vbs               ← `wscript` shim so PowerShell launches without a console flash
│   └── lib/
│       └── audio-duck.js            ← builds the WinRT pause-resume PowerShell snippet
└── README.md
```

Hook scripts spawn PowerShell via a VBScript shim (`run-hidden.vbs` → `WScript.Shell.Run cmd, 0, False`) so nothing flashes a console on launch. The PowerShell script is passed base64-encoded via `-EncodedCommand` to avoid quoting headaches through `cmd` → `wscript` → `powershell`.

## License

MIT — see [LICENSE](LICENSE).
