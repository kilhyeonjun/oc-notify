# oc-notify

Smart macOS notification wrapper for [opencode-notifier](https://github.com/mohak34/opencode-notifier).

Rich, structured notifications for your OpenCode sessions via `osascript`.

## Features

- **Rich notifications** — Title (project), subtitle (session), body (event + timestamp)
- **Session awareness** — Shows which OpenCode session triggered the notification
- **Zero dependencies** — Just a bash script + macOS built-in `osascript`
- **Configurable** — Override defaults via config file or environment variables

## Notification layout

```
┌─────────────────────────────────────────┐
│ OpenCode (project-name)          Title  │
│ Fix login bug                  Subtitle │
│ 작업 완료 — [complete] 14:30:05    Body │
└─────────────────────────────────────────┘
```

## Install

```bash
git clone https://github.com/kilhyeonjun/oc-notify.git
cd oc-notify
./install.sh
```

Or manually:

```bash
cp oc-notify ~/.local/bin/oc-notify
chmod +x ~/.local/bin/oc-notify
```

## Setup

Add to your `~/.config/opencode/opencode-notifier.json`:

```json
{
  "notification": false,
  "showSessionTitle": true,
  "command": {
    "enabled": true,
    "path": "~/.local/bin/oc-notify",
    "args": ["{event}", "{message}", "{sessionTitle}", "{projectName}", "{timestamp}", "{turn}"],
    "minDuration": 0
  }
}
```

> Set `"notification": false` to avoid duplicate notifications (oc-notify handles it).

## How it works

```
opencode-notifier (plugin)
  → fires command hook on events
    → oc-notify (this script)
      → osascript display notification
        → macOS notification with session context
```

## License

MIT
