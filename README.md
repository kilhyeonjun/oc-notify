# oc-notify

Smart macOS notification wrapper for [opencode-notifier](https://github.com/mohak34/opencode-notifier).

Click a notification → your terminal gets focused. That's it.

## Features

- **Click-to-focus** — Clicking a notification activates your terminal app (Ghostty, iTerm2, Terminal.app)
- **Rich notifications** — Shows project name, event type, timestamp, session title
- **Per-event grouping** — New notifications replace stale ones (no spam)
- **Terminal icon** — Notifications show your terminal's icon, not Script Editor
- **Zero dependencies** — Just a bash script + `terminal-notifier`

## Install

```bash
brew install terminal-notifier  # if not already installed
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
  "command": {
    "enabled": true,
    "path": "~/.local/bin/oc-notify",
    "args": ["{event}", "{message}", "{sessionTitle}", "{projectName}", "{timestamp}", "{turn}"],
    "minDuration": 0
  }
}
```

> Set `"notification": false` to avoid duplicate notifications (oc-notify handles it).

## Configuration

Edit `~/.config/oc-notify/config`:

```bash
# Terminal app to focus on click
TERMINAL_BUNDLE_ID="com.mitchellh.ghostty"

# Play sound via terminal-notifier (default: false)
PLAY_SOUND="false"

# tmux session to switch to on click (empty = just focus terminal)
# TMUX_TARGET="main"
```

### Supported terminals

| Terminal | Bundle ID |
|----------|-----------|
| Ghostty | `com.mitchellh.ghostty` |
| iTerm2 | `com.googlecode.iterm2` |
| Terminal.app | `com.apple.Terminal` |
| Alacritty | `org.alacritty` |
| WezTerm | `com.github.wez.wezterm` |
| Kitty | `net.kovidgoyal.kitty` |

### Environment variables

All config options can be set via environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `OC_NOTIFY_TERMINAL` | Terminal bundle ID | `com.mitchellh.ghostty` |
| `OC_NOTIFY_BIN` | Path to terminal-notifier | auto-detected |
| `OC_NOTIFY_SOUND` | Play sound (`true`/`false`) | `false` |
| `OC_NOTIFY_TMUX_TARGET` | tmux target on click | empty |

## How it works

```
opencode-notifier (plugin)
  → fires command hook on events
    → oc-notify (this script)
      → terminal-notifier -activate com.mitchellh.ghostty
        → click notification → Ghostty gets focused
```

## License

MIT
